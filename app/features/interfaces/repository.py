from __future__ import annotations

import sqlite3
from typing import Any

from .common import db_connection, log_db_error, normalize_host, text_or_none


def _choice(value: Any, allowed: set[str], default: str) -> str:
    text = str(value or "").strip().lower()
    return text if text in allowed else default


def _int_or_none(db: Any, value: Any) -> int | None:
    return db._int_or_none(value)


def _bool_int(db: Any, value: Any) -> int:
    return db._bool_int(value)


def _interface_select_sql(where_clause: str) -> str:
    return f"""
        SELECT
            i.iface_id,
            i.host,
            i.interface_name,
            i.ip_address,
            i.subnet_mask,
            i.description,
            i.shutdown,
            i.sync_status,
            CASE
                WHEN t.iface_id IS NOT NULL THEN 'Tunnel'
                WHEN w.iface_id IS NOT NULL THEN 'WAN'
                ELSE 'L3'
            END AS interface_kind,
            CASE WHEN l.iface_id IS NOT NULL THEN 1 ELSE 0 END AS has_l3,
            CASE WHEN t.iface_id IS NOT NULL THEN 1 ELSE 0 END AS has_tunnel,
            CASE WHEN w.iface_id IS NOT NULL THEN 1 ELSE 0 END AS has_wan,
            l.secondary_ip,
            l.secondary_mask,
            l.mtu,
            l.bandwidth,
            l.delay,
            l.speed,
            l.duplex,
            l.negotiation,
            l.proxy_arp,
            l.unreachables,
            l.directed_broadcast,
            t.tunnel_mode,
            t.tunnel_src,
            t.tunnel_dst,
            t.tunnel_key,
            t.keepalive_sec,
            t.keepalive_retry,
            t.ipsec_profile,
            w.encap_type,
            w.pppoe_dialer_pool,
            w.ppp_auth,
            w.ppp_username,
            w.ppp_password,
            w.clock_rate,
            w.lmi_type
        FROM t02_interface_name AS i
        LEFT JOIN t02_router_iface_l3 AS l
            ON l.iface_id = i.iface_id AND COALESCE(l.sync_status, 'pending_apply') != 'pending_delete'
        LEFT JOIN t02_router_iface_tunnel AS t
            ON t.iface_id = i.iface_id AND COALESCE(t.sync_status, 'pending_apply') != 'pending_delete'
        LEFT JOIN t02_router_iface_wan AS w
            ON w.iface_id = i.iface_id AND COALESCE(w.sync_status, 'pending_apply') != 'pending_delete'
        WHERE {where_clause}
    """


def get_router_interfaces(db: Any, host: str) -> list[dict[str, Any]]:
    host = normalize_host(host)
    if not host:
        return []
    try:
        with db_connection(db) as conn:
            rows = conn.execute(
                _interface_select_sql("i.host = ? AND COALESCE(i.sync_status, 'pending_apply') != 'pending_delete'")
                + " ORDER BY i.interface_name COLLATE NOCASE;",
                (host,),
            ).fetchall()
        return db._dict_rows(rows)
    except sqlite3.Error as exc:
        log_db_error("getRouterInterfaces", exc)
        return []


def get_router_interface_by_name(db: Any, host: str, name: str) -> dict[str, Any]:
    host = normalize_host(host)
    name = (name or "").strip()
    if not host or not name:
        return {}
    try:
        with db_connection(db) as conn:
            row = conn.execute(
                _interface_select_sql(
                    "i.host = ? AND i.interface_name = ? AND COALESCE(i.sync_status, 'pending_apply') != 'pending_delete'"
                )
                + " ORDER BY i.iface_id DESC LIMIT 1;",
                (host, name),
            ).fetchone()
        return dict(row) if row else {}
    except sqlite3.Error as exc:
        log_db_error("getRouterInterfaceByName", exc)
        return {}


