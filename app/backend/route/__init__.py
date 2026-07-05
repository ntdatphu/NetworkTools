"""Routing persistence services used by the PyQt bridge."""

from .static_route import get_static_routing, save_static_routing
from .ospf import get_ospf_routing, save_ospf_routing
from .eigrp import get_eigrp_routing, save_eigrp_routing

__all__ = [
    "get_static_routing",
    "save_static_routing",
    "get_ospf_routing",
    "save_ospf_routing",
    "get_eigrp_routing",
    "save_eigrp_routing",
]
