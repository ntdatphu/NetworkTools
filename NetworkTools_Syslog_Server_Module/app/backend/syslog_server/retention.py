from __future__ import annotations

from .repository import SyslogRepository


def run_retention(repository: SyslogRepository, retention_days: int) -> dict[str, object]:
    try:
        deleted = repository.delete_expired(retention_days)
        return {"ok": True, "deleted": deleted, "message": f"Removed {deleted} expired syslog messages."}
    except Exception as exc:
        return {"ok": False, "deleted": 0, "message": f"Syslog retention failed: {exc}"}

