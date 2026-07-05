from __future__ import annotations

import sqlite3
from typing import Any

from .common import as_dict, as_list, int_or_none_value, int_or_zero_value, normalize_action_cfg, normalize_process, text


CHILD_TABLE_FIELDS = {
    "eigrp_networks": "networks",
    "eigrp_interface_settings": "interface_settings",
    "eigrp_passive_interfaces": "passive_interfaces",
    "eigrp_distribute_lists": "distribute_lists",
    "eigrp_offset_lists": "offset_lists",
    "eigrp_redistribute": "redistribute",
}

CHILD_TABLES = tuple(CHILD_TABLE_FIELDS)


def child_identity_key(table: str, row: dict[str, Any]) -> tuple[Any, ...]:
    if table == "eigrp_networks":
        return (text(row.get("network")), text(row.get("wildcard")), text(row.get("interface_name")))
    if table == "eigrp_interface_settings":
        return (text(row.get("interface_name")),)
    if table == "eigrp_passive_interfaces":
        return (text(row.get("interface_name")), text(row.get("mode")) or "passive")
    if table == "eigrp_distribute_lists":
        return (text(row.get("list_name")), text(row.get("direction")) or "in", text(row.get("interface_name")))
    if table == "eigrp_offset_lists":
        return (
            text(row.get("list_name")),
            text(row.get("direction")) or "in",
            int_or_zero_value(row.get("value")),
            text(row.get("interface_name")),
        )
    if table == "eigrp_redistribute":
        return (text(row.get("protocol")), text(row.get("route_map")))
    raise ValueError(f"Unsupported table for key extraction: {table}")


def normalized_child_rows(db: Any, process: dict[str, Any], field: str) -> list[dict[str, Any]]:
    return list(normalize_process(db, process).get(field, []))


def load_process_for_compare(conn: sqlite3.Connection, db: Any, eigrp_id: int) -> dict[str, Any] | None:
    process = conn.execute(
        """
        SELECT eigrp_id, as_number, router_id, timers_active_time, bfd_all_interfaces,
               auto_summary, passive_default, metric_weights, distance_internal, distance_external,
               variance, maximum_paths, stub_enabled, stub_options, stub_leak_map,
               action, action_Cfg
        FROM eigrp_processes
        WHERE eigrp_id = ? AND success != -1
        LIMIT 1;
        """,
        (eigrp_id,),
    ).fetchone()
    if process is None:
        return None

    data = dict(process)
    data["networks"] = db._dict_rows(
        conn.execute(
            """
            SELECT network, wildcard, interface_name
            FROM eigrp_networks
            WHERE eigrp_id = ? AND success != -1
            ORDER BY id ASC;
            """,
            (eigrp_id,),
        ).fetchall()
    )
    data["interface_settings"] = db._dict_rows(
        conn.execute(
            """
            SELECT interface_name, bandwidth, delay, hello_interval, hold_time,
                   auth_key_chain, summary_ip, summary_mask, split_horizon,
                   bandwidth_percent, next_hop_self, bfd, bfd_tx, bfd_rx, bfd_multiplier
            FROM eigrp_interface_settings
            WHERE eigrp_id = ? AND success != -1
            ORDER BY id ASC;
            """,
            (eigrp_id,),
        ).fetchall()
    )
    data["passive_interfaces"] = db._dict_rows(
        conn.execute(
            """
            SELECT interface_name, mode
            FROM eigrp_passive_interfaces
            WHERE eigrp_id = ? AND success != -1
            ORDER BY id ASC;
            """,
            (eigrp_id,),
        ).fetchall()
    )
    data["distribute_lists"] = db._dict_rows(
        conn.execute(
            """
            SELECT list_name, direction, interface_name
            FROM eigrp_distribute_lists
            WHERE eigrp_id = ? AND success != -1
            ORDER BY id ASC;
            """,
            (eigrp_id,),
        ).fetchall()
    )
    data["offset_lists"] = db._dict_rows(
        conn.execute(
            """
            SELECT list_name, direction, value, interface_name
            FROM eigrp_offset_lists
            WHERE eigrp_id = ? AND success != -1
            ORDER BY id ASC;
            """,
            (eigrp_id,),
        ).fetchall()
    )
    data["redistribute"] = db._dict_rows(
        conn.execute(
            """
            SELECT protocol, route_map, metric_bw, metric_delay, metric_reliability, metric_load, metric_mtu
            FROM eigrp_redistribute
            WHERE eigrp_id = ? AND success != -1
            ORDER BY id ASC;
            """,
            (eigrp_id,),
        ).fetchall()
    )
    return data


