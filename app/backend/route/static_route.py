from __future__ import annotations

import sqlite3
import sys
from typing import Any

from .static_default import default_route_payload, fetch_default_route, replace_default_route


def get_static_routing(db: Any, host: str) -> dict[str, Any]:
    host = (host or "").strip()
    if not host:
        return {"ok": False, "message": "Host is empty", "default_route": "", "routes": []}

    try:
        with db._connect() as conn:
            default_row = fetch_default_route(conn, host)
            route_rows = conn.execute(
                """
                SELECT id, network, subnet_mask, next_hop, ad, success
                FROM t04_static_routes
                WHERE host = ? AND success != -1
                ORDER BY id ASC;
                """,
                (host,),
            ).fetchall()

        routes = [
            {
                "id": row["id"],
                "network": row["network"],
                "mask": row["subnet_mask"],
                "nexthop": row["next_hop"],
                "ad": row["ad"],
                "success": row["success"],
            }
            for row in route_rows
        ]
        return {
            "ok": True,
            "message": "Loaded static/default routes",
            **default_route_payload(default_row),
            "routes": routes,
        }
    except sqlite3.Error as exc:
        print(f"[db] getStaticRouting failed: {exc}", file=sys.stderr)
        return {"ok": False, "message": str(exc), "default_route": "", "routes": []}


def save_static_routing(db: Any, host: str, default_value: str, routes: Any) -> bool:
    host = (host or "").strip()
    if not host:
        return False

    try:
        with db._connect() as conn:
            replace_default_route(conn, host, default_value)

            existing_ids = {
                row["id"]
                for row in conn.execute(
                    """
                    SELECT id
                    FROM t04_static_routes
                    WHERE host = ? AND success != -1;
                    """,
                    (host,),
                ).fetchall()
            }
            submitted_ids: set[int] = set()

            for route_value in db._as_list(routes):
                route = db._as_dict(route_value)
                route_id = db._int_or_none(route.get("id")) or db._int_or_none(route.get("routeId")) or 0
                network = db._str_or_none(route.get("network"))
                mask = db._str_or_none(route.get("mask"))
                nexthop = db._str_or_none(route.get("nexthop"))
                if not (network or mask or nexthop):
                    continue
                if not (network and mask and nexthop):
                    raise ValueError("Static route must include network, mask, and next-hop")
                ad = db._int_or_none(route.get("ad")) or 1
                if ad < 1 or ad > 255:
                    ad = 1

                if route_id > 0 and route_id in existing_ids:
                    submitted_ids.add(route_id)
                    if bool(route.get("edited")):
                        conn.execute(
                            """
                            UPDATE t04_static_routes
                            SET success = -1
                            WHERE id = ? AND host = ? AND success != -1;
                            """,
                            (route_id, host),
                        )
                        conn.execute(
                            """
                            INSERT INTO t04_static_routes (host, network, subnet_mask, next_hop, ad, success)
                            VALUES (?, ?, ?, ?, ?, 0);
                            """,
                            (host, network, mask, nexthop, ad),
                        )
                    continue

                conn.execute(
                    """
                    INSERT INTO t04_static_routes (host, network, subnet_mask, next_hop, ad, success)
                    VALUES (?, ?, ?, ?, ?, 0);
                    """,
                    (host, network, mask, nexthop, ad),
                )

            deleted_ids = existing_ids - submitted_ids
            if deleted_ids:
                placeholders = ",".join("?" for _ in deleted_ids)
                conn.execute(
                    f"""
                    UPDATE t04_static_routes
                    SET success = -1
                    WHERE host = ? AND id IN ({placeholders});
                    """,
                    (host, *deleted_ids),
                )
            conn.commit()
        return True
    except (sqlite3.Error, ValueError) as exc:
        print(f"[db] saveStaticRouting failed: {exc}", file=sys.stderr)
        return False
