"""Device state use cases shared by QML and terminal facades."""

from __future__ import annotations

from .repository import DeviceRepository


class DeviceService:
    """Coordinate device status transitions without exposing SQL to core."""

    def __init__(self, repository: DeviceRepository) -> None:
        """Store the injected device repository."""
        self.repository = repository

    def update_flag(self, host: str, column: str, value: int) -> bool:
        """Update one validated device status flag."""
        return self.repository.update_flag(host, column, value)

    def reset_to_waiting(self, host: str) -> dict[str, object]:
        """Reset session state and retain the legacy structured payload."""
        target = (host or "").strip()
        if not target:
            return {"ok": False, "message": "Host is empty.", "severity": "warning"}
        try:
            if not self.repository.reset_to_waiting(target):
                return {"ok": False, "message": f"Device {target} not found.", "severity": "error"}
            return {"ok": True, "message": f"Device {target} reset to Waiting.", "severity": "success"}
        except Exception as exc:
            return {"ok": False, "message": str(exc), "severity": "error"}
