"""Router-interface persistence boundary."""

from .repository import (
    delete_router_interface,
    get_router_interface_by_name,
    get_router_interfaces,
    save_router_interface,
)
from .collector import collect_interface_tasks
from .commands import (
    redact_interface_commands,
    redact_interface_output,
    render_interface_commands,
)

__all__ = [
    "delete_router_interface",
    "get_router_interface_by_name",
    "get_router_interfaces",
    "save_router_interface",
    "collect_interface_tasks",
    "redact_interface_commands",
    "redact_interface_output",
    "render_interface_commands",
]
