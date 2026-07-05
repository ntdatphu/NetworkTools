from __future__ import annotations

import sqlite3
import sys
from typing import Any


def get_eigrp_routing(db: Any, host: str) -> dict[str, Any]:
    host = (host or "").strip()
    if not host:
        return {"ok": False, "message": "Host is empty", "processes": []}

    try:
        with db._connect() as conn:
            key_chains = db._dict_rows(
                conn.execute(
                    """
                    SELECT id, chain_name, key_id, key_string, accept_lifetime, send_lifetime, success
                    FROM eigrp_key_chains
                    WHERE host = ? AND success != -1
                    ORDER BY id ASC;
                    """,
                    (host,),
                ).fetchall()
            )
            process_rows = conn.execute(
                """
                SELECT eigrp_id, as_number, router_id, timers_active_time, bfd_all_interfaces,
                       auto_summary, passive_default, metric_weights, distance_internal, distance_external,
                       variance, maximum_paths, stub_enabled, stub_options, stub_leak_map,
                       action, action_Cfg, success
                FROM eigrp_processes
                WHERE host = ? AND success != -1
                ORDER BY eigrp_id ASC;
                """,
                (host,),
            ).fetchall()

            processes: list[dict[str, Any]] = []
            for process_row in process_rows:
                eigrp_id = process_row["eigrp_id"]
                process = dict(process_row)
                process["networks"] = db._dict_rows(
                    conn.execute(
                        """
                        SELECT id, network, wildcard, interface_name, success
                        FROM eigrp_networks
                        WHERE eigrp_id = ? AND success != -1
                        ORDER BY id ASC;
                        """,
                        (eigrp_id,),
                    ).fetchall()
                )
                process["interface_settings"] = db._dict_rows(
                    conn.execute(
                        """
                        SELECT id, interface_name, bandwidth, delay, hello_interval, hold_time,
                               auth_key_chain, summary_ip, summary_mask, split_horizon,
                               bandwidth_percent, next_hop_self, bfd, bfd_tx, bfd_rx,
                               bfd_multiplier, success
                        FROM eigrp_interface_settings
                        WHERE eigrp_id = ? AND success != -1
                        ORDER BY id ASC;
                        """,
                        (eigrp_id,),
                    ).fetchall()
                )
                process["passive_interfaces"] = db._dict_rows(
                    conn.execute(
                        """
                        SELECT id, interface_name, mode, success
                        FROM eigrp_passive_interfaces
                        WHERE eigrp_id = ? AND success != -1
                        ORDER BY id ASC;
                        """,
                        (eigrp_id,),
                    ).fetchall()
                )
                process["distribute_lists"] = db._dict_rows(
                    conn.execute(
                        """
                        SELECT id, list_name, direction, interface_name, success
                        FROM eigrp_distribute_lists
                        WHERE eigrp_id = ? AND success != -1
                        ORDER BY id ASC;
                        """,
                        (eigrp_id,),
                    ).fetchall()
                )
                process["offset_lists"] = db._dict_rows(
                    conn.execute(
                        """
                        SELECT id, list_name, direction, value, interface_name, success
                        FROM eigrp_offset_lists
                        WHERE eigrp_id = ? AND success != -1
                        ORDER BY id ASC;
                        """,
                        (eigrp_id,),
                    ).fetchall()
                )
                process["redistribute"] = db._dict_rows(
                    conn.execute(
                        """
                        SELECT id, protocol, route_map, metric_bw, metric_delay,
                               metric_reliability, metric_load, metric_mtu, success
                        FROM eigrp_redistribute
                        WHERE eigrp_id = ? AND success != -1
                        ORDER BY id ASC;
                        """,
                        (eigrp_id,),
                    ).fetchall()
                )
                process["key_chains"] = key_chains
                processes.append(process)

        return {"ok": True, "message": "Loaded EIGRP routing", "processes": processes}
    except sqlite3.Error as exc:
        print(f"[db] getEigrpRouting failed: {exc}", file=sys.stderr)
        return {"ok": False, "message": str(exc), "processes": []}


def _text(value: Any) -> str:
    return "" if value is None else str(value).strip()


