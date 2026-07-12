"""ACL CRUD operations for t05_ACL_DB and all rule child tables.

Schema (from main_numbered_tables.sql):
  t05_ACL_DB              — parent ACL entry
  t05_standard_acl_rules  — Standard ACL rules
  t05_extended_acl_rules  — Extended ACL rules
  t05_dynamic_acl_rules   — Dynamic ACL rules
  t05_reflexive_acl_rules — Reflexive ACL rules
  t05_mac_acl_rules       — MAC ACL rules
  t05_router_iface_acl    — Interface binding (iface_id, direction)

Payload contract (from AclForm.qml saveAcl()):
  {
    "acl_id":          int,   # 0 = new; >0 = update existing
    "host":            str,
    "acl_name":        str,
    "acl_type":        str,   # "Standard"|"Extended"|"Dynamic"|"Reflexive"|"MAC"
    "description":     str,
    "description_only": bool, # True = only update description, keep rules untouched
    "rules":           list,  # list of rule dicts (structure depends on acl_type)
    "binding": {
      "iface_id":   int,      # 0 = no binding
      "direction":  str       # "in"|"out"
    }
  }

Completion levels:
  save_acl  → creates/updates ACL at L2 (local CRUD, success=0 awaiting push)
  delete_acl → soft-delete ACL (success=-1)
  get_acls  → reads ACL list for a host+type, including rules and binding
"""
from __future__ import annotations

import sqlite3
from typing import Any

from .common import (
    int_or_none,
    log_db_error,
    normalize_host,
    soft_delete,
    text_or_default,
    text_or_none,
)

# ── ACL type normalisation ────────────────────────────────────────────────────

_TYPE_MAP: dict[str, str] = {
    "standard":  "Standard",
    "extended":  "Extended",
    "dynamic":   "Dynamic",
    "reflexive": "Reflexive",
    "mac":       "MAC",
}

_RULE_TABLE: dict[str, str] = {
    "Standard":  "t05_standard_acl_rules",
    "Extended":  "t05_extended_acl_rules",
    "Dynamic":   "t05_dynamic_acl_rules",
    "Reflexive": "t05_reflexive_acl_rules",
    "MAC":       "t05_mac_acl_rules",
}


def _canonical_type(raw: Any) -> str:
    """Return canonical ACL type (title-case) or raise ValueError."""
    s = str(raw or "").strip()
    lower = s.lower()
    if lower in _TYPE_MAP:
        return _TYPE_MAP[lower]
    # Accept title-case too (e.g. "Standard")
    if s in _TYPE_MAP.values():
        return s
    raise ValueError(f"Unknown ACL type: {s!r}")


# ── Rule insertion helpers ────────────────────────────────────────────────────