def _upsert_l3(conn: sqlite3.Connection, db: Any, iface_id: int, payload: dict[str, Any], sync_status: str = "pending_apply") -> None:
    speed = _choice(payload.get("speed"), {"auto", "10", "100", "1000", "10000"}, "auto")
    duplex = _choice(payload.get("duplex"), {"auto", "full", "half"}, "auto")
    conn.execute(
        """
        INSERT INTO t02_router_iface_l3 (
            iface_id, secondary_ip, secondary_mask, mtu, bandwidth, delay,
            speed, duplex, negotiation, proxy_arp, unreachables,
            directed_broadcast, sync_status, action_Cfg
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, '11111')
        ON CONFLICT(iface_id) DO UPDATE SET
            secondary_ip = excluded.secondary_ip,
            secondary_mask = excluded.secondary_mask,
            mtu = excluded.mtu,
            bandwidth = excluded.bandwidth,
            delay = excluded.delay,
            speed = excluded.speed,
            duplex = excluded.duplex,
            negotiation = excluded.negotiation,
            proxy_arp = excluded.proxy_arp,
            unreachables = excluded.unreachables,
            directed_broadcast = excluded.directed_broadcast,
            sync_status = excluded.sync_status,
            action_Cfg = '11111';
        """,
        (
            iface_id,
            text_or_none(payload.get("secondary_ip")),
            text_or_none(payload.get("secondary_mask")),
            _int_or_none(db, payload.get("mtu")) or 1500,
            _int_or_none(db, payload.get("bandwidth")),
            _int_or_none(db, payload.get("delay")),
            speed,
            duplex,
            _bool_int(db, payload.get("negotiation", True)),
            _bool_int(db, payload.get("proxy_arp", True)),
            _bool_int(db, payload.get("unreachables", True)),
            _bool_int(db, payload.get("directed_broadcast")),
            sync_status,
        ),
    )


def _upsert_tunnel(conn: sqlite3.Connection, db: Any, iface_id: int, payload: dict[str, Any], sync_status: str = "pending_apply") -> bool:
    tunnel_src = text_or_none(payload.get("tunnel_src"))
    tunnel_dst = text_or_none(payload.get("tunnel_dst"))
    if not tunnel_src or not tunnel_dst:
        return False
    tunnel_mode = _choice(payload.get("tunnel_mode"), {"gre", "ipip", "ipsec", "gre-ipsec"}, "gre")
    conn.execute(
        """
        INSERT INTO t02_router_iface_tunnel (
            iface_id, tunnel_mode, tunnel_src, tunnel_dst, tunnel_key,
            keepalive_sec, keepalive_retry, ipsec_profile, sync_status, action_Cfg
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, '111')
        ON CONFLICT(iface_id) DO UPDATE SET
            tunnel_mode = excluded.tunnel_mode,
            tunnel_src = excluded.tunnel_src,
            tunnel_dst = excluded.tunnel_dst,
            tunnel_key = excluded.tunnel_key,
            keepalive_sec = excluded.keepalive_sec,
            keepalive_retry = excluded.keepalive_retry,
            ipsec_profile = excluded.ipsec_profile,
            sync_status = excluded.sync_status,
            action_Cfg = '111';
        """,
        (
            iface_id,
            tunnel_mode,
            tunnel_src,
            tunnel_dst,
            _int_or_none(db, payload.get("tunnel_key")),
            _int_or_none(db, payload.get("keepalive_sec")),
            _int_or_none(db, payload.get("keepalive_retry")),
            text_or_none(payload.get("ipsec_profile")),
            sync_status,
        ),
    )
    return True


def _upsert_wan(conn: sqlite3.Connection, db: Any, iface_id: int, payload: dict[str, Any], sync_status: str = "pending_apply") -> None:
    encap_type = _choice(payload.get("encap_type"), {"none", "pppoe", "hdlc", "ppp", "frame-relay"}, "none")
    ppp_auth = _choice(payload.get("ppp_auth"), {"pap", "chap"}, "")
    lmi_type = _choice(payload.get("lmi_type"), {"cisco", "ansi", "q933a"}, "")
    conn.execute(
        """
        INSERT INTO t02_router_iface_wan (
            iface_id, encap_type, pppoe_dialer_pool, ppp_auth,
            ppp_username, ppp_password, clock_rate, lmi_type,
            sync_status, action_Cfg
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, '11')
        ON CONFLICT(iface_id) DO UPDATE SET
            encap_type = excluded.encap_type,
            pppoe_dialer_pool = excluded.pppoe_dialer_pool,
            ppp_auth = excluded.ppp_auth,
            ppp_username = excluded.ppp_username,
            ppp_password = excluded.ppp_password,
            clock_rate = excluded.clock_rate,
            lmi_type = excluded.lmi_type,
            sync_status = excluded.sync_status,
            action_Cfg = '11';
        """,
        (
            iface_id,
            encap_type,
            _int_or_none(db, payload.get("pppoe_dialer_pool")),
            ppp_auth or None,
            text_or_none(payload.get("ppp_username")),
            text_or_none(payload.get("ppp_password")),
            _int_or_none(db, payload.get("clock_rate")),
            lmi_type or None,
            sync_status,
        ),
    )