def _int_or_zero_value(value: Any) -> int:
    if value is None or value == "":
        return 0
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value) if value.is_integer() else 0
    try:
        text = str(value).strip()
        return int(text)
    except (TypeError, ValueError):
        try:
            number = float(str(value).strip())
        except (TypeError, ValueError):
            return 0
        return int(number) if number.is_integer() else 0


def _int_or_none_value(value: Any) -> int | None:
    if value is None or value == "":
        return None
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value) if value.is_integer() else None
    try:
        text = str(value).strip()
        return int(text)
    except (TypeError, ValueError):
        try:
            number = float(str(value).strip())
        except (TypeError, ValueError):
            return None
        return int(number) if number.is_integer() else None


def _bool_int_value(value: Any) -> int:
    if isinstance(value, str):
        return 1 if value.strip().lower() in {"1", "true", "yes", "on"} else 0
    return 1 if bool(value) else 0


def _as_list(db: Any, value: Any) -> list[Any]:
    return db._as_list(value)


def _as_dict(db: Any, value: Any) -> dict[str, Any]:
    return db._as_dict(value)


def _normalize_action_cfg(value: Any) -> str:
    text = _text(value)
    return text if len(text) == 7 and all(ch in "01" for ch in text) else "1111111"


def _normalize_process(db: Any, process: dict[str, Any]) -> dict[str, Any]:
    return {
        "as_number": _int_or_none_value(process.get("as_number")),
        "router_id": _text(process.get("router_id")),
        "timers_active_time": _int_or_zero_value(process.get("timers_active_time")),
        "bfd_all_interfaces": _bool_int_value(process.get("bfd_all_interfaces")),
        "auto_summary": _bool_int_value(process.get("auto_summary")),
        "passive_default": _bool_int_value(process.get("passive_default")),
        "metric_weights": _text(process.get("metric_weights")) or "0 1 0 1 0 0",
        "distance_internal": _int_or_zero_value(process.get("distance_internal")),
        "distance_external": _int_or_zero_value(process.get("distance_external")),
        "variance": _int_or_zero_value(process.get("variance")),
        "maximum_paths": _int_or_zero_value(process.get("maximum_paths")),
        "stub_enabled": _bool_int_value(process.get("stub_enabled")),
        "stub_options": _text(process.get("stub_options")),
        "stub_leak_map": _text(process.get("stub_leak_map")),
        "action": _int_or_none_value(process.get("action")) or 15,
        "action_Cfg": _normalize_action_cfg(process.get("action_Cfg")),
        "networks": [
            {
                "network": _text(row.get("network")),
                "wildcard": _text(row.get("wildcard")),
                "interface_name": _text(row.get("interface_name")),
            }
            for row in (_as_dict(db, value) for value in _as_list(db, process.get("networks")))
            if _text(row.get("network"))
        ],
        "interface_settings": [
            {
                "interface_name": _text(row.get("interface_name")),
                "bandwidth": _int_or_zero_value(row.get("bandwidth")),
                "delay": _int_or_zero_value(row.get("delay")),
                "hello_interval": _int_or_zero_value(row.get("hello_interval")),
                "hold_time": _int_or_zero_value(row.get("hold_time")),
                "auth_key_chain": _text(row.get("auth_key_chain")),
                "summary_ip": _text(row.get("summary_ip")),
                "summary_mask": _text(row.get("summary_mask")),
                "split_horizon": _bool_int_value(row.get("split_horizon")),
                "bandwidth_percent": _int_or_zero_value(row.get("bandwidth_percent")),
                "next_hop_self": _bool_int_value(row.get("next_hop_self")),
                "bfd": _bool_int_value(row.get("bfd")),
                "bfd_tx": _int_or_zero_value(row.get("bfd_tx")),
                "bfd_rx": _int_or_zero_value(row.get("bfd_rx")),
                "bfd_multiplier": _int_or_zero_value(row.get("bfd_multiplier")),
            }
            for row in (_as_dict(db, value) for value in _as_list(db, process.get("interface_settings")))
            if _text(row.get("interface_name"))
        ],
        "passive_interfaces": [
            {
                "interface_name": _text(row.get("interface_name")),
                "mode": _text(row.get("mode")) or "passive",
            }
            for row in (_as_dict(db, value) for value in _as_list(db, process.get("passive_interfaces")))
            if _text(row.get("interface_name"))
        ],
        "distribute_lists": [
            {
                "list_name": _text(row.get("list_name")),
                "direction": _text(row.get("direction")) or "in",
                "interface_name": _text(row.get("interface_name")),
            }
            for row in (_as_dict(db, value) for value in _as_list(db, process.get("distribute_lists")))
            if _text(row.get("list_name"))
        ],
        "offset_lists": [
            {
                "list_name": _text(row.get("list_name")),
                "direction": _text(row.get("direction")) or "in",
                "value": _int_or_zero_value(row.get("value")),
                "interface_name": _text(row.get("interface_name")),
            }
            for row in (_as_dict(db, value) for value in _as_list(db, process.get("offset_lists")))
            if _text(row.get("list_name")) and _int_or_zero_value(row.get("value")) > 0
        ],
        "redistribute": [
            {
                "protocol": _text(row.get("protocol")),
                "route_map": _text(row.get("route_map")),
                "metric_bw": _int_or_zero_value(row.get("metric_bw")),
                "metric_delay": _int_or_zero_value(row.get("metric_delay")),
                "metric_reliability": _int_or_zero_value(row.get("metric_reliability")),
                "metric_load": _int_or_zero_value(row.get("metric_load")),
                "metric_mtu": _int_or_zero_value(row.get("metric_mtu")),
            }
            for row in (_as_dict(db, value) for value in _as_list(db, process.get("redistribute")))
            if _text(row.get("protocol"))
        ],
    }


