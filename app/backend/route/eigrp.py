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


def save_eigrp_routing(db: Any, host: str, payload: Any) -> bool:
    host = (host or "").strip()
    if not host:
        return False

    try:
        with db._connect() as conn:
            conn.execute("DELETE FROM eigrp_processes WHERE host = ?;", (host,))
            conn.execute("DELETE FROM eigrp_key_chains WHERE host = ?;", (host,))

            saved_key_chain_names: set[tuple[str, int | None]] = set()
            for process_value in db._as_list(payload):
                process = db._as_dict(process_value)
                as_number = db._int_or_none(process.get("as_number"))
                if as_number is None:
                    raise ValueError("EIGRP as_number is required")

                action_cfg = str(process.get("action_Cfg") or "1111111").strip()
                if len(action_cfg) != 7:
                    action_cfg = "1111111"

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
                        action_cfg,
                    ),
                )
                eigrp_id = cur.lastrowid

                for network_value in db._as_list(process.get("networks")):
                    network = db._as_dict(network_value)
                    network_text = db._str_or_none(network.get("network"))
                    if not network_text:
                        continue
                    conn.execute(
                        """
                        INSERT INTO eigrp_networks (eigrp_id, network, wildcard, interface_name, success)
                        VALUES (?, ?, ?, ?, 0);
                        """,
                        (
                            eigrp_id,
                            network_text,
                            db._str_or_none(network.get("wildcard")),
                            db._str_or_none(network.get("interface_name")),
                        ),
                    )

                for iface_value in db._as_list(process.get("interface_settings")):
                    iface = db._as_dict(iface_value)
                    iface_name = db._str_or_none(iface.get("interface_name"))
                    if not iface_name:
                        continue
                    conn.execute(
                        """
                        INSERT INTO eigrp_interface_settings (
                            eigrp_id, interface_name, bandwidth, delay, hello_interval, hold_time,
                            auth_key_chain, summary_ip, summary_mask, split_horizon,
                            bandwidth_percent, next_hop_self, bfd, bfd_tx, bfd_rx,
                            bfd_multiplier, success
                        )
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0);
                        """,
                        (
                            eigrp_id,
                            iface_name,
                            db._int_or_none(iface.get("bandwidth")),
                            db._int_or_none(iface.get("delay")),
                            db._int_or_none(iface.get("hello_interval")),
                            db._int_or_none(iface.get("hold_time")),
                            db._str_or_none(iface.get("auth_key_chain")),
                            db._str_or_none(iface.get("summary_ip")),
                            db._str_or_none(iface.get("summary_mask")),
                            db._bool_int(iface.get("split_horizon")),
                            db._int_or_none(iface.get("bandwidth_percent")),
                            db._bool_int(iface.get("next_hop_self")),
                            db._bool_int(iface.get("bfd")),
                            db._int_or_none(iface.get("bfd_tx")),
                            db._int_or_none(iface.get("bfd_rx")),
                            db._int_or_none(iface.get("bfd_multiplier")),
                        ),
                    )

                for passive_value in db._as_list(process.get("passive_interfaces")):
                    passive = db._as_dict(passive_value)
                    iface_name = db._str_or_none(passive.get("interface_name"))
                    if not iface_name:
                        continue
                    conn.execute(
                        """
                        INSERT INTO eigrp_passive_interfaces (eigrp_id, interface_name, mode, success)
                        VALUES (?, ?, ?, 0);
                        """,
                        (eigrp_id, iface_name, db._str_or_none(passive.get("mode")) or "passive"),
                    )

                for distribute_value in db._as_list(process.get("distribute_lists")):
                    distribute = db._as_dict(distribute_value)
                    list_name = db._str_or_none(distribute.get("list_name"))
                    if not list_name:
                        continue
                    conn.execute(
                        """
                        INSERT INTO eigrp_distribute_lists (
                            eigrp_id, list_name, direction, interface_name, success
                        )
                        VALUES (?, ?, ?, ?, 0);
                        """,
                        (
                            eigrp_id,
                            list_name,
                            db._str_or_none(distribute.get("direction")) or "in",
                            db._str_or_none(distribute.get("interface_name")),
                        ),
                    )

                for offset_value in db._as_list(process.get("offset_lists")):
                    offset = db._as_dict(offset_value)
                    list_name = db._str_or_none(offset.get("list_name"))
                    value = db._int_or_none(offset.get("value"))
                    if not list_name or value is None:
                        continue
                    conn.execute(
                        """
                        INSERT INTO eigrp_offset_lists (
                            eigrp_id, list_name, direction, value, interface_name, success
                        )
                        VALUES (?, ?, ?, ?, ?, 0);
                        """,
                        (
                            eigrp_id,
                            list_name,
                            db._str_or_none(offset.get("direction")) or "in",
                            value,
                            db._str_or_none(offset.get("interface_name")),
                        ),
                    )

                for redist_value in db._as_list(process.get("redistribute")):
                    redist = db._as_dict(redist_value)
                    protocol = db._str_or_none(redist.get("protocol"))
                    if not protocol:
                        continue
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
                            protocol,
                            db._str_or_none(redist.get("route_map")),
                            db._int_or_none(redist.get("metric_bw")),
                            db._int_or_none(redist.get("metric_delay")),
                            db._int_or_none(redist.get("metric_reliability")),
                            db._int_or_none(redist.get("metric_load")),
                            db._int_or_none(redist.get("metric_mtu")),
                        ),
                    )

                for key_value in db._as_list(process.get("key_chains")):
                    key_chain = db._as_dict(key_value)
                    chain_name = db._str_or_none(key_chain.get("chain_name"))
                    key_id = db._int_or_none(key_chain.get("key_id"))
                    if not chain_name:
                        continue
                    dedupe_key = (chain_name, key_id)
                    if dedupe_key in saved_key_chain_names:
                        continue
                    saved_key_chain_names.add(dedupe_key)
                    conn.execute(
                        """
                        INSERT INTO eigrp_key_chains (
                            host, chain_name, key_id, key_string,
                            accept_lifetime, send_lifetime, success
                        )
                        VALUES (?, ?, ?, ?, ?, ?, 0);
                        """,
                        (
                            host,
                            chain_name,
                            key_id,
                            db._str_or_none(key_chain.get("key_string")),
                            db._str_or_none(key_chain.get("accept_lifetime")),
                            db._str_or_none(key_chain.get("send_lifetime")),
                        ),
                    )

            conn.commit()
        return True
    except (sqlite3.Error, ValueError) as exc:
        print(f"[db] saveEigrpRouting failed: {exc}", file=sys.stderr)
        return False
