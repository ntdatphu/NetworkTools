from __future__ import annotations

import json
from pathlib import Path


NETWORK_CODE_DIR = Path(__file__).resolve().parents[2]
APP_DIR = NETWORK_CODE_DIR.parent

_paths_file = NETWORK_CODE_DIR / "database_paths.json"
_paths = {}
if _paths_file.exists():
    try:
        _paths = json.loads(_paths_file.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        _paths = {}

DB_PATH = str(Path(_paths.get("device_network_db") or APP_DIR / "device_network.db"))
MAIN_SQL = str(Path(_paths.get("main_sql") or APP_DIR / "NetworkTools" / "main.sql"))
TMP_DIR = str(APP_DIR / "tmp")
ROUTE_OUTPUT = str(Path(TMP_DIR) / "routing_output.json")
ROUTING_TEMPLATE_DIR = str(NETWORK_CODE_DIR / "routing" / "templates")

DB_TABLES = {
    "device_info": {"main": "devices"},
    "routing_static": {
        "default": "static_default_routes",
        "routes": "static_routes",
    },
    "routing_ospf": {
        "processes": "ospf_processes",
        "networks": "ospf_networks",
        "areas": "ospf_areas",
        "area_ranges": "ospf_area_ranges",
        "distance": "ospf_distance",
        "tuning": "ospf_tuning",
        "redistribute": "ospf_redistribute",
        "passive_interfaces": "ospf_passive_interfaces",
        "interface_settings": "ospf_interface_settings",
    },
    "routing_eigrp": {
        "processes": "eigrp_processes",
        "networks": "eigrp_networks",
        "interface_settings": "eigrp_interface_settings",
        "passive_interfaces": "eigrp_passive_interfaces",
        "distribute_lists": "eigrp_distribute_lists",
        "offset_lists": "eigrp_offset_lists",
        "redistribute": "eigrp_redistribute",
        "key_chains": "eigrp_key_chains",
    },
}