def _child_identity_key(table: str, row: dict[str, Any]) -> tuple[Any, ...]:
    if table == "eigrp_networks":
        return (_text(row.get("network")), _text(row.get("wildcard")), _text(row.get("interface_name")))
    if table == "eigrp_interface_settings":
        return (_text(row.get("interface_name")),)
    if table == "eigrp_passive_interfaces":
        return (_text(row.get("interface_name")), _text(row.get("mode")) or "passive")
    if table == "eigrp_distribute_lists":
        return (_text(row.get("list_name")), _text(row.get("direction")) or "in", _text(row.get("interface_name")))
    if table == "eigrp_offset_lists":
        return (
            _text(row.get("list_name")),
            _text(row.get("direction")) or "in",
            _int_or_zero_value(row.get("value")),
            _text(row.get("interface_name")),
        )
    if table == "eigrp_redistribute":
        return (_text(row.get("protocol")), _text(row.get("route_map")))
    raise ValueError(f"Unsupported table for key extraction: {table}")


def _normalized_child_rows(db: Any, process: dict[str, Any], field: str) -> list[dict[str, Any]]:
    return list(_normalize_process(db, process).get(field, []))


def _load_process_for_compare(conn: sqlite3.Connection, db: Any, eigrp_id: int) -> dict[str, Any] | None:
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


def _archive_eigrp_process(conn: sqlite3.Connection, eigrp_id: int) -> None:
    conn.execute("UPDATE eigrp_processes SET success = -1 WHERE eigrp_id = ?;", (eigrp_id,))
    for table in (
        "eigrp_networks",
        "eigrp_interface_settings",
        "eigrp_passive_interfaces",
        "eigrp_distribute_lists",
        "eigrp_offset_lists",
        "eigrp_redistribute",
    ):
        conn.execute(f"UPDATE {table} SET success = -1 WHERE eigrp_id = ?;", (eigrp_id,))


def _insert_eigrp_process(conn: sqlite3.Connection, db: Any, host: str, process: dict[str, Any]) -> int:
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
            _normalize_action_cfg(process.get("action_Cfg")),
        ),
    )
    eigrp_id = cur.lastrowid

    _sync_eigrp_child_table(conn, db, eigrp_id, process, "eigrp_networks", replace_all=False)
    _sync_eigrp_child_table(conn, db, eigrp_id, process, "eigrp_interface_settings", replace_all=False)
    _sync_eigrp_child_table(conn, db, eigrp_id, process, "eigrp_passive_interfaces", replace_all=False)
    _sync_eigrp_child_table(conn, db, eigrp_id, process, "eigrp_distribute_lists", replace_all=False)
    _sync_eigrp_child_table(conn, db, eigrp_id, process, "eigrp_offset_lists", replace_all=False)
    _sync_eigrp_child_table(conn, db, eigrp_id, process, "eigrp_redistribute", replace_all=False)

    return eigrp_id


