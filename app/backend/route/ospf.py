from __future__ import annotations

import sqlite3
import sys
from typing import Any


def get_ospf_routing(db: Any, host: str) -> dict[str, Any]:
    host = (host or "").strip()
    if not host:
        return {"ok": False, "message": "Host is empty", "processes": []}

    try:
        with db._connect() as conn:
            process_rows = conn.execute(
                """
                SELECT ospf_id, process_id, router_id, reference_bandwidth,
                       passive_default, default_originate, default_originate_always, success
                FROM ospf_processes
                WHERE host = ? AND success != -1
                ORDER BY ospf_id ASC;
                """,
                (host,),
            ).fetchall()

            processes: list[dict[str, Any]] = []
            for process_row in process_rows:
                ospf_id = process_row["ospf_id"]
                process = dict(process_row)
                process["networks"] = db._dict_rows(
                    conn.execute(
                        """
                        SELECT id, network, wildcard, area, success
                        FROM ospf_networks
                        WHERE ospf_id = ? AND success != -1
                        ORDER BY id ASC;
                        """,
                        (ospf_id,),
                    ).fetchall()
                )

                distance = conn.execute(
                    """
                    SELECT external, intra_area, inter_area, success
                    FROM ospf_distance
                    WHERE ospf_id = ? AND success != -1
                    LIMIT 1;
                    """,
                    (ospf_id,),
                ).fetchone()
                process["distance"] = dict(distance) if distance else {}

                area_rows = conn.execute(
                    """
                    SELECT id, area_id, area_type, no_summary, authentication, success
                    FROM ospf_areas
                    WHERE ospf_id = ? AND success != -1
                    ORDER BY id ASC;
                    """,
                    (ospf_id,),
                ).fetchall()
                areas: list[dict[str, Any]] = []
                for area_row in area_rows:
                    area = dict(area_row)
                    area["ranges"] = db._dict_rows(
                        conn.execute(
                            """
                            SELECT id, ip, mask, advertise, cost, success
                            FROM ospf_area_ranges
                            WHERE area_db_id = ? AND success != -1
                            ORDER BY id ASC;
                            """,
                            (area_row["id"],),
                        ).fetchall()
                    )
                    areas.append(area)
                process["areas"] = areas

                process["redistribute"] = db._dict_rows(
                    conn.execute(
                        """
                        SELECT id, protocol, process_id, subnets, metric, metric_type, route_map, success
                        FROM ospf_redistribute
                        WHERE ospf_id = ? AND success != -1
                        ORDER BY id ASC;
                        """,
                        (ospf_id,),
                    ).fetchall()
                )
                process["passive_interfaces"] = db._dict_rows(
                    conn.execute(
                        """
                        SELECT id, interface_name, passive, success
                        FROM ospf_passive_interfaces
                        WHERE ospf_id = ? AND success != -1
                        ORDER BY id ASC;
                        """,
                        (ospf_id,),
                    ).fetchall()
                )
                tuning = conn.execute(
                    """
                    SELECT maximum_paths, max_lsa, spf_delay, spf_min_delay, spf_max_delay,
                           lsa_delay, lsa_min_delay, lsa_max_delay, success
                    FROM ospf_tuning
                    WHERE ospf_id = ? AND success != -1
                    LIMIT 1;
                    """,
                    (ospf_id,),
                ).fetchone()
                process["tuning"] = dict(tuning) if tuning else {}
                process["interface_settings"] = db._dict_rows(
                    conn.execute(
                        """
                        SELECT id, interface_name, area, cost, hello_interval, dead_interval,
                               mtu_ignore, bfd, network_type, auth_type, success
                        FROM ospf_interface_settings
                        WHERE ospf_id = ? AND success != -1
                        ORDER BY id ASC;
                        """,
                        (ospf_id,),
                    ).fetchall()
                )
                processes.append(process)

        return {"ok": True, "message": "Loaded OSPF routing", "processes": processes}
    except sqlite3.Error as exc:
        print(f"[db] getOspfRouting failed: {exc}", file=sys.stderr)
        return {"ok": False, "message": str(exc), "processes": []}