def archive_eigrp_process(conn: sqlite3.Connection, eigrp_id: int) -> None:
    conn.execute("UPDATE eigrp_processes SET success = -1 WHERE eigrp_id = ?;", (eigrp_id,))
    for table in CHILD_TABLES:
        conn.execute(f"UPDATE {table} SET success = -1 WHERE eigrp_id = ?;", (eigrp_id,))


def insert_eigrp_process(conn: sqlite3.Connection, db: Any, host: str, process: dict[str, Any]) -> int:
    as_number = db._int_or_none(process.get("as_number"))
    if as_number is None:
        raise ValueError("EIGRP as_number is required")

    cur = conn.execute(
        """
        INSERT INTO eigrp_processes (
            host, as_number, router_id, timers_active_time, bfd_all_interfaces,
            auto_summary, passive_default, metric_weights, distance_internal,
            distance_external, variance, maximum_paths, stub_enabled,
            stub_options, stub_leak_map, action, action_Cfg, success
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0);
        """,
        (
            host,
            as_number,
            db._str_or_none(process.get("router_id")),
            db._int_or_none(process.get("timers_active_time")),
            db._bool_int(process.get("bfd_all_interfaces")),
            db._bool_int(process.get("auto_summary")),
            db._bool_int(process.get("passive_default")),
            db._str_or_none(process.get("metric_weights")) or "0 1 0 1 0 0",
            db._int_or_none(process.get("distance_internal")),
            db._int_or_none(process.get("distance_external")),
            db._int_or_none(process.get("variance")),
            db._int_or_none(process.get("maximum_paths")),
            db._bool_int(process.get("stub_enabled")),
            db._str_or_none(process.get("stub_options")),
            db._str_or_none(process.get("stub_leak_map")),
            db._int_or_none(process.get("action")) or 15,
            normalize_action_cfg(process.get("action_Cfg")),
        ),
    )
    eigrp_id = cur.lastrowid

    for table in CHILD_TABLES:
        sync_eigrp_child_table(conn, db, eigrp_id, process, table, replace_all=False)

    return eigrp_id


def update_eigrp_process_row(conn: sqlite3.Connection, db: Any, eigrp_id: int, process: dict[str, Any]) -> None:
    conn.execute(
        """
        UPDATE eigrp_processes
        SET router_id = ?,
            timers_active_time = ?,
            bfd_all_interfaces = ?,
            auto_summary = ?,
            passive_default = ?,
            metric_weights = ?,
            distance_internal = ?,
            distance_external = ?,
            variance = ?,
            maximum_paths = ?,
            stub_enabled = ?,
            stub_options = ?,
            stub_leak_map = ?,
            action = ?,
            action_Cfg = ?,
            success = 0
        WHERE eigrp_id = ?;
        """,
        (
            db._str_or_none(process.get("router_id")),
            db._int_or_none(process.get("timers_active_time")),
            db._bool_int(process.get("bfd_all_interfaces")),
            db._bool_int(process.get("auto_summary")),
            db._bool_int(process.get("passive_default")),
            db._str_or_none(process.get("metric_weights")) or "0 1 0 1 0 0",
            db._int_or_none(process.get("distance_internal")),
            db._int_or_none(process.get("distance_external")),
            db._int_or_none(process.get("variance")),
            db._int_or_none(process.get("maximum_paths")),
            db._bool_int(process.get("stub_enabled")),
            db._str_or_none(process.get("stub_options")),
            db._str_or_none(process.get("stub_leak_map")),
            db._int_or_none(process.get("action")) or 15,
            normalize_action_cfg(process.get("action_Cfg")),
            eigrp_id,
        ),
    )


