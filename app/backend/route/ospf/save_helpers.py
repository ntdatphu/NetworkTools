from __future__ import annotations

import sqlite3
from typing import Any

from .common import (
    as_dict,
    as_list,
    bool_int_value,
    int_or_zero_value,
    network_key,
    payload_networks,
    text,
)


def sync_ospf_networks(conn: sqlite3.Connection, db: Any, ospf_id: int, process: dict[str, Any]) -> None:
    existing_rows = conn.execute(
        """
        SELECT id, network, wildcard, area
        FROM ospf_networks
        WHERE ospf_id = ? AND success != -1;
        """,
        (ospf_id,),
    ).fetchall()
    existing = {network_key(dict(row)): row["id"] for row in existing_rows}
    submitted = payload_networks(db, process)

    for key, row_id in existing.items():
        if key not in submitted:
            conn.execute("UPDATE ospf_networks SET success = -1 WHERE id = ?;", (row_id,))

    for key in submitted:
        if key not in existing:
            conn.execute(
                """
                INSERT INTO ospf_networks (ospf_id, network, wildcard, area, success)
                VALUES (?, ?, ?, ?, 0);
                """,
                (ospf_id, key[0], key[1], key[2]),
            )


def load_process_for_compare(conn: sqlite3.Connection, db: Any, ospf_id: int) -> dict[str, Any] | None:
    process = conn.execute(
        """
        SELECT ospf_id, process_id, router_id, reference_bandwidth,
               passive_default, default_originate, default_originate_always
        FROM ospf_processes
        WHERE ospf_id = ? AND success != -1
        LIMIT 1;
        """,
        (ospf_id,),
    ).fetchone()
    if process is None:
        return None

    data = dict(process)
    data["networks"] = db._dict_rows(
        conn.execute(
            """
            SELECT network, wildcard, area
            FROM ospf_networks
            WHERE ospf_id = ? AND success != -1
            ORDER BY id ASC;
            """,
            (ospf_id,),
        ).fetchall()
    )
    distance = conn.execute(
        """
        SELECT external, intra_area, inter_area
        FROM ospf_distance
        WHERE ospf_id = ? AND success != -1
        LIMIT 1;
        """,
        (ospf_id,),
    ).fetchone()
    data["distance"] = dict(distance) if distance else {}

    area_rows = conn.execute(
        """
        SELECT id, area_id, area_type, no_summary, authentication
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
                SELECT ip, mask, advertise, cost
                FROM ospf_area_ranges
                WHERE area_db_id = ? AND success != -1
                ORDER BY id ASC;
                """,
                (area_row["id"],),
            ).fetchall()
        )
        areas.append(area)
    data["areas"] = areas

    data["redistribute"] = db._dict_rows(
        conn.execute(
            """
            SELECT protocol, process_id, subnets, metric, metric_type, route_map
            FROM ospf_redistribute
            WHERE ospf_id = ? AND success != -1
            ORDER BY id ASC;
            """,
            (ospf_id,),
        ).fetchall()
    )
    data["passive_interfaces"] = db._dict_rows(
        conn.execute(
            """
            SELECT interface_name, passive
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
               lsa_delay, lsa_min_delay, lsa_max_delay
        FROM ospf_tuning
        WHERE ospf_id = ? AND success != -1
        LIMIT 1;
        """,
        (ospf_id,),
    ).fetchone()
    data["tuning"] = dict(tuning) if tuning else {}
    data["interface_settings"] = db._dict_rows(
        conn.execute(
            """
            SELECT interface_name, area, cost, hello_interval, dead_interval,
                   mtu_ignore, bfd, network_type, auth_type
            FROM ospf_interface_settings
            WHERE ospf_id = ? AND success != -1
            ORDER BY id ASC;
            """,
            (ospf_id,),
        ).fetchall()
    )
    return data


def reset_ospf_process_children(conn: sqlite3.Connection, ospf_id: int) -> None:
    for table in (
        "ospf_networks",
        "ospf_distance",
        "ospf_areas",
        "ospf_redistribute",
        "ospf_passive_interfaces",
        "ospf_tuning",
        "ospf_interface_settings",
    ):
        conn.execute(f"UPDATE {table} SET success = -1 WHERE ospf_id = ?;", (ospf_id,))
    conn.execute(
        """
        UPDATE ospf_area_ranges
        SET success = -1
        WHERE area_db_id IN (
            SELECT id FROM ospf_areas WHERE ospf_id = ?
        );
        """,
        (ospf_id,),
    )


def archive_ospf_process(conn: sqlite3.Connection, ospf_id: int) -> None:
    conn.execute("UPDATE ospf_processes SET success = -1 WHERE ospf_id = ?;", (ospf_id,))
    reset_ospf_process_children(conn, ospf_id)


def is_blank_ospf_process_submission(db: Any, process: dict[str, Any]) -> bool:
    if db._int_or_none(process.get("process_id")) is not None:
        return False
    if text(process.get("router_id")):
        return False
    if int_or_zero_value(process.get("reference_bandwidth")) > 0:
        return False
    if bool_int_value(process.get("passive_default")):
        return False
    if bool_int_value(process.get("default_originate")):
        return False
    if bool_int_value(process.get("default_originate_always")):
        return False
    if any(text(as_dict(db, row).get("network")) or text(as_dict(db, row).get("wildcard")) for row in as_list(db, process.get("networks"))):
        return False
    if as_dict(db, process.get("distance")):
        return False
    if as_dict(db, process.get("tuning")):
        return False
    if as_list(db, process.get("areas")):
        return False
    if as_list(db, process.get("redistribute")):
        return False
    if as_list(db, process.get("passive_interfaces")):
        return False
    if as_list(db, process.get("interface_settings")):
        return False
    return True


def describe_process_submission(db: Any, process: dict[str, Any], index: int) -> str:
    return (
        f"submission #{index}: "
        f"ospf_id={process.get('ospf_id')!r}, "
        f"process_id={process.get('process_id')!r}, "
        f"router_id={text(process.get('router_id'))!r}, "
        f"reference_bandwidth={process.get('reference_bandwidth')!r}, "
        f"networks={len(as_list(db, process.get('networks')))}"
    )


def insert_ospf_process(conn: sqlite3.Connection, db: Any, host: str, process: dict[str, Any]) -> int:
    process_id = db._int_or_none(process.get("process_id"))
    if process_id is None:
        raise ValueError("OSPF process_id is required")

    existing = conn.execute(
        """
        SELECT ospf_id
        FROM ospf_processes
        WHERE host = ? AND process_id = ?
        ORDER BY ospf_id ASC
        LIMIT 1;
        """,
        (host, process_id),
    ).fetchone()

    if existing is not None:
        ospf_id = existing["ospf_id"]
        conn.execute(
            """
            UPDATE ospf_processes
            SET router_id = ?,
                reference_bandwidth = ?,
                passive_default = ?,
                default_originate = ?,
                default_originate_always = ?,
                success = 0
            WHERE ospf_id = ?;
            """,
            (
                db._str_or_none(process.get("router_id")),
                db._int_or_none(process.get("reference_bandwidth")),
                db._bool_int(process.get("passive_default")),
                db._bool_int(process.get("default_originate")),
                db._bool_int(process.get("default_originate_always")),
                ospf_id,
            ),
        )
        reset_ospf_process_children(conn, ospf_id)
    else:
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

    for network_value in as_list(db, process.get("networks")):
        network = as_dict(db, network_value)
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

    distance = as_dict(db, process.get("distance"))
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

    for area_value in as_list(db, process.get("areas")):
        area = as_dict(db, area_value)
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
        for range_value in as_list(db, area.get("ranges")):
            range_row = as_dict(db, range_value)
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

    for redist_value in as_list(db, process.get("redistribute")):
        redist = as_dict(db, redist_value)
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

    for passive_value in as_list(db, process.get("passive_interfaces")):
        passive = as_dict(db, passive_value)
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

    tuning = as_dict(db, process.get("tuning"))
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

    for iface_value in as_list(db, process.get("interface_settings")):
        iface = as_dict(db, iface_value)
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

    return ospf_id