def _update_eigrp_process_row(conn: sqlite3.Connection, db: Any, eigrp_id: int, process: dict[str, Any]) -> None:
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
            _normalize_action_cfg(process.get("action_Cfg")),
            eigrp_id,
        ),
    )


def _load_child_rows(conn: sqlite3.Connection, eigrp_id: int, table: str) -> list[dict[str, Any]]:
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


def _insert_child_row(conn: sqlite3.Connection, db: Any, eigrp_id: int, table: str, row: dict[str, Any]) -> None:
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


def _update_child_row(conn: sqlite3.Connection, db: Any, row_id: int, table: str, row: dict[str, Any]) -> None:
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


def _sync_eigrp_child_table(
    conn: sqlite3.Connection,
    db: Any,
    eigrp_id: int,
    process: dict[str, Any],
    table: str,
    *,
    replace_all: bool,
) -> None:
    field_map = {
        "eigrp_networks": "networks",
        "eigrp_interface_settings": "interface_settings",
        "eigrp_passive_interfaces": "passive_interfaces",
        "eigrp_distribute_lists": "distribute_lists",
        "eigrp_offset_lists": "offset_lists",
        "eigrp_redistribute": "redistribute",
    }
    field = field_map[table]
    submitted_rows = _normalized_child_rows(db, process, field)

    if replace_all:
        conn.execute(f"UPDATE {table} SET success = -1 WHERE eigrp_id = ?;", (eigrp_id,))

    existing_rows = _load_child_rows(conn, eigrp_id, table) if not replace_all else []
    existing_by_key = {_child_identity_key(table, row): row for row in existing_rows}
    submitted_by_key = {_child_identity_key(table, row): row for row in submitted_rows}

    for key, existing in existing_by_key.items():
        if key not in submitted_by_key:
            conn.execute(f"UPDATE {table} SET success = -1 WHERE id = ?;", (existing["id"],))

    for key, submitted in submitted_by_key.items():
        existing = existing_by_key.get(key)
        if existing is None:
            _insert_child_row(conn, db, eigrp_id, table, submitted)
            continue
        current = dict(existing)
        current.pop("id", None)
        if current != submitted:
            _update_child_row(conn, db, existing["id"], table, submitted)
        else:
            conn.execute(f"UPDATE {table} SET success = 0 WHERE id = ?;", (existing["id"],))


def _normalize_key_chain(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "chain_name": _text(row.get("chain_name")),
        "key_id": _int_or_none_value(row.get("key_id")),
        "key_string": _text(row.get("key_string")),
        "accept_lifetime": _text(row.get("accept_lifetime")),
        "send_lifetime": _text(row.get("send_lifetime")),
    }


def _key_chain_identity(row: dict[str, Any]) -> tuple[str, int | None]:
    return (_text(row.get("chain_name")), _int_or_none_value(row.get("key_id")))


def _collect_payload_key_chains(db: Any, payload: Any) -> list[dict[str, Any]]:
    deduped: dict[tuple[str, int | None], dict[str, Any]] = {}
    for process_value in db._as_list(payload):
        process = db._as_dict(process_value)
        for key_value in db._as_list(process.get("key_chains")):
            key_chain = _normalize_key_chain(db._as_dict(key_value))
            key = _key_chain_identity(key_chain)
            if key[0]:
                deduped[key] = key_chain
    return list(deduped.values())


