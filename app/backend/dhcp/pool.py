from __future__ import annotations

import sqlite3
import sys
from typing import Any

from .common import option_action_cfg, pool_identity_changed, table_name, text_or_default, text_or_none


def _pool_payload(
    pool: str,
    network: str,
    subnetmask: str,
    default_router: str,
    dns: str,
    lease: str,
) -> dict[str, Any]:
    return {
        "pool": text_or_default(pool, ""),
        "network": text_or_default(network, ""),
        "subnetmask": text_or_default(subnetmask, ""),
        "defaut": text_or_none(default_router),
        "dns": text_or_none(dns),
        "lease": text_or_default(lease, "1"),
    }


def _insert_pool(conn: sqlite3.Connection, table: str, host: str, data: dict[str, Any], action_cfg: str = "111") -> None:
    conn.execute(
        f"""
        INSERT INTO {table}
            (host, pool, network, subnetmask, defaut, dns, lease, success, action_Cfg)
        VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?);
        """,
        (
            host,
            data["pool"],
            data["network"],
            data["subnetmask"],
            data["defaut"],
            data["dns"],
            data["lease"],
            action_cfg,
        ),
    )


def get_dhcp_pools(db: Any, host: str) -> list[dict[str, Any]]:
    host = (host or "").strip()
    if not host:
        return []
    try:
        with db._connect() as conn:
            pool_table = table_name(db, conn, "dhcp_pool", "t03_dhcp_pool")
            rows = conn.execute(
                f"""
                SELECT dhcp_id, host, pool, network, subnetmask, defaut, dns, lease, success, action_Cfg
                FROM {pool_table}
                WHERE host = ? AND success != -1
                ORDER BY dhcp_id ASC;
                """,
                (host,),
            ).fetchall()
        return db._dict_rows(rows)
    except sqlite3.Error as exc:
        print(f"[db] getDhcpPools failed: {exc}", file=sys.stderr)
        return []


def add_dhcp_pool(
    db: Any,
    host: str,
    pool: str,
    network: str,
    subnetmask: str,
    default_router: str,
    dns: str,
    lease: str,
) -> bool:
    host = (host or "").strip()
    data = _pool_payload(pool, network, subnetmask, default_router, dns, lease)
    if not host or not data["pool"] or not data["network"] or not data["subnetmask"]:
        return False
    try:
        with db._connect() as conn:
            pool_table = table_name(db, conn, "dhcp_pool", "t03_dhcp_pool")
            _insert_pool(conn, pool_table, host, data)
            conn.commit()
        return True
    except sqlite3.Error as exc:
        print(f"[db] addDhcpPool failed: {exc}", file=sys.stderr)
        return False


def update_dhcp_pool(
    db: Any,
    dhcp_id: int,
    pool: str,
    network: str,
    subnetmask: str,
    default_router: str,
    dns: str,
    lease: str,
) -> bool:
    data = _pool_payload(pool, network, subnetmask, default_router, dns, lease)
    if dhcp_id < 0 or not data["pool"] or not data["network"] or not data["subnetmask"]:
        return False
    try:
        with db._connect() as conn:
            pool_table = table_name(db, conn, "dhcp_pool", "t03_dhcp_pool")
            current_row = conn.execute(
                f"""
                SELECT dhcp_id, host, pool, network, subnetmask, defaut, dns, lease
                FROM {pool_table}
                WHERE dhcp_id = ? AND success != -1;
                """,
                (dhcp_id,),
            ).fetchone()
            if current_row is None:
                return False

            current = dict(current_row)
            if pool_identity_changed(current, data):
                conn.execute(f"UPDATE {pool_table} SET success = -1 WHERE dhcp_id = ?;", (dhcp_id,))
                _insert_pool(conn, pool_table, current["host"], data)
            else:
                action_cfg = option_action_cfg(current, data)
                conn.execute(
                    f"""
                    UPDATE {pool_table}
                    SET defaut = ?, dns = ?, lease = ?, action_Cfg = ?, success = 0
                    WHERE dhcp_id = ?;
                    """,
                    (data["defaut"], data["dns"], data["lease"], action_cfg, dhcp_id),
                )
            conn.commit()
        return True
    except sqlite3.Error as exc:
        print(f"[db] updateDhcpPool failed: {exc}", file=sys.stderr)
        return False


def delete_dhcp_pool(db: Any, dhcp_id: int) -> bool:
    try:
        with db._connect() as conn:
            pool_table = table_name(db, conn, "dhcp_pool", "t03_dhcp_pool")
            conn.execute(f"UPDATE {pool_table} SET success = -1 WHERE dhcp_id = ?;", (dhcp_id,))
            conn.commit()
        return True
    except sqlite3.Error as exc:
        print(f"[db] deleteDhcpPool failed: {exc}", file=sys.stderr)
        return False