def save_router_interface(db: Any, payload_value: Any) -> bool:
    payload = db._as_dict(payload_value)
    host = normalize_host(payload.get("host"))
    name = text_or_none(payload.get("interface_name"))
    if not host or not name:
        return False

    kind = str(payload.get("interface_kind") or "L3").strip()
    if kind not in {"L3", "WAN", "Tunnel"}:
        kind = "L3"
    if kind == "Tunnel" and (
        not text_or_none(payload.get("tunnel_src")) or not text_or_none(payload.get("tunnel_dst"))
    ):
        return False

    try:
        with db_connection(db) as conn:
            row = conn.execute(
                """
                SELECT iface_id
                FROM t02_interface_name
                WHERE host = ? AND interface_name = ?
                ORDER BY CASE WHEN COALESCE(sync_status, 'pending_apply') != 'pending_delete' THEN 0 ELSE 1 END, iface_id DESC
                LIMIT 1;
                """,
                (host, name),
            ).fetchone()
            if row:
                iface_id = int(row["iface_id"])
                conn.execute(
                    """
                    UPDATE t02_interface_name
                    SET ip_address = ?, subnet_mask = ?, description = ?, shutdown = ?, sync_status = 'pending_apply'
                    WHERE iface_id = ?;
                    """,
                    (
                        text_or_none(payload.get("ip_address")),
                        text_or_none(payload.get("subnet_mask")),
                        text_or_none(payload.get("description")),
                        _bool_int(db, payload.get("shutdown")),
                        iface_id,
                    ),
                )
            else:
                cursor = conn.execute(
                    """
                    INSERT INTO t02_interface_name (
                        host, interface_name, ip_address, subnet_mask,
                        description, shutdown, sync_status
                    )
                    VALUES (?, ?, ?, ?, ?, ?, 'pending_apply');
                    """,
                    (
                        host,
                        name,
                        text_or_none(payload.get("ip_address")),
                        text_or_none(payload.get("subnet_mask")),
                        text_or_none(payload.get("description")),
                        _bool_int(db, payload.get("shutdown")),
                    ),
                )
                iface_id = int(cursor.lastrowid)

            if kind == "L3":
                _upsert_l3(conn, db, iface_id, payload)
                conn.execute("UPDATE t02_router_iface_tunnel SET sync_status = 'pending_delete' WHERE iface_id = ?;", (iface_id,))
                conn.execute("UPDATE t02_router_iface_wan SET sync_status = 'pending_delete' WHERE iface_id = ?;", (iface_id,))
            elif kind == "Tunnel":
                _upsert_tunnel(conn, db, iface_id, payload)
                conn.execute("UPDATE t02_router_iface_l3 SET sync_status = 'pending_delete' WHERE iface_id = ?;", (iface_id,))
                conn.execute("UPDATE t02_router_iface_wan SET sync_status = 'pending_delete' WHERE iface_id = ?;", (iface_id,))
            else:
                _upsert_wan(conn, db, iface_id, payload)
                conn.execute("UPDATE t02_router_iface_l3 SET sync_status = 'pending_delete' WHERE iface_id = ?;", (iface_id,))
                conn.execute("UPDATE t02_router_iface_tunnel SET sync_status = 'pending_delete' WHERE iface_id = ?;", (iface_id,))

            conn.commit()
        return True
    except sqlite3.Error as exc:
        log_db_error("saveRouterInterface", exc)
        return False


def delete_router_interface(db: Any, iface_id: int) -> bool:
    try:
        with db_connection(db) as conn:
            cursor = conn.execute("UPDATE t02_interface_name SET sync_status = 'pending_delete' WHERE iface_id = ?;", (iface_id,))
            for table in (
                "t02_router_iface_l3",
                "t02_router_iface_tunnel",
                "t02_router_iface_wan",
            ):
                conn.execute(f"UPDATE {table} SET sync_status = 'pending_delete' WHERE iface_id = ?;", (iface_id,))
            conn.commit()
        return cursor.rowcount > 0
    except sqlite3.Error as exc:
        log_db_error("deleteRouterInterface", exc)
        return False
