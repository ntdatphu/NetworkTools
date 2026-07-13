"""NAT CRUD operations for all NAT tables.

Schema references (from main_numbered_tables.sql):
  t05_NAT_DB                   — parent NAT entry
  t05_nat_static_mappings      — Static NAT
  t05_nat_interfaces           — NAT interface roles (inside/outside)
  t05_nat_pools                — NAT pools (used by Dynamic rules)
  t05_nat_dynamic_rules        — Dynamic NAT rules (pool-based)
  t05_nat_overload_interface_rules — PAT (overload via interface)
  t05_NAT_ACL_DB               — NAT ACL (standard/extended)
  t05_nat_standard_acl_rules   — NAT ACL standard rules
  t05_nat_extended_acl_rules   — NAT ACL extended rules
  t05_route_map_db             — Route Map
  t05_route_map_entries        — Route Map entries

Design note:
  The QML forms (NatStaticForm, NatDynamicForm, ...) use flat slot APIs
  (addNatStaticEntry, addNatDynamicPool, ...) without a nat_id parent.
  To keep the QML unchanged we transparently get-or-create a NAT_DB entry
  using the host + nat_type as a single composite key, then attach child
  rows to it. This is an implementation detail not visible to the UI.
"""
from __future__ import annotations

import sqlite3
from typing import Any

from .common import (
    bool_to_int,
    int_or_none,
    log_db_error,
    normalize_host,
    soft_delete,
    text_or_default,
    text_or_none,
)


# ── Internal helper: get-or-create NAT_DB entry ───────────────────────────────

def _get_or_create_nat_id(conn: sqlite3.Connection, host: str, nat_type: str, nat_name: str) -> int:
    """Return an existing active nat_id or insert a new t05_NAT_DB row."""
    row = conn.execute(
        """
        SELECT nat_id FROM t05_NAT_DB
        WHERE host = ? AND nat_name = ? AND nat_type = ? AND success != -1
        LIMIT 1;
        """,
        (host, nat_name, nat_type),
    ).fetchone()
    if row:
        return int(row[0])
    cursor = conn.execute(
        """
        INSERT INTO t05_NAT_DB (nat_name, nat_type, host, success, action_Cfg)
        VALUES (?, ?, ?, 0, 1);
        """,
        (nat_name, nat_type, host),
    )
    return cursor.lastrowid  # type: ignore[return-value]


# ── Static NAT ────────────────────────────────────────────────────────────────

def get_nat_static_entries(db: Any, host: str) -> list[dict[str, Any]]:
    host = normalize_host(host)
    if not host:
        return []
    try:
        with db._connect() as conn:
            rows = conn.execute(
                """
                SELECT m.id, m.nat_id, m.inside_local_ip, m.inside_global_ip,
                       m.protocol, m.local_port, m.global_port,
                       m.is_extendable, m.description, m.success
                FROM t05_nat_static_mappings m
                JOIN t05_NAT_DB n ON n.nat_id = m.nat_id
                WHERE n.host = ? AND n.nat_type = 'static'
                  AND n.success != -1 AND m.success != -1
                ORDER BY m.id ASC;
                """,
                (host,),
            ).fetchall()
        return [dict(r) for r in rows]
    except sqlite3.Error as exc:
        log_db_error("getNatStaticEntries", exc)
        return []


def add_nat_static_entry(
    db: Any,
    host: str,
    local_ip: str,
    global_ip: str,
    protocol: str,
    local_port: str,
    global_port: str,
) -> bool:
    host = normalize_host(host)
    local_ip = text_or_default(local_ip, "")
    global_ip = text_or_default(global_ip, "")
    if not host or not local_ip or not global_ip:
        return False

    protocol_val = text_or_none(protocol)
    local_port_val = int_or_none(local_port)
    global_port_val = int_or_none(global_port)

    try:
        with db._connect() as conn:
            nat_id = _get_or_create_nat_id(conn, host, "static", f"static_{host}")
            conn.execute(
                """
                INSERT INTO t05_nat_static_mappings
                    (nat_id, inside_local_ip, inside_global_ip, protocol,
                     local_port, global_port, success)
                VALUES (?, ?, ?, ?, ?, ?, 0);
                """,
                (nat_id, local_ip, global_ip, protocol_val, local_port_val, global_port_val),
            )
            conn.commit()
        return True
    except sqlite3.Error as exc:
        log_db_error("addNatStaticEntry", exc)
        return False


def delete_nat_static_entry(db: Any, nat_static_id: int) -> bool:
    if nat_static_id <= 0:
        return False
    try:
        with db._connect() as conn:
            deleted = soft_delete(conn, "t05_nat_static_mappings", "id", nat_static_id)
            conn.commit()
        return deleted
    except sqlite3.Error as exc:
        log_db_error("deleteNatStaticEntry", exc)
        return False


