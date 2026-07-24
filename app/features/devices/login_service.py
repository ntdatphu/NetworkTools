"""Device login normalization and credential lookup use cases."""

from __future__ import annotations

from typing import Any

from .repository import DeviceRepository


def normalize_device_type(os_name: str | None) -> str:
    """Normalize inventory OS aliases to connector identifiers."""
    if not os_name:
        return "cisco_ios"
    normalized = os_name.strip().lower().replace("-", "_").replace(" ", "_")
    aliases = {
        "ios": "cisco_ios", "cisco_ios": "cisco_ios", "ios_xe": "cisco_xe",
        "cisco_xe": "cisco_xe", "nxos": "cisco_nxos", "cisco_nxos": "cisco_nxos",
        "asa": "cisco_asa", "cisco_asa": "cisco_asa", "mikrotik": "mikrotik_routeros",
        "mikrotik_routeros": "mikrotik_routeros",
    }
    return aliases.get(normalized, normalized)


class DeviceLoginService:
    """Build normalized connection payloads for network infrastructure."""

    def __init__(self, repository: DeviceRepository) -> None:
        """Use the injected repository as credential authority."""
        self.repository = repository

    def load(self, host: str) -> dict[str, Any] | None:
        """Return a connector-ready payload or None for an unknown host."""
        row = self.repository.get_login(host)
        if row is None:
            return None
        method = str(row.get("method") or "ssh").strip().lower()
        return {
            "host": row["host"], "method": method,
            "port": row.get("portnumber") or (23 if method == "telnet" else 22),
            "username": row.get("username") or "", "password": row.get("password") or "",
            "device_type": normalize_device_type(row.get("os")),
            "role": str(row.get("role") or "").strip().lower(),
            "dev": int(row.get("dev") or 0),
        }

    @staticmethod
    def is_dev_device(device: dict[str, Any] | None) -> bool:
        """Return whether a normalized device must avoid real network access."""
        try:
            return bool(device) and int(device.get("dev") or 0) == 1
        except (TypeError, ValueError):
            return False