def _insert_rule(conn: sqlite3.Connection, acl_type: str, acl_id: int, rule: dict[str, Any]) -> None:
    """Insert a single rule row into the appropriate rule table."""
    seq = int_or_none(rule.get("sequence"))
    action = text_or_default(rule.get("action"), "permit")

    if acl_type == "Standard":
        conn.execute(
            """
            INSERT INTO t05_standard_acl_rules
                (acl_id, sequence, action, source, wildcard, success)
            VALUES (?, ?, ?, ?, ?, 0);
            """,
            (
                acl_id, seq, action,
                text_or_default(rule.get("source"), "any"),
                text_or_none(rule.get("wildcard")),
            ),
        )

    elif acl_type == "Extended":
        conn.execute(
            """
            INSERT INTO t05_extended_acl_rules
                (acl_id, sequence, action, protocol,
                 source, src_wildcard, src_port,
                 destination, dst_wildcard, dst_port, success)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0);
            """,
            (
                acl_id, seq, action,
                text_or_default(rule.get("protocol"), "ip"),
                text_or_default(rule.get("source"), "any"),
                text_or_none(rule.get("src_wildcard")),
                text_or_none(rule.get("src_port")),
                text_or_default(rule.get("destination"), "any"),
                text_or_none(rule.get("dst_wildcard")),
                text_or_none(rule.get("dst_port")),
            ),
        )

    elif acl_type == "Dynamic":
        conn.execute(
            """
            INSERT INTO t05_dynamic_acl_rules
                (acl_id, sequence, action, protocol,
                 source, src_wildcard, src_port,
                 destination, dst_wildcard, dst_port,
                 dynamic_name, timeout_seconds, success)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0);
            """,
            (
                acl_id, seq, action,
                text_or_default(rule.get("protocol"), "ip"),
                text_or_default(rule.get("source"), "any"),
                text_or_none(rule.get("src_wildcard")),
                text_or_none(rule.get("src_port")),
                text_or_default(rule.get("destination"), "any"),
                text_or_none(rule.get("dst_wildcard")),
                text_or_none(rule.get("dst_port")),
                text_or_default(rule.get("dynamic_name"), ""),
                int_or_none(rule.get("timeout_seconds")) or 300,
            ),
        )

    elif acl_type == "Reflexive":
        conn.execute(
            """
            INSERT INTO t05_reflexive_acl_rules
                (acl_id, sequence, action, protocol,
                 source, src_wildcard, src_port,
                 destination, dst_wildcard, dst_port,
                 reflect_name, timeout_seconds, success)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0);
            """,
            (
                acl_id, seq, action,
                text_or_default(rule.get("protocol"), "ip"),
                text_or_default(rule.get("source"), "any"),
                text_or_none(rule.get("src_wildcard")),
                text_or_none(rule.get("src_port")),
                text_or_default(rule.get("destination"), "any"),
                text_or_none(rule.get("dst_wildcard")),
                text_or_none(rule.get("dst_port")),
                text_or_none(rule.get("reflect_name")),
                int_or_none(rule.get("timeout_seconds")) or 300,
            ),
        )

    elif acl_type == "MAC":
        conn.execute(
            """
            INSERT INTO t05_mac_acl_rules
                (acl_id, sequence, action, src_mac, src_mask,
                 dst_mac, dst_mask, ethertype, success)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0);
            """,
            (
                acl_id, seq, action,
                text_or_default(rule.get("src_mac"), "any"),
                text_or_none(rule.get("src_mask")),
                text_or_none(rule.get("dst_mac")),
                text_or_none(rule.get("dst_mask")),
                text_or_none(rule.get("ethertype")),
            ),
        )


def _delete_rules(conn: sqlite3.Connection, acl_type: str, acl_id: int) -> None:
    """Hard-delete all rule rows for an ACL (rules have no lifecycle of their own)."""
    table = _RULE_TABLE.get(acl_type)
    if table:
        conn.execute(f"DELETE FROM {table} WHERE acl_id = ?;", (acl_id,))


def _read_rules(conn: sqlite3.Connection, acl_type: str, acl_id: int) -> list[dict[str, Any]]:
    table = _RULE_TABLE.get(acl_type)
    if not table:
        return []
    rows = conn.execute(
        f"SELECT * FROM {table} WHERE acl_id = ? AND success != -1 ORDER BY sequence ASC, id ASC;",
        (acl_id,),
    ).fetchall()
    return [dict(r) for r in rows]


# ── Interface binding helpers ─────────────────────────────────────────────────

def _upsert_binding(conn: sqlite3.Connection, acl_id: int, iface_id: int, direction: str) -> None:
    """Insert or replace a binding row in t05_router_iface_acl."""
    dir_norm = "out" if str(direction or "in").strip().lower() == "out" else "in"
    # Remove any old binding for this iface+direction combination first to avoid UNIQUE conflicts
    conn.execute(
        "DELETE FROM t05_router_iface_acl WHERE acl_id = ? AND iface_id = ? AND direction = ?;",
        (acl_id, iface_id, dir_norm),
    )
    conn.execute(
        """
        INSERT INTO t05_router_iface_acl (iface_id, acl_id, direction, success)
        VALUES (?, ?, ?, 0);
        """,
        (iface_id, acl_id, dir_norm),
    )


def _remove_all_bindings(conn: sqlite3.Connection, acl_id: int) -> None:
    conn.execute("DELETE FROM t05_router_iface_acl WHERE acl_id = ?;", (acl_id,))


def _read_bindings(conn: sqlite3.Connection, acl_id: int) -> list[dict[str, Any]]:
    rows = conn.execute(
        """
        SELECT r.id, r.iface_id, r.direction, r.success,
               i.interface_name AS interface_name
        FROM t05_router_iface_acl r
        LEFT JOIN t02_interface_name i ON i.iface_id = r.iface_id
        WHERE r.acl_id = ?;
        """,
        (acl_id,),
    ).fetchall()
    return [dict(r) for r in rows]