# ── NAT Interfaces ────────────────────────────────────────────────────────────

def get_nat_interfaces(db: Any, host: str) -> list[dict[str, Any]]:
    host = normalize_host(host)
    if not host:
        return []
    try:
        with db._connect() as conn:
            rows = conn.execute(
                """
                SELECT i.id, i.nat_id, i.t02_interface_name AS interface_name,
                       i.nat_role, i.success
                FROM t05_nat_interfaces i
                JOIN t05_NAT_DB n ON n.nat_id = i.nat_id
                WHERE n.host = ? AND n.success != -1 AND i.success != -1
                ORDER BY i.id ASC;
                """,
                (host,),
            ).fetchall()
        return [dict(r) for r in rows]
    except sqlite3.Error as exc:
        log_db_error("getNatInterfaces", exc)
        return []


def add_nat_interface(db: Any, host: str, interface_name: str, nat_role: str) -> bool:
    host = normalize_host(host)
    interface_name = text_or_default(interface_name, "")
    nat_role = text_or_default(nat_role, "inside")
    if not host or not interface_name:
        return False
    if nat_role not in ("inside", "outside"):
        nat_role = "inside"
    try:
        with db._connect() as conn:
            nat_id = _get_or_create_nat_id(conn, host, "static", f"nat_iface_{host}")
            conn.execute(
                """
                INSERT INTO t05_nat_interfaces (nat_id, t02_interface_name, nat_role, success)
                VALUES (?, ?, ?, 0);
                """,
                (nat_id, interface_name, nat_role),
            )
            conn.commit()
        return True
    except sqlite3.Error as exc:
        log_db_error("addNatInterface", exc)
        return False


def delete_nat_interface(db: Any, nat_intf_id: int) -> bool:
    if nat_intf_id <= 0:
        return False
    try:
        with db._connect() as conn:
            deleted = soft_delete(conn, "t05_nat_interfaces", "id", nat_intf_id)
            conn.commit()
        return deleted
    except sqlite3.Error as exc:
        log_db_error("deleteNatInterface", exc)
        return False


# ── Dynamic NAT (pool-based) ──────────────────────────────────────────────────

def get_nat_dynamic_pools(db: Any, host: str) -> list[dict[str, Any]]:
    host = normalize_host(host)
    if not host:
        return []
    try:
        with db._connect() as conn:
            rows = conn.execute(
                """
                SELECT p.pool_id, p.nat_id, p.pool_name, p.start_ip,
                       p.end_ip, p.netmask, p.prefix_length, p.success
                FROM t05_nat_pools p
                JOIN t05_NAT_DB n ON n.nat_id = p.nat_id
                WHERE n.host = ? AND n.nat_type = 'dynamic'
                  AND n.success != -1 AND p.success != -1
                ORDER BY p.pool_id ASC;
                """,
                (host,),
            ).fetchall()
        return [dict(r) for r in rows]
    except sqlite3.Error as exc:
        log_db_error("getNatDynamicPools", exc)
        return []


def add_nat_dynamic_pool(
    db: Any,
    host: str,
    pool_name: str,
    start_ip: str,
    end_ip: str,
    netmask: str,
    acl_name: str,
) -> bool:
    host = normalize_host(host)
    pool_name = text_or_default(pool_name, "")
    start_ip = text_or_default(start_ip, "")
    end_ip = text_or_default(end_ip, "")
    if not host or not pool_name or not start_ip or not end_ip:
        return False
    try:
        with db._connect() as conn:
            nat_id = _get_or_create_nat_id(conn, host, "dynamic", f"dynamic_{host}")
            conn.execute(
                """
                INSERT INTO t05_nat_pools (nat_id, pool_name, start_ip, end_ip, netmask, success)
                VALUES (?, ?, ?, ?, ?, 0);
                """,
                (nat_id, pool_name, start_ip, end_ip, text_or_none(netmask)),
            )
            conn.commit()
        return True
    except sqlite3.Error as exc:
        log_db_error("addNatDynamicPool", exc)
        return False


def delete_nat_dynamic_pool(db: Any, nat_dynamic_id: int) -> bool:
    if nat_dynamic_id <= 0:
        return False
    try:
        with db._connect() as conn:
            deleted = soft_delete(conn, "t05_nat_pools", "pool_id", nat_dynamic_id)
            conn.commit()
        return deleted
    except sqlite3.Error as exc:
        log_db_error("deleteNatDynamicPool", exc)
        return False


# ── PAT (overload via interface) ──────────────────────────────────────────────

