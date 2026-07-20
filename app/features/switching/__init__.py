"""Switch SW2/SW3 persistence and role-aware navigation.

These modules only manage local SQLite state. They intentionally do not expose
device-push actions until the corresponding network workers are implemented
and validated.
"""

from .interface_repository import get_switch_interfaces, save_switch_interface
from .l3_repository import get_ip_routing, get_svis, save_ip_routing, save_svi
from .monitoring_repository import get_mac_table, get_port_counters
from .navigation import navigation_for_role
from .schema import ensure_switch_schema
from .vlan_repository import get_vlans, save_vlan

__all__ = [
    "ensure_switch_schema",
    "get_ip_routing",
    "get_mac_table",
    "get_port_counters",
    "get_svis",
    "get_switch_interfaces",
    "get_vlans",
    "navigation_for_role",
    "save_ip_routing",
    "save_svi",
    "save_switch_interface",
    "save_vlan",
]