def load_child_rows(conn: sqlite3.Connection, eigrp_id: int, table: str) -> list[dict[str, Any]]:
    if table == "eigrp_networks":
        rows = conn.execute(
            "SELECT id, network, wildcard, interface_name FROM eigrp_networks WHERE eigrp_id = ? AND success != -1 ORDER BY id ASC;",
            (eigrp_id,),
        ).fetchall()
    elif table == "eigrp_interface_settings":
        rows = conn.execute(
            """
            SELECT id, interface_name, bandwidth, delay, hello_interval, hold_time,
                   auth_key_chain, summary_ip, summary_mask, split_horizon,
                   bandwidth_percent, next_hop_self, bfd, bfd_tx, bfd_rx, bfd_multiplier
            FROM eigrp_interface_settings
            WHERE eigrp_id = ? AND success != -1
            ORDER BY id ASC;
            """,
            (eigrp_id,),
        ).fetchall()
    elif table == "eigrp_passive_interfaces":
        rows = conn.execute(
            "SELECT id, interface_name, mode FROM eigrp_passive_interfaces WHERE eigrp_id = ? AND success != -1 ORDER BY id ASC;",
            (eigrp_id,),
        ).fetchall()
    elif table == "eigrp_distribute_lists":
        rows = conn.execute(
            "SELECT id, list_name, direction, interface_name FROM eigrp_distribute_lists WHERE eigrp_id = ? AND success != -1 ORDER BY id ASC;",
            (eigrp_id,),
        ).fetchall()
    elif table == "eigrp_offset_lists":
        rows = conn.execute(
            "SELECT id, list_name, direction, value, interface_name FROM eigrp_offset_lists WHERE eigrp_id = ? AND success != -1 ORDER BY id ASC;",
            (eigrp_id,),
        ).fetchall()
    elif table == "eigrp_redistribute":
        rows = conn.execute(
            """
            SELECT id, protocol, route_map, metric_bw, metric_delay,
                   metric_reliability, metric_load, metric_mtu
            FROM eigrp_redistribute
            WHERE eigrp_id = ? AND success != -1
            ORDER BY id ASC;
            """,
            (eigrp_id,),
        ).fetchall()
    else:
        raise ValueError(f"Unsupported child table: {table}")
    return [dict(row) for row in rows]


