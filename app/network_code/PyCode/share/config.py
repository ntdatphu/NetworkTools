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
MAIN_SQL = str(Path(_paths.get("main_sql") or APP_DIR / "UI" / "main_numbered_tables.sql"))
TMP_DIR = str(APP_DIR / "tmp")
BACKUP_DIR = str(APP_DIR / "backup")
ROUTE_OUTPUT = str(Path(TMP_DIR) / "routing_output.json")
DHCP_OUTPUT = str(Path(TMP_DIR) / "dhcp_output.json")
ROUTING_TEMPLATE_DIR = str(NETWORK_CODE_DIR / "routing" / "templates")

DB_TABLES = {
    "device_info": {"main": "t01_devices"},
    "routing_static": {
        "default": "t04_static_default_routes",
        "routes": "t04_static_routes",
    },
    "routing_ospf": {
        "processes": "t04_ospf_processes",
        "networks": "t04_ospf_networks",
        "areas": "t04_ospf_areas",
        "area_ranges": "t04_ospf_area_ranges",
        "distance": "t04_ospf_distance",
        "tuning": "t04_ospf_tuning",
        "redistribute": "t04_ospf_redistribute",
        "passive_interfaces": "t04_ospf_passive_interfaces",
        "interface_settings": "t04_ospf_interface_settings",
    },
    "routing_eigrp": {
        "processes": "t04_eigrp_processes",
        "networks": "t04_eigrp_networks",
        "interface_settings": "t04_eigrp_interface_settings",
        "passive_interfaces": "t04_eigrp_passive_interfaces",
        "distribute_lists": "t04_eigrp_distribute_lists",
        "offset_lists": "t04_eigrp_offset_lists",
        "redistribute": "t04_eigrp_redistribute",
        "key_chains": "t04_eigrp_key_chains",
    },
    "dhcp": {
        "pools": "t03_dhcp_pool",
        "excluded": "t03_excluded_address",
        "helpers": "t03_router_iface_helper",
    },
}
