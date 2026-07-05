from __future__ import annotations

import sqlite3
from typing import Any

from .child_sync import CHILD_TABLES, sync_eigrp_child_table
from .common import normalize_action_cfg


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