def insert_child_row(conn: sqlite3.Connection, db: Any, eigrp_id: int, table: str, row: dict[str, Any]) -> None:
    if table == "eigrp_networks":
        conn.execute(
            """
            INSERT INTO eigrp_networks (eigrp_id, network, wildcard, interface_name, success)
            VALUES (?, ?, ?, ?, 0);
            """,
            (
                eigrp_id,
                db._str_or_none(row.get("network")),
                db._str_or_none(row.get("wildcard")),
                db._str_or_none(row.get("interface_name")),
            ),
        )
        return

    if table == "eigrp_interface_settings":
        conn.execute(
            """
            INSERT INTO eigrp_interface_settings (
                eigrp_id, interface_name, bandwidth, delay, hello_interval, hold_time,
                auth_key_chain, summary_ip, summary_mask, split_horizon,
                bandwidth_percent, next_hop_self, bfd, bfd_tx, bfd_rx, bfd_multiplier, success
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0);
            """,
            (
                eigrp_id,
                db._str_or_none(row.get("interface_name")),
                db._int_or_none(row.get("bandwidth")),
                db._int_or_none(row.get("delay")),
                db._int_or_none(row.get("hello_interval")),
                db._int_or_none(row.get("hold_time")),
                db._str_or_none(row.get("auth_key_chain")),
                db._str_or_none(row.get("summary_ip")),
                db._str_or_none(row.get("summary_mask")),
                db._bool_int(row.get("split_horizon")),
                db._int_or_none(row.get("bandwidth_percent")),
                db._bool_int(row.get("next_hop_self")),
                db._bool_int(row.get("bfd")),
                db._int_or_none(row.get("bfd_tx")),
                db._int_or_none(row.get("bfd_rx")),
                db._int_or_none(row.get("bfd_multiplier")),
            ),
        )
        return

    if table == "eigrp_passive_interfaces":
        conn.execute(
            """
            INSERT INTO eigrp_passive_interfaces (eigrp_id, interface_name, mode, success)
            VALUES (?, ?, ?, 0);
            """,
            (
                eigrp_id,
                db._str_or_none(row.get("interface_name")),
                db._str_or_none(row.get("mode")) or "passive",
            ),
        )
        return

    if table == "eigrp_distribute_lists":
        conn.execute(
            """
            INSERT INTO eigrp_distribute_lists (eigrp_id, list_name, direction, interface_name, success)
            VALUES (?, ?, ?, ?, 0);
            """,
            (
                eigrp_id,
                db._str_or_none(row.get("list_name")),
                db._str_or_none(row.get("direction")) or "in",
                db._str_or_none(row.get("interface_name")),
            ),
        )
        return

    if table == "eigrp_offset_lists":
        conn.execute(
            """
            INSERT INTO eigrp_offset_lists (eigrp_id, list_name, direction, value, interface_name, success)
            VALUES (?, ?, ?, ?, ?, 0);
            """,
            (
                eigrp_id,
                db._str_or_none(row.get("list_name")),
                db._str_or_none(row.get("direction")) or "in",
                db._int_or_none(row.get("value")),
                db._str_or_none(row.get("interface_name")),
            ),
        )
        return

    if table == "eigrp_redistribute":
        conn.execute(
            """
            INSERT INTO eigrp_redistribute (
                eigrp_id, protocol, route_map, metric_bw, metric_delay,
                metric_reliability, metric_load, metric_mtu, success
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0);
            """,
            (
                eigrp_id,
                db._str_or_none(row.get("protocol")),
                db._str_or_none(row.get("route_map")),
                db._int_or_none(row.get("metric_bw")),
                db._int_or_none(row.get("metric_delay")),
                db._int_or_none(row.get("metric_reliability")),
                db._int_or_none(row.get("metric_load")),
                db._int_or_none(row.get("metric_mtu")),
            ),
        )
        return

    raise ValueError(f"Unsupported child table: {table}")


