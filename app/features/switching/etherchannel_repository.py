from __future__ import annotations

import re
import sqlite3
from contextlib import closing
from typing import Any

from .common import choice, failed, integer, ok, text
from .schema import ensure_switch_schema


_MEMBER_PATTERN = re.compile(r"^[A-Za-z][A-Za-z0-9./:_-]*$")
_MODES = {
    "lacp": {"active", "passive"},
    "pagp": {"desirable", "auto"},
    "static": {"on"},
}
_DEFAULT_MODES = {"lacp": "active", "pagp": "desirable", "static": "on"}


def get_etherchannels(db: Any, host: str) -> list[dict[str, Any]]:
    """Return the existing EtherChannel desired state without changing its schema."""
    target = text(host)
    if not target:
        return []
    ensure_switch_schema(db)
    with closing(db._connect()) as conn:
        rows = conn.execute(
            """
            SELECT id, po_number, protocol, mode, member_ports, description,
                   status, success
            FROM t06_etherchannel
            WHERE host = ?
            ORDER BY po_number;
            """,
            (target,),
        ).fetchall()
    return [dict(row) for row in rows]


def _normalize_members(value: Any) -> str:
    members = [item.strip() for item in text(value).split(",") if item.strip()]
    if not members:
        raise ValueError("At least one member interface is required")

    normalized: list[str] = []
    seen: set[str] = set()
    for member in members:
        if not _MEMBER_PATTERN.fullmatch(member):
            raise ValueError(f"Invalid member interface: {member}")
        if re.match(r"^(?:port-channel|po)\d", member, re.IGNORECASE):
            raise ValueError("A Port-channel cannot be nested as a member")
        key = member.casefold()
        if key in seen:
            raise ValueError(f"Duplicate member interface: {member}")
        seen.add(key)
        normalized.append(member)
    return ",".join(normalized)


def save_etherchannel(db: Any, host: str, payload: dict[str, Any]) -> dict[str, Any]:
    """Create or update an EtherChannel using the legacy t06 table as-is."""
    target = text(host)
    if not target:
        return failed("Host is required")
    try:
        ensure_switch_schema(db)
        row_id = int(payload.get("id") or 0)
        po_number = integer(payload.get("po_number"), "Port-channel number", 1, 4096)
        protocol = choice(payload.get("protocol"), "Protocol", set(_MODES), "lacp")
        mode = choice(payload.get("mode"), "Mode", _MODES[protocol], _DEFAULT_MODES[protocol])
        member_ports = _normalize_members(payload.get("member_ports"))
        description = text(payload.get("description"))
        if "\n" in description or "\r" in description:
            raise ValueError("Description must be a single line")

        with closing(db._connect()) as conn:
            with conn:
                duplicate = conn.execute(
                    """
                    SELECT 1 FROM t06_etherchannel
                    WHERE host = ? AND po_number = ? AND id <> ?;
                    """,
                    (target, po_number, row_id),
                ).fetchone()
                if duplicate is not None:
                    raise ValueError(f"Port-channel{po_number} already exists on this switch")

                requested_members = {
                    member.casefold(): member for member in member_ports.split(",")
                }
                existing_rows = conn.execute(
                    """
                    SELECT po_number, member_ports
                    FROM t06_etherchannel
                    WHERE host = ? AND id <> ?;
                    """,
                    (target, row_id),
                ).fetchall()
                for existing in existing_rows:
                    assigned = {
                        member.strip().casefold()
                        for member in str(existing["member_ports"] or "").split(",")
                        if member.strip()
                    }
                    conflicts = sorted(set(requested_members) & assigned)
                    if conflicts:
                        raise ValueError(
                            "Member interface is already assigned to "
                            f"Port-channel{existing['po_number']}: "
                            + ", ".join(requested_members[item] for item in conflicts)
                        )
                if row_id > 0:
                    cursor = conn.execute(
                        """
                        UPDATE t06_etherchannel
                        SET po_number = ?, protocol = ?, mode = ?, member_ports = ?,
                            description = ?, success = 'pending_apply'
                        WHERE id = ? AND host = ?;
                        """,
                        (
                            po_number,
                            protocol,
                            mode,
                            member_ports,
                            description,
                            row_id,
                            target,
                        ),
                    )
                    if cursor.rowcount == 0:
                        raise ValueError("The selected EtherChannel no longer exists")
                    saved_id = row_id
                else:
                    cursor = conn.execute(
                        """
                        INSERT INTO t06_etherchannel(
                            host, po_number, protocol, mode, member_ports, description, status
                        ) VALUES (?, ?, ?, ?, ?, ?, 'unknown');
                        """,
                        (target, po_number, protocol, mode, member_ports, description),
                    )
                    saved_id = int(cursor.lastrowid)
        return ok("EtherChannel saved to the local workspace", id=saved_id)
    except (sqlite3.Error, ValueError, TypeError) as exc:
        return failed(str(exc))