def save_ospf_routing(db: Any, host: str, payload: Any) -> bool:
    host = (host or "").strip()
    if not host:
        return False

    try:
        with db._connect() as conn:
            conn.execute("DELETE FROM ospf_processes WHERE host = ?;", (host,))

            for process_value in db._as_list(payload):
                process = db._as_dict(process_value)
                process_id = db._int_or_none(process.get("process_id"))
                if process_id is None:
                    raise ValueError("OSPF process_id is required")

                cur = conn.execute(
                    """
                    INSERT INTO ospf_processes (
                        host, process_id, router_id, reference_bandwidth,
                        passive_default, default_originate, default_originate_always, success
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?, 0);
                    """,
                    (
                        host,
                        process_id,
                        db._str_or_none(process.get("router_id")),
                        db._int_or_none(process.get("reference_bandwidth")),
                        db._bool_int(process.get("passive_default")),
                        db._bool_int(process.get("default_originate")),
                        db._bool_int(process.get("default_originate_always")),
                    ),
                )
                ospf_id = cur.lastrowid

                for network_value in db._as_list(process.get("networks")):
                    network = db._as_dict(network_value)
                    conn.execute(
                        """
                        INSERT INTO ospf_networks (ospf_id, network, wildcard, area, success)
                        VALUES (?, ?, ?, ?, 0);
                        """,
                        (
                            ospf_id,
                            db._str_or_none(network.get("network")),
                            db._str_or_none(network.get("wildcard")),
                            db._int_or_zero(network.get("area")),
                        ),
                    )

                distance = db._as_dict(process.get("distance"))
                if distance:
                    conn.execute(
                        """
                        INSERT INTO ospf_distance (ospf_id, external, intra_area, inter_area, success)
                        VALUES (?, ?, ?, ?, 0);
                        """,
                        (
                            ospf_id,
                            db._int_or_none(distance.get("external")),
                            db._int_or_none(distance.get("intra_area")),
                            db._int_or_none(distance.get("inter_area")),
                        ),
                    )

                for area_value in db._as_list(process.get("areas")):
                    area = db._as_dict(area_value)
                    cur = conn.execute(
                        """
                        INSERT INTO ospf_areas (
                            ospf_id, area_id, area_type, no_summary, authentication, success
                        )
                        VALUES (?, ?, ?, ?, ?, 0);
                        """,
                        (
                            ospf_id,
                            db._int_or_zero(area.get("area_id")),
                            db._str_or_none(area.get("area_type")) or "normal",
                            db._bool_int(area.get("no_summary")),
                            db._str_or_none(area.get("authentication")),
                        ),
                    )
                    area_db_id = cur.lastrowid
                    for range_value in db._as_list(area.get("ranges")):
                        range_row = db._as_dict(range_value)
                        conn.execute(
                            """
                            INSERT INTO ospf_area_ranges (area_db_id, ip, mask, advertise, cost, success)
                            VALUES (?, ?, ?, ?, ?, 0);
                            """,
                            (
                                area_db_id,
                                db._str_or_none(range_row.get("ip")),
                                db._str_or_none(range_row.get("mask")),
                                db._bool_int(range_row.get("advertise", True)),
                                db._int_or_none(range_row.get("cost")),
                            ),
                        )

                for redist_value in db._as_list(process.get("redistribute")):
                    redist = db._as_dict(redist_value)
                    protocol = db._str_or_none(redist.get("protocol"))
                    if not protocol:
                        continue
                    conn.execute(
                        """
                        INSERT INTO ospf_redistribute (
                            ospf_id, protocol, process_id, subnets, metric, metric_type, route_map, success
                        )
                        VALUES (?, ?, ?, ?, ?, ?, ?, 0);
                        """,
                        (
                            ospf_id,
                            protocol,
                            db._int_or_none(redist.get("process_id")),
                            db._bool_int(redist.get("subnets", True)),
                            db._int_or_none(redist.get("metric")),
                            db._int_or_none(redist.get("metric_type")),
                            db._str_or_none(redist.get("route_map")),
                        ),
                    )

                for passive_value in db._as_list(process.get("passive_interfaces")):
                    passive = db._as_dict(passive_value)
                    iface = db._str_or_none(passive.get("interface_name"))
                    if not iface:
                        continue
                    conn.execute(
                        """
                        INSERT INTO ospf_passive_interfaces (ospf_id, interface_name, passive, success)
                        VALUES (?, ?, ?, 0);
                        """,
                        (ospf_id, iface, db._bool_int(passive.get("passive", True))),
                    )

                tuning = db._as_dict(process.get("tuning"))
                if tuning:
                    conn.execute(
                        """
                        INSERT INTO ospf_tuning (
                            ospf_id, maximum_paths, max_lsa, spf_delay, spf_min_delay, spf_max_delay,
                            lsa_delay, lsa_min_delay, lsa_max_delay, success
                        )
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0);
                        """,
                        (
                            ospf_id,
                            db._int_or_none(tuning.get("maximum_paths")),
                            db._int_or_none(tuning.get("max_lsa")),
                            db._int_or_none(tuning.get("spf_delay")),
                            db._int_or_none(tuning.get("spf_min_delay")),
                            db._int_or_none(tuning.get("spf_max_delay")),
                            db._int_or_none(tuning.get("lsa_delay")),
                            db._int_or_none(tuning.get("lsa_min_delay")),
                            db._int_or_none(tuning.get("lsa_max_delay")),
                        ),
                    )

                for iface_value in db._as_list(process.get("interface_settings")):
                    iface = db._as_dict(iface_value)
                    iface_name = db._str_or_none(iface.get("interface_name"))
                    if not iface_name:
                        continue
                    conn.execute(
                        """
                        INSERT INTO ospf_interface_settings (
                            ospf_id, interface_name, area, cost, hello_interval, dead_interval,
                            mtu_ignore, bfd, network_type, auth_type, success
                        )
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0);
                        """,
                        (
                            ospf_id,
                            iface_name,
                            db._int_or_zero(iface.get("area")),
                            db._int_or_none(iface.get("cost")),
                            db._int_or_none(iface.get("hello_interval")),
                            db._int_or_none(iface.get("dead_interval")),
                            db._bool_int(iface.get("mtu_ignore")),
                            db._bool_int(iface.get("bfd")),
                            db._str_or_none(iface.get("network_type")),
                            db._str_or_none(iface.get("auth_type")),
                        ),
                    )

            conn.commit()
        return True
    except (sqlite3.Error, ValueError) as exc:
        print(f"[db] saveOspfRouting failed: {exc}", file=sys.stderr)
        return False