def update_child_row(conn: sqlite3.Connection, db: Any, row_id: int, table: str, row: dict[str, Any]) -> None:
    if table == "eigrp_networks":
        conn.execute(
            """
            UPDATE eigrp_networks
            SET network = ?, wildcard = ?, interface_name = ?, success = 0
            WHERE id = ?;
            """,
            (
                db._str_or_none(row.get("network")),
                db._str_or_none(row.get("wildcard")),
                db._str_or_none(row.get("interface_name")),
                row_id,
            ),
        )
        return

    if table == "eigrp_interface_settings":
        conn.execute(
            """
            UPDATE eigrp_interface_settings
            SET bandwidth = ?, delay = ?, hello_interval = ?, hold_time = ?,
                auth_key_chain = ?, summary_ip = ?, summary_mask = ?, split_horizon = ?,
                bandwidth_percent = ?, next_hop_self = ?, bfd = ?, bfd_tx = ?, bfd_rx = ?,
                bfd_multiplier = ?, success = 0
            WHERE id = ?;
            """,
            (
                db._int_or_none(row.get("bandwidth")),
                db._int_or_none(row.get("delay")),
                db._int_or_none(row.get("hello_interval")),
                db._int_or_none(row.get("hold_time")),
                db._str_or_none(row.get("auth_key_chain")),
                db._str_or_none(row.get("summary_ip")),
                db._str_or_none(row.get("summary_mask")),
                db._bool_int(row.get("split_horizon")),
                db._int_or_none(row.get("bandwidth_percent")),
                db._bool_int(row.get("next_hop_self")),
                db._bool_int(row.get("bfd")),
                db._int_or_none(row.get("bfd_tx")),
                db._int_or_none(row.get("bfd_rx")),
                db._int_or_none(row.get("bfd_multiplier")),
                row_id,
            ),
        )
        return

    if table == "eigrp_passive_interfaces":
        conn.execute(
            "UPDATE eigrp_passive_interfaces SET interface_name = ?, mode = ?, success = 0 WHERE id = ?;",
            (
                db._str_or_none(row.get("interface_name")),
                db._str_or_none(row.get("mode")) or "passive",
                row_id,
            ),
        )
        return

    if table == "eigrp_distribute_lists":
        conn.execute(
            """
            UPDATE eigrp_distribute_lists
            SET list_name = ?, direction = ?, interface_name = ?, success = 0
            WHERE id = ?;
            """,
            (
                db._str_or_none(row.get("list_name")),
                db._str_or_none(row.get("direction")) or "in",
                db._str_or_none(row.get("interface_name")),
                row_id,
            ),
        )
        return

    if table == "eigrp_offset_lists":
        conn.execute(
            """
            UPDATE eigrp_offset_lists
            SET list_name = ?, direction = ?, value = ?, interface_name = ?, success = 0
            WHERE id = ?;
            """,
            (
                db._str_or_none(row.get("list_name")),
                db._str_or_none(row.get("direction")) or "in",
                db._int_or_none(row.get("value")),
                db._str_or_none(row.get("interface_name")),
                row_id,
            ),
        )
        return

    if table == "eigrp_redistribute":
        conn.execute(
            """
            UPDATE eigrp_redistribute
            SET protocol = ?, route_map = ?, metric_bw = ?, metric_delay = ?,
                metric_reliability = ?, metric_load = ?, metric_mtu = ?, success = 0
            WHERE id = ?;
            """,
            (
                db._str_or_none(row.get("protocol")),
                db._str_or_none(row.get("route_map")),
                db._int_or_none(row.get("metric_bw")),
                db._int_or_none(row.get("metric_delay")),
                db._int_or_none(row.get("metric_reliability")),
                db._int_or_none(row.get("metric_load")),
                db._int_or_none(row.get("metric_mtu")),
                row_id,
            ),
        )
        return

    raise ValueError(f"Unsupported child table: {table}")


def sync_eigrp_child_table(
    conn: sqlite3.Connection,
    db: Any,
    eigrp_id: int,
    process: dict[str, Any],
    table: str,
    *,
    replace_all: bool,
) -> None:
    field = CHILD_TABLE_FIELDS[table]
    submitted_rows = normalized_child_rows(db, process, field)

    if replace_all:
        conn.execute(f"UPDATE {table} SET success = -1 WHERE eigrp_id = ?;", (eigrp_id,))

    existing_rows = load_child_rows(conn, eigrp_id, table) if not replace_all else []
    existing_by_key = {child_identity_key(table, row): row for row in existing_rows}
    submitted_by_key = {child_identity_key(table, row): row for row in submitted_rows}

    for key, existing in existing_by_key.items():
        if key not in submitted_by_key:
            conn.execute(f"UPDATE {table} SET success = -1 WHERE id = ?;", (existing['id'],))

    for key, submitted in submitted_by_key.items():
        existing = existing_by_key.get(key)
        if existing is None:
            insert_child_row(conn, db, eigrp_id, table, submitted)
            continue
        current = dict(existing)
        current.pop("id", None)
        if current != submitted:
            update_child_row(conn, db, existing["id"], table, submitted)
        else:
            conn.execute(f"UPDATE {table} SET success = 0 WHERE id = ?;", (existing["id"],))
