from __future__ import annotations

import sqlite3
from typing import Any
from ..interface_refs import require_iface_id


def insert_child_row(conn: sqlite3.Connection, db: Any, eigrp_id: int, table: str, row: dict[str, Any]) -> None:
    if table == "t04_eigrp_networks":
        conn.execute(
            """
            INSERT INTO t04_eigrp_networks (eigrp_id, network, wildcard, interface_name, success)
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

    if table == "t04_router_iface_eigrp":
        host_row = conn.execute("SELECT host FROM t04_eigrp_processes WHERE eigrp_id = ?;", (eigrp_id,)).fetchone()
        if host_row is None:
            raise ValueError(f"EIGRP process {eigrp_id} does not exist")
        iface_id = require_iface_id(conn, host_row["host"], db._str_or_none(row.get("interface_name")) or "")
        conn.execute(
            """
            INSERT INTO t04_router_iface_eigrp (
                eigrp_id, iface_id, bandwidth, delay, hello_interval, hold_time,
                auth_key_chain, summary_ip, summary_mask, split_horizon,
                bandwidth_percent, next_hop_self, bfd, bfd_tx, bfd_rx, bfd_multiplier, success
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0);
            """,
            (
                eigrp_id,
                iface_id,
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

    if table == "t04_eigrp_passive_interfaces":
        conn.execute(
            """
            INSERT INTO t04_eigrp_passive_interfaces (eigrp_id, interface_name, mode, success)
            VALUES (?, ?, ?, 0);
            """,
            (eigrp_id, db._str_or_none(row.get("interface_name")), db._str_or_none(row.get("mode")) or "passive"),
        )
        return

    if table == "t04_eigrp_distribute_lists":
        conn.execute(
            """
            INSERT INTO t04_eigrp_distribute_lists (eigrp_id, list_name, direction, interface_name, success)
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

    if table == "t04_eigrp_offset_lists":
        conn.execute(
            """
            INSERT INTO t04_eigrp_offset_lists (eigrp_id, list_name, direction, value, interface_name, success)
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

    if table == "t04_eigrp_redistribute":
        conn.execute(
            """
            INSERT INTO t04_eigrp_redistribute (
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
    if table == "t04_eigrp_networks":
        conn.execute(
            """
            UPDATE t04_eigrp_networks
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

    if table == "t04_router_iface_eigrp":
        conn.execute(
            """
            UPDATE t04_router_iface_eigrp
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

    if table == "t04_eigrp_passive_interfaces":
        conn.execute(
            "UPDATE t04_eigrp_passive_interfaces SET interface_name = ?, mode = ?, success = 0 WHERE id = ?;",
            (db._str_or_none(row.get("interface_name")), db._str_or_none(row.get("mode")) or "passive", row_id),
        )
        return

    if table == "t04_eigrp_distribute_lists":
        conn.execute(
            """
            UPDATE t04_eigrp_distribute_lists
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

    if table == "t04_eigrp_offset_lists":
        conn.execute(
            """
            UPDATE t04_eigrp_offset_lists
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

    if table == "t04_eigrp_redistribute":
        conn.execute(
            """
            UPDATE t04_eigrp_redistribute
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
