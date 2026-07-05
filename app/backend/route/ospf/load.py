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