# ── Public CRUD ───────────────────────────────────────────────────────────────

def get_acls(db: Any, host: str, acl_type: str) -> list[dict[str, Any]]:
    """Return all non-deleted ACLs for *host* and *acl_type*, with rules and bindings."""
    host = normalize_host(host)
    try:
        canonical = _canonical_type(acl_type)
    except ValueError:
        return []

    if not host:
        return []

    try:
        with db._connect() as conn:
            acl_rows = conn.execute(
                """
                SELECT Acl_id, acl_name, acl_type, host, description, success, action_Cfg
                FROM t05_ACL_DB
                WHERE host = ? AND acl_type = ? AND success != -1
                ORDER BY Acl_id ASC;
                """,
                (host, canonical),
            ).fetchall()

            result: list[dict[str, Any]] = []
            for row in acl_rows:
                acl = dict(row)
                acl_id = acl["Acl_id"]
                acl["rules"] = _read_rules(conn, canonical, acl_id)
                acl["bindings"] = _read_bindings(conn, acl_id)
                result.append(acl)
        return result
    except sqlite3.Error as exc:
        log_db_error("getAcls", exc)
        return []


def save_acl(db: Any, payload: Any) -> bool:
    """Create or update an ACL entry.

    When ``payload["acl_id"] > 0``:
      - ``description_only=True``: only update the description field, keep rules unchanged.
      - ``description_only=False``: soft-delete the old ACL, insert a new one (preserves audit trail).

    When ``payload["acl_id"] == 0``: insert a brand new ACL with success=0.
    """
    if not isinstance(payload, dict):
        return False

    host = normalize_host(payload.get("host"))
    acl_name = text_or_none(payload.get("acl_name"))
    raw_type = payload.get("acl_type", "")
    description = text_or_none(payload.get("description"))
    description_only = bool(payload.get("description_only", False))
    acl_id = int(payload.get("acl_id") or 0)
    rules: list[dict[str, Any]] = list(payload.get("rules") or [])
    binding: dict[str, Any] = dict(payload.get("binding") or {})

    if not host or not acl_name:
        return False

    try:
        canonical = _canonical_type(raw_type)
    except ValueError:
        return False

    try:
        with db._connect() as conn:
            if acl_id > 0 and description_only:
                # Fast path: only update description, touch action_Cfg bit0
                conn.execute(
                    """
                    UPDATE t05_ACL_DB
                    SET description = ?, action_Cfg = (action_Cfg | 1), success = 0
                    WHERE Acl_id = ? AND success != -1;
                    """,
                    (description, acl_id),
                )
                conn.commit()
                return True

            if acl_id > 0:
                # Replace: soft-delete old, insert new
                soft_delete(conn, "t05_ACL_DB", "Acl_id", acl_id)

            # Insert new ACL_DB row
            cursor = conn.execute(
                """
                INSERT INTO t05_ACL_DB (acl_name, acl_type, host, description, success, action_Cfg)
                VALUES (?, ?, ?, ?, 0, 1);
                """,
                (acl_name, canonical, host, description),
            )
            new_acl_id = cursor.lastrowid

            # Insert rules
            for rule in rules:
                _insert_rule(conn, canonical, new_acl_id, rule)

            # Handle binding
            iface_id = int(binding.get("iface_id") or 0)
            direction = text_or_default(binding.get("direction"), "in")
            if iface_id > 0:
                _upsert_binding(conn, new_acl_id, iface_id, direction)

            conn.commit()
        return True
    except sqlite3.Error as exc:
        log_db_error("saveAcl", exc)
        return False


def delete_acl(db: Any, acl_id: int) -> bool:
    """Soft-delete an ACL (sets success = -1).

    Child rule rows and binding rows are hard-deleted via ON DELETE CASCADE.
    However we soft-delete the parent so the push worker can detect removal
    (if needed in future). Cascade handles the rule/binding cleanup automatically
    only for hard-delete, so for soft-delete we also clean up binding rows.
    """
    if acl_id <= 0:
        return False
    try:
        with db._connect() as conn:
            deleted = soft_delete(conn, "t05_ACL_DB", "Acl_id", acl_id)
            if deleted:
                # Bindings reference the ACL; remove them so iface slots are freed
                _remove_all_bindings(conn, acl_id)
            conn.commit()
        return deleted
    except sqlite3.Error as exc:
        log_db_error("deleteAcl", exc)
        return False