def get_nat_pat_rules(db: Any, host: str) -> list[dict[str, Any]]:
    host = normalize_host(host)
    if not host:
        return []
    try:
        with db._connect() as conn:
            rows = conn.execute(
                """
                SELECT r.id, r.nat_id, r.nat_acl_id, r.outside_interface,
                       r.overload, r.description, r.success,
                       a.acl_name
                FROM t05_nat_overload_interface_rules r
                JOIN t05_NAT_DB n ON n.nat_id = r.nat_id
                LEFT JOIN t05_NAT_ACL_DB a ON a.nat_acl_id = r.nat_acl_id
                WHERE n.host = ? AND n.nat_type = 'overload'
                  AND n.success != -1 AND r.success != -1
                ORDER BY r.id ASC;
                """,
                (host,),
            ).fetchall()
        return [dict(r) for r in rows]
    except sqlite3.Error as exc:
        log_db_error("getNatPatRules", exc)
        return []


def _get_or_create_nat_acl_id(conn: sqlite3.Connection, host: str, acl_name: str) -> int | None:
    """Look up an existing NAT_ACL_DB entry by host + acl_name."""
    row = conn.execute(
        """
        SELECT nat_acl_id FROM t05_NAT_ACL_DB
        WHERE host = ? AND acl_name = ? AND success != -1
        LIMIT 1;
        """,
        (host, acl_name),
    ).fetchone()
    return int(row[0]) if row else None


def add_nat_pat_rule(
    db: Any,
    host: str,
    acl_name: str,
    source_type: str,
    source_value: str,
    overload: bool,
) -> bool:
    host = normalize_host(host)
    if not host or not acl_name:
        return False
    try:
        with db._connect() as conn:
            nat_id = _get_or_create_nat_id(conn, host, "overload", f"pat_{host}")
            nat_acl_id = _get_or_create_nat_acl_id(conn, host, acl_name)
            if nat_acl_id is None:
                # Create a minimal NAT ACL placeholder so the FK is satisfied
                cursor = conn.execute(
                    """
                    INSERT INTO t05_NAT_ACL_DB (acl_name, acl_type, host, success, action_Cfg)
                    VALUES (?, 'standard', ?, 0, 1);
                    """,
                    (acl_name, host),
                )
                nat_acl_id = cursor.lastrowid

            outside_iface = text_or_default(source_value if source_type == "interface" else None, "")
            conn.execute(
                """
                INSERT INTO t05_nat_overload_interface_rules
                    (nat_id, nat_acl_id, outside_interface, overload, success)
                VALUES (?, ?, ?, ?, 0);
                """,
                (nat_id, nat_acl_id, outside_iface, bool_to_int(overload)),
            )
            conn.commit()
        return True
    except sqlite3.Error as exc:
        log_db_error("addNatPatRule", exc)
        return False


def delete_nat_pat_rule(db: Any, nat_pat_id: int) -> bool:
    if nat_pat_id <= 0:
        return False
    try:
        with db._connect() as conn:
            deleted = soft_delete(conn, "t05_nat_overload_interface_rules", "id", nat_pat_id)
            conn.commit()
        return deleted
    except sqlite3.Error as exc:
        log_db_error("deleteNatPatRule", exc)
        return False


# ── NAT ACL ───────────────────────────────────────────────────────────────────

def get_nat_acls(db: Any, host: str) -> list[dict[str, Any]]:
    host = normalize_host(host)
    if not host:
        return []
    try:
        with db._connect() as conn:
            acl_rows = conn.execute(
                """
                SELECT nat_acl_id, acl_name, acl_type, host, description, success
                FROM t05_NAT_ACL_DB
                WHERE host = ? AND success != -1
                ORDER BY nat_acl_id ASC;
                """,
                (host,),
            ).fetchall()
            result: list[dict[str, Any]] = []
            for row in acl_rows:
                acl = dict(row)
                acl_id = acl["nat_acl_id"]
                # Fetch rules
                std_rows = conn.execute(
                    "SELECT * FROM t05_nat_standard_acl_rules WHERE nat_acl_id = ? AND success != -1 ORDER BY sequence ASC, id ASC;",
                    (acl_id,),
                ).fetchall()
                ext_rows = conn.execute(
                    "SELECT * FROM t05_nat_extended_acl_rules WHERE nat_acl_id = ? AND success != -1 ORDER BY sequence ASC, id ASC;",
                    (acl_id,),
                ).fetchall()
                acl["rules"] = [dict(r) for r in std_rows + ext_rows]
                result.append(acl)
        return result
    except sqlite3.Error as exc:
        log_db_error("getNatAcls", exc)
        return []


