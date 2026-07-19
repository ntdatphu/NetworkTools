"""Application session registry surface."""

from .runtime import device_session_registry
from infrastructure.network.session_registry import DeviceSessionRegistry

__all__ = ["DeviceSessionRegistry", "device_session_registry"]
