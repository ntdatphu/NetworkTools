import re
from typing import Any, Dict, List


def parse_routing_payload(raw_text: str, host: str) -> Dict[str, Any]:
    text = raw_text or ""
    routes: List[Dict[str, Any]] = []

    static_routes = []
    defaults = []

    # ip route 10.10.10.0 255.255.255.0 192.168.1.1 [1]
    static_pattern = re.compile(
        r"^\s*ip\s+route\s+(\d+\.\d+\.\d+\.\d+)\s+(\d+\.\d+\.\d+\.\d+)\s+(\d+\.\d+\.\d+\.\d+)(?:\s+(\d+))?\s*$",
        re.IGNORECASE | re.MULTILINE,
    )

    # ip route 0.0.0.0 0.0.0.0 192.168.1.254
    default_pattern = re.compile(
        r"^\s*ip\s+route\s+0\.0\.0\.0\s+0\.0\.0\.0\s+(\d+\.\d+\.\d+\.\d+)\s*$",
        re.IGNORECASE | re.MULTILINE,
    )

    for m in static_pattern.finditer(text):
        network, mask, next_hop, ad = m.groups()
        if network == "0.0.0.0" and mask == "0.0.0.0":
            continue
        static_routes.append(
            {
                "network": network,
                "subnet_mask": mask,
                "next_hop": next_hop,
                "ad": int(ad) if ad else 1,
            }
        )

    for m in default_pattern.finditer(text):
        defaults.append({"next_hop_ip": m.group(1)})

    if static_routes or defaults:
        routes.append(
            {
                "route_type": "static",
                "description": "parsed from running-config",
                "static": static_routes,
                "defaults": defaults,
            }
        )

    # router ospf 1 ... network 10.0.0.0 0.0.0.255 area 0
    ospf_block_pattern = re.compile(
        r"router\s+ospf\s+(\d+)(.*?)(?=^\S|\Z)",
        re.IGNORECASE | re.MULTILINE | re.DOTALL,
    )
    ospf_net_pattern = re.compile(
        r"network\s+(\d+\.\d+\.\d+\.\d+)\s+(\d+\.\d+\.\d+\.\d+)\s+area\s+(\S+)",
        re.IGNORECASE,
    )

    for ospf_match in ospf_block_pattern.finditer(text):
        process_id = int(ospf_match.group(1))
        block = ospf_match.group(2)
        nets = []
        for net_match in ospf_net_pattern.finditer(block):
            nets.append(
                {
                    "network": net_match.group(1),
                    "wildcard": net_match.group(2),
                    "area": net_match.group(3),
                }
            )
        routes.append(
            {
                "route_type": "ospf",
                "description": f"process {process_id}",
                "ospf": {
                    "process_id": process_id,
                    "router_id": None,
                    "ad": None,
                    "default_info": 0,
                    "auto_summary": 0,
                    "networks": nets,
                },
            }
        )

    # router eigrp 100 ... network 10.0.0.0 0.0.0.255
    eigrp_block_pattern = re.compile(
        r"router\s+eigrp\s+(\d+)(.*?)(?=^\S|\Z)",
        re.IGNORECASE | re.MULTILINE | re.DOTALL,
    )
    eigrp_net_pattern = re.compile(
        r"network\s+(\d+\.\d+\.\d+\.\d+)(?:\s+(\d+\.\d+\.\d+\.\d+))?",
        re.IGNORECASE,
    )

    for eigrp_match in eigrp_block_pattern.finditer(text):
        as_number = int(eigrp_match.group(1))
        block = eigrp_match.group(2)
        nets = []
        for net_match in eigrp_net_pattern.finditer(block):
            nets.append(
                {
                    "network": net_match.group(1),
                    "wildcard": net_match.group(2),
                    "interface_name": None,
                }
            )
        routes.append(
            {
                "route_type": "eigrp",
                "description": f"as {as_number}",
                "eigrp": {
                    "as_number": as_number,
                    "router_id": None,
                    "auto_summary": 0,
                    "passive_default": 0,
                    "networks": nets,
                },
            }
        )

    return {"host": host, "routes": routes}
