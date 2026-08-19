"""SQLite repository for multi-device HSRP, VRRP and GLBP groups."""

from __future__ import annotations

import ipaddress
import sqlite3
from contextlib import closing
from typing import Any


def _network_for_row(row: sqlite3.Row) -> ipaddress.IPv4Network | None:
    try:
        return ipaddress.ip_interface(
            f"{str(row['ip_address']).strip()}/{str(row['subnet_mask']).strip()}"
        ).network
    except (ValueError, TypeError):
        return None


class FhrpRepository:
    """Own all FHRP SQL while services own validation and policy."""

    def __init__(self, db: Any) -> None:
        self.db = db

    def connected_hosts(self) -> list[dict[str, str]]:
        with closing(self.db._connect()) as conn:
            rows = conn.execute(
                """
                SELECT host, device_name
                FROM t01_devices
                WHERE connection_status = 'connected'
                  AND (
                    lower(COALESCE(role, '')) IN ('rou', 'router', 'sw3')
                    OR lower(COALESCE(device_type, '')) IN ('router', 'sw3')
                  )
                ORDER BY host COLLATE NOCASE;
                """
            ).fetchall()
        return [
            {"host": row["host"], "device_name": row["device_name"] or ""}
            for row in rows
        ]

    def matching_interfaces(
        self, hosts: list[str], gateway: ipaddress.IPv4Address
    ) -> list[dict[str, Any]]:
        if not hosts:
            return []
        placeholders = ",".join("?" for _ in hosts)
        with closing(self.db._connect()) as conn:
            rows = conn.execute(
                f"""
                SELECT iface_id, host, interface_name, ip_address, subnet_mask
                FROM t02_interface_name
                WHERE host IN ({placeholders})
                  AND sync_status != 'pending_delete'
                  AND COALESCE(ip_address, '') != ''
                  AND COALESCE(subnet_mask, '') != ''
                ORDER BY host COLLATE NOCASE, interface_name COLLATE NOCASE;
                """,
                hosts,
            ).fetchall()
        result: list[dict[str, Any]] = []
        for row in rows:
            network = _network_for_row(row)
            try:
                interface_ip = ipaddress.IPv4Address(str(row["ip_address"]).strip())
            except ValueError:
                continue
            if (
                network is None
                or gateway not in network
                or gateway == interface_ip
                or gateway in {network.network_address, network.broadcast_address}
            ):
                continue
            result.append(
                {
                    "iface_id": row["iface_id"],
                    "host": row["host"],
                    "interface_name": row["interface_name"],
                    "ip_address": row["ip_address"],
                    "subnet_mask": row["subnet_mask"],
                    "network": str(network),
                }
            )
        return result

    def list_groups(self, host: str = "") -> list[dict[str, Any]]:
        params: tuple[Any, ...] = ()
        host_filter = ""
        if host:
            host_filter = "WHERE EXISTS (SELECT 1 FROM t08_fhrp_members x WHERE x.fhrp_id = g.fhrp_id AND x.host = ?)"
            params = (host,)
        with closing(self.db._connect()) as conn:
            groups = conn.execute(
                f"""
                SELECT g.fhrp_id, g.protocol, g.group_number, g.virtual_ip,
                       g.address_family, g.description, g.updated_at
                FROM t08_fhrp_groups AS g
                {host_filter}
                ORDER BY g.updated_at DESC, g.fhrp_id DESC;
                """,
                params,
            ).fetchall()
            result: list[dict[str, Any]] = []
            for group in groups:
                item = dict(group)
                item["members"] = [
                    dict(row)
                    for row in conn.execute(
                        """
                        SELECT m.member_id, m.host, m.iface_id, i.interface_name,
                               m.priority, m.preempt, m.shutdown, m.sync_status
                        FROM t08_fhrp_members AS m
                        JOIN t02_interface_name AS i ON i.iface_id = m.iface_id
                        WHERE m.fhrp_id = ?
                        ORDER BY m.host COLLATE NOCASE;
                        """,
                        (group["fhrp_id"],),
                    ).fetchall()
                ]
                result.append(item)
        return result

    def save_group(self, payload: dict[str, Any]) -> int:
        protocol = payload["protocol"]
        members = payload["members"]
        with closing(self.db._connect()) as conn:
            with conn:
                existing = conn.execute(
                    """
                    SELECT fhrp_id
                    FROM t08_fhrp_groups
                    WHERE protocol = ? AND group_number = ?
                      AND virtual_ip = ? AND address_family = 'ipv4'
                    LIMIT 1;
                    """,
                    (
                        protocol,
                        payload["group_number"],
                        payload["virtual_ip"],
                    ),
                ).fetchone()
                if existing is not None:
                    fhrp_id = int(existing["fhrp_id"])
                    protected = conn.execute(
                        """
                        SELECT 1
                        FROM t08_fhrp_members
                        WHERE fhrp_id = ? AND sync_status != 'pending_apply'
                        LIMIT 1;
                        """,
                        (fhrp_id,),
                    ).fetchone()
                    if protected is not None:
                        raise ValueError(
                            "FHRP group already exists in device-synchronized state."
                        )
                    # A failed/partial Save & Push can leave a local-only draft.
                    # Replace that draft atomically so retrying is idempotent.
                    conn.execute(
                        "DELETE FROM t08_fhrp_groups WHERE fhrp_id = ?;",
                        (fhrp_id,),
                    )
                cursor = conn.execute(
                    """
                    INSERT INTO t08_fhrp_groups (
                        protocol, group_number, virtual_ip, address_family, description
                    )
                    VALUES (?, ?, ?, 'ipv4', ?);
                    """,
                    (
                        protocol,
                        payload["group_number"],
                        payload["virtual_ip"],
                        payload.get("description") or None,
                    ),
                )
                fhrp_id = int(cursor.lastrowid)
                for member in members:
                    member_cursor = conn.execute(
                        """
                        INSERT INTO t08_fhrp_members (
                            fhrp_id, host, iface_id, priority, preempt, shutdown, sync_status
                        )
                        VALUES (?, ?, ?, ?, ?, ?, 'pending_apply');
                        """,
                        (
                            fhrp_id,
                            member["host"],
                            member["iface_id"],
                            member["priority"],
                            int(member["preempt"]),
                            int(member["shutdown"]),
                        ),
                    )
                    member_id = int(member_cursor.lastrowid)
                    self._insert_options(conn, protocol, member_id, member)
                    for track in member.get("tracks") or []:
                        conn.execute(
                            """
                            INSERT INTO t08_fhrp_tracks (
                                member_id, track_object, decrement_value, sync_status
                            )
                            VALUES (?, ?, ?, 'pending_apply');
                            """,
                            (
                                member_id,
                                track["track_object"],
                                track["decrement_value"],
                            ),
                        )
        return fhrp_id

    def mark_group_for_delete(self, fhrp_id: int) -> list[str]:
        with closing(self.db._connect()) as conn:
            with conn:
                members = conn.execute(
                    """
                    SELECT member_id, host, sync_status
                    FROM t08_fhrp_members
                    WHERE fhrp_id = ?
                    ORDER BY member_id;
                    """,
                    (fhrp_id,),
                ).fetchall()
                hosts = [row["host"] for row in members]
                local_member_ids = [
                    int(row["member_id"])
                    for row in members
                    if row["sync_status"] not in {"synchronized", "pending_delete"}
                ]
                device_member_ids = [
                    int(row["member_id"])
                    for row in members
                    if row["sync_status"] in {"synchronized", "pending_delete"}
                ]

                # Local-only members never existed on the device. Deleting
                # them cancels their pending apply and must not create a
                # synthetic `no standby/vrrp/glbp` push task.
                if local_member_ids:
                    placeholders = ",".join("?" for _ in local_member_ids)
                    conn.execute(
                        f"DELETE FROM t08_fhrp_members "
                        f"WHERE member_id IN ({placeholders});",
                        local_member_ids,
                    )

                # Preserve the established removal flow only for members that
                # may already exist on their device. This also handles a group
                # whose multi-host push succeeded only on some members.
                if device_member_ids:
                    placeholders = ",".join("?" for _ in device_member_ids)
                    conn.execute(
                        f"""
                        UPDATE t08_fhrp_members
                        SET sync_status = 'pending_delete'
                        WHERE member_id IN ({placeholders});
                        """,
                        device_member_ids,
                    )
                    conn.execute(
                        f"""
                        UPDATE t08_fhrp_tracks
                        SET sync_status = 'pending_delete'
                        WHERE member_id IN ({placeholders});
                        """,
                        device_member_ids,
                    )

                remaining = conn.execute(
                    "SELECT 1 FROM t08_fhrp_members WHERE fhrp_id = ? LIMIT 1;",
                    (fhrp_id,),
                ).fetchone()
                if remaining is None:
                    conn.execute(
                        "DELETE FROM t08_fhrp_groups WHERE fhrp_id = ?;",
                        (fhrp_id,),
                    )
        return hosts

    @staticmethod
    def _insert_options(
        conn: sqlite3.Connection,
        protocol: str,
        member_id: int,
        member: dict[str, Any],
    ) -> None:
        auth_type = member.get("auth_type") or "none"
        auth_secret = member.get("auth_secret") or None
        if protocol == "hsrp":
            conn.execute(
                """
                INSERT INTO t08_hsrp_options (
                    member_id, version, hello_ms, hold_ms,
                    preempt_delay_min_sec, preempt_delay_reload_sec,
                    auth_type, auth_secret
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
                """,
                (
                    member_id,
                    member.get("version", 2),
                    member.get("hello_ms", 3000),
                    member.get("hold_ms", 10000),
                    member.get("preempt_delay_min_sec", 0),
                    member.get("preempt_delay_reload_sec", 0),
                    auth_type,
                    auth_secret,
                ),
            )
        elif protocol == "vrrp":
            conn.execute(
                """
                INSERT INTO t08_vrrp_options (
                    member_id, version, advertisement_ms, accept_mode,
                    auth_type, auth_secret
                ) VALUES (?, ?, ?, ?, ?, ?);
                """,
                (
                    member_id,
                    member.get("version", 3),
                    member.get("advertisement_ms", 1000),
                    int(member.get("accept_mode", False)),
                    auth_type,
                    auth_secret,
                ),
            )
        else:
            conn.execute(
                """
                INSERT INTO t08_glbp_options (
                    member_id, hello_ms, hold_ms, load_balancing,
                    weighting_max, weighting_lower, weighting_upper,
                    forwarder_preempt, forwarder_preempt_delay_sec,
                    auth_type, auth_secret
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                """,
                (
                    member_id,
                    member.get("hello_ms", 3000),
                    member.get("hold_ms", 10000),
                    member.get("load_balancing", "round-robin"),
                    member.get("weighting_max", 100),
                    member.get("weighting_lower"),
                    member.get("weighting_upper"),
                    int(member.get("forwarder_preempt", True)),
                    member.get("forwarder_preempt_delay_sec", 30),
                    auth_type,
                    auth_secret,
                ),
            )
