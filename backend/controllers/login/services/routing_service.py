from typing import Any, Dict

from db_client import DbClient


ALLOWED_ROUTE_TYPES = {"static", "default", "ospf", "eigrp"}


def save_routing_payload(db: DbClient, payload: Dict[str, Any]) -> None:
    host = payload.get("host")
    if not host:
        return

    db.clear_routing_for_host(host)

    for route_item in payload.get("routes", []):
        route_type = (route_item.get("route_type") or "").strip().lower()
        if route_type not in ALLOWED_ROUTE_TYPES:
            continue

        for row in route_item.get("static", []):
            db.insert_static_route(
                host=host,
                network=row.get("network"),
                subnet_mask=row.get("subnet_mask"),
                next_hop=row.get("next_hop"),
                ad=row.get("ad"),
            )

        for row in route_item.get("defaults", []):
            if row.get("next_hop_ip"):
                db.insert_default_route(host=host, next_hop_ip=row.get("next_hop_ip"))

        ospf = route_item.get("ospf") or {}
        if ospf:
            ospf_id = db.insert_ospf_process(
                host=host,
                process_id=int(ospf.get("process_id", 1)),
                router_id=ospf.get("router_id"),
                ad=ospf.get("ad"),
                default_info=int(ospf.get("default_info", 0)),
                auto_summary=int(ospf.get("auto_summary", 0)),
            )
            for n in ospf.get("networks", []):
                if n.get("network") and n.get("wildcard") and n.get("area") is not None:
                    db.insert_ospf_network(ospf_id, n.get("network"), n.get("wildcard"), str(n.get("area")))

        eigrp = route_item.get("eigrp") or {}
        if eigrp:
            eigrp_id = db.insert_eigrp_process(
                host=host,
                as_number=int(eigrp.get("as_number", 1)),
                router_id=eigrp.get("router_id"),
                auto_summary=int(eigrp.get("auto_summary", 0)),
                passive_default=int(eigrp.get("passive_default", 0)),
            )
            for n in eigrp.get("networks", []):
                if n.get("network"):
                    db.insert_eigrp_network(eigrp_id, n.get("network"), n.get("wildcard"), n.get("interface_name"))