def add_nat_acl(
    db: Any,
    host: str,
    acl_name: str,
    action: str,
    source_network: str,
    wildcard: str,
) -> bool:
    host = normalize_host(host)
    acl_name = text_or_default(acl_name, "")
    if not host or not acl_name:
        return False
    try:
        with db._connect() as conn:
            # Get or create NAT_ACL_DB entry
            nat_acl_id = _get_or_create_nat_acl_id(conn, host, acl_name)
            if nat_acl_id is None:
                cursor = conn.execute(
                    """
                    INSERT INTO t05_NAT_ACL_DB (acl_name, acl_type, host, success, action_Cfg)
                    VALUES (?, 'standard', ?, 0, 1);
                    """,
                    (acl_name, host),
                )
                nat_acl_id = cursor.lastrowid

            conn.execute(
                """
                INSERT INTO t05_nat_standard_acl_rules
                    (nat_acl_id, action, source, wildcard, success)
                VALUES (?, ?, ?, ?, 0);
                """,
                (nat_acl_id, text_or_default(action, "permit"),
                 text_or_default(source_network, "any"),
                 text_or_none(wildcard)),
            )
            conn.commit()
        return True
    except sqlite3.Error as exc:
        log_db_error("addNatAcl", exc)
        return False


def delete_nat_acl(db: Any, nat_acl_id: int) -> bool:
    if nat_acl_id <= 0:
        return False
    try:
        with db._connect() as conn:
            deleted = soft_delete(conn, "t05_NAT_ACL_DB", "nat_acl_id", nat_acl_id)
            conn.commit()
        return deleted
    except sqlite3.Error as exc:
        log_db_error("deleteNatAcl", exc)
        return False


# ── Route Map ─────────────────────────────────────────────────────────────────

def get_nat_route_map_entries(db: Any, host: str) -> list[dict[str, Any]]:
    host = normalize_host(host)
    if not host:
        return []
    try:
        with db._connect() as conn:
            rows = conn.execute(
                """
                SELECT rm.route_map_id, rm.route_map_name, rm.host,
                       rm.description, rm.success,
                       e.id AS entry_id, e.sequence, e.action,
                       e.nat_acl_id, a.acl_name
                FROM t05_route_map_db rm
                LEFT JOIN t05_route_map_entries e ON e.route_map_id = rm.route_map_id
                LEFT JOIN t05_NAT_ACL_DB a ON a.nat_acl_id = e.nat_acl_id
                WHERE rm.host = ? AND rm.success != -1
                ORDER BY rm.route_map_id ASC, e.sequence ASC;
                """,
                (host,),
            ).fetchall()
        return [dict(r) for r in rows]
    except sqlite3.Error as exc:
        log_db_error("getNatRouteMapEntries", exc)
        return []


def add_nat_route_map_entry(
    db: Any,
    host: str,
    route_map_name: str,
    description: str,
    sequence: int,
    action: str,
    acl_name: str,
) -> bool:
    host = normalize_host(host)
    route_map_name = text_or_default(route_map_name, "")
    if not host or not route_map_name:
        return False
    try:
        with db._connect() as conn:
            # Get or create route_map_db entry
            rm_row = conn.execute(
                """
                SELECT route_map_id FROM t05_route_map_db
                WHERE host = ? AND route_map_name = ? AND success != -1
                LIMIT 1;
                """,
                (host, route_map_name),
            ).fetchone()
            if rm_row:
                rm_id = int(rm_row[0])
            else:
                cursor = conn.execute(
                    """
                    INSERT INTO t05_route_map_db (route_map_name, host, description, success)
                    VALUES (?, ?, ?, 0);
                    """,
                    (route_map_name, host, text_or_none(description)),
                )
                rm_id = cursor.lastrowid

            # Resolve nat_acl_id if acl_name given
            nat_acl_id: int | None = None
            if acl_name:
                nat_acl_id = _get_or_create_nat_acl_id(conn, host, acl_name)

            action_val = "permit" if str(action or "permit").strip().lower() == "permit" else "deny"
            conn.execute(
                """
                INSERT INTO t05_route_map_entries (route_map_id, sequence, action, nat_acl_id, success)
                VALUES (?, ?, ?, ?, 0);
                """,
                (rm_id, int(sequence or 10), action_val, nat_acl_id),
            )
            conn.commit()
        return True
    except sqlite3.Error as exc:
        log_db_error("addNatRouteMapEntry", exc)
        return False


def delete_nat_route_map_entry(db: Any, route_map_entry_id: int) -> bool:
    if route_map_entry_id <= 0:
        return False
    try:
        with db._connect() as conn:
            # Route map entries don't have success col — hard delete
            cursor = conn.execute(
                "DELETE FROM t05_route_map_entries WHERE id = ?;",
                (route_map_entry_id,),
            )
            conn.commit()
        return cursor.rowcount > 0
    except sqlite3.Error as exc:
        log_db_error("deleteNatRouteMapEntry", exc)
        return False
