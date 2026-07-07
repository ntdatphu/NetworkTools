from __future__ import annotations

import sqlite3
from typing import Any

from .common import log_db_error, normalize_host, option_action_cfg, pool_identity_changed, soft_delete, text_or_default, text_or_none


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


def _insert_pool(conn: sqlite3.Connection, host: str, data: dict[str, Any], action_cfg: str = "111") -> None:
    conn.execute(
        """
        INSERT INTO dhcp_pool
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
    host = normalize_host(host)
    if not host:
        return []
    try:
        with db._connect() as conn:
            rows = conn.execute(
                """
                SELECT dhcp_id, host, pool, network, subnetmask, defaut, dns, lease, success, action_Cfg
                FROM dhcp_pool
                WHERE host = ? AND success != -1
                ORDER BY dhcp_id ASC;
                """,
                (host,),
            ).fetchall()
        return db._dict_rows(rows)
    except sqlite3.Error as exc:
        log_db_error("getDhcpPools", exc)
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
    host = normalize_host(host)
    data = _pool_payload(pool, network, subnetmask, default_router, dns, lease)
    if not host or not data["pool"] or not data["network"] or not data["subnetmask"]:
        return False
    try:
        with db._connect() as conn:
            _insert_pool(conn, host, data)
            conn.commit()
        return True
    except sqlite3.Error as exc:
        log_db_error("addDhcpPool", exc)
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
            current_row = conn.execute(
                """
                SELECT dhcp_id, host, pool, network, subnetmask, defaut, dns, lease
                FROM dhcp_pool
                WHERE dhcp_id = ? AND success != -1;
                """,
                (dhcp_id,),
            ).fetchone()
            if current_row is None:
                return False

            current = dict(current_row)
            if pool_identity_changed(current, data):
                soft_delete(conn, "dhcp_pool", "dhcp_id", dhcp_id)
                _insert_pool(conn, current["host"], data)
            else:
                action_cfg = option_action_cfg(current, data)
                conn.execute(
                    """
                    UPDATE dhcp_pool
                    SET defaut = ?, dns = ?, lease = ?, action_Cfg = ?, success = 0
                    WHERE dhcp_id = ?;
                    """,
                    (data["defaut"], data["dns"], data["lease"], action_cfg, dhcp_id),
                )
            conn.commit()
        return True
    except sqlite3.Error as exc:
        log_db_error("updateDhcpPool", exc)
        return False


def delete_dhcp_pool(db: Any, dhcp_id: int) -> bool:
    try:
        with db._connect() as conn:
            soft_delete(conn, "dhcp_pool", "dhcp_id", dhcp_id)
            conn.commit()
        return True
    except sqlite3.Error as exc:
        log_db_error("deleteDhcpPool", exc)
        return False