def _sync_eigrp_key_chains(conn: sqlite3.Connection, db: Any, host: str, payload: Any) -> None:
    submitted_rows = _collect_payload_key_chains(db, payload)
    existing_rows = [
        dict(row)
        for row in conn.execute(
            """
            SELECT id, chain_name, key_id, key_string, accept_lifetime, send_lifetime
            FROM eigrp_key_chains
            WHERE host = ? AND success != -1
            ORDER BY id ASC;
            """,
            (host,),
        ).fetchall()
    ]
    existing_by_key = {_key_chain_identity(row): row for row in existing_rows}
    submitted_by_key = {_key_chain_identity(row): row for row in submitted_rows}

    for key, existing in existing_by_key.items():
        if key not in submitted_by_key:
            conn.execute("UPDATE eigrp_key_chains SET success = -1 WHERE id = ?;", (existing["id"],))

    for key, submitted in submitted_by_key.items():
        existing = existing_by_key.get(key)
        if existing is None:
            conn.execute(
                """
                INSERT INTO eigrp_key_chains (
                    host, chain_name, key_id, key_string, accept_lifetime, send_lifetime, success
                )
                VALUES (?, ?, ?, ?, ?, ?, 0);
                """,
                (
                    host,
                    submitted["chain_name"],
                    submitted["key_id"],
                    submitted["key_string"] or None,
                    submitted["accept_lifetime"] or None,
                    submitted["send_lifetime"] or None,
                ),
            )
            continue

        current = _normalize_key_chain(existing)
        if current != submitted:
            conn.execute(
                """
                UPDATE eigrp_key_chains
                SET key_string = ?, accept_lifetime = ?, send_lifetime = ?, success = 0
                WHERE id = ?;
                """,
                (
                    submitted["key_string"] or None,
                    submitted["accept_lifetime"] or None,
                    submitted["send_lifetime"] or None,
                    existing["id"],
                ),
            )
        else:
            conn.execute("UPDATE eigrp_key_chains SET success = 0 WHERE id = ?;", (existing["id"],))


def save_eigrp_routing(db: Any, host: str, payload: Any) -> bool:
    host = (host or "").strip()
    if not host:
        return False

    try:
        with db._connect() as conn:
            existing_ids = {
                row["eigrp_id"]
                for row in conn.execute(
                    """
                    SELECT eigrp_id
                    FROM eigrp_processes
                    WHERE host = ? AND success != -1;
                    """,
                    (host,),
                ).fetchall()
            }
            submitted_ids: set[int] = set()

            for process_value in db._as_list(payload):
                process = db._as_dict(process_value)
                eigrp_id = db._int_or_none(process.get("eigrp_id")) or 0
                as_number = db._int_or_none(process.get("as_number"))
                if as_number is None:
                    raise ValueError("EIGRP as_number is required")

                if eigrp_id > 0 and eigrp_id in existing_ids:
                    submitted_ids.add(eigrp_id)
                    current = _load_process_for_compare(conn, db, eigrp_id)
                    if current is None:
                        _insert_eigrp_process(conn, db, host, process)
                        continue

                    current_as_number = db._int_or_none(current.get("as_number"))
                    if current_as_number != as_number:
                        _archive_eigrp_process(conn, eigrp_id)
                        _insert_eigrp_process(conn, db, host, process)
                        continue

                    if _normalize_process(db, current) != _normalize_process(db, process):
                        _update_eigrp_process_row(conn, db, eigrp_id, process)
                        _sync_eigrp_child_table(conn, db, eigrp_id, process, "eigrp_networks", replace_all=False)
                        _sync_eigrp_child_table(conn, db, eigrp_id, process, "eigrp_interface_settings", replace_all=False)
                        _sync_eigrp_child_table(conn, db, eigrp_id, process, "eigrp_passive_interfaces", replace_all=False)
                        _sync_eigrp_child_table(conn, db, eigrp_id, process, "eigrp_distribute_lists", replace_all=False)
                        _sync_eigrp_child_table(conn, db, eigrp_id, process, "eigrp_offset_lists", replace_all=False)
                        _sync_eigrp_child_table(conn, db, eigrp_id, process, "eigrp_redistribute", replace_all=False)
                    else:
                        conn.execute("UPDATE eigrp_processes SET success = 0 WHERE eigrp_id = ?;", (eigrp_id,))
                    continue

                _insert_eigrp_process(conn, db, host, process)

            for deleted_id in existing_ids - submitted_ids:
                _archive_eigrp_process(conn, deleted_id)

            _sync_eigrp_key_chains(conn, db, host, payload)
            conn.commit()
        return True
    except (sqlite3.Error, ValueError) as exc:
        print(f"[db] saveEigrpRouting failed: {exc}", file=sys.stderr)
        return False
