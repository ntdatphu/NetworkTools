"""Collect, back up, and synchronize one host through the shared session."""

from __future__ import annotations

from typing import Any, Callable


class RunningConfigService:
    def __init__(
        self,
        login_service: Any,
        session_registry: Any,
        snapshot_committer: Callable[
            [str, dict[str, Any], str], tuple[dict[str, Any], dict[str, Any]]
        ],
    ) -> None:
        self._login_service = login_service
        self._sessions = session_registry
        self._commit_snapshot = snapshot_committer

    def collect(self, host: str, sync_mode: str = "automatic") -> dict[str, Any]:
        host = (host or "").strip()
        if not host:
            return {"ok": False, "severity": "warning", "message": "Get running-config failed: host is empty."}
        device = self._login_service.load(host)
        if device is None:
            return {"ok": False, "severity": "error", "message": f"Get running-config failed for {host}: device was not found."}
        if self._login_service.is_dev_device(device):
            return {"ok": False, "severity": "warning", "message": f"{host} is a dev-test host; no running-config can be collected."}
        if str(device.get("method") or "") not in {"ssh", "telnet"}:
            return {"ok": False, "severity": "warning", "message": f"Get running-config failed for {host}: unsupported protocol."}

        executed = self._sessions.execute(
            host, lambda connector: connector.collect_running_config()
        )
        if not executed.get("ok"):
            return executed
        snapshot = executed.get("value") or {}
        if not snapshot.get("ok"):
            return {
                "ok": False, "severity": "error",
                "message": f"Get running-config failed for {host}: {snapshot.get('message') or 'no output'}.",
            }
        backup, sync = self._commit_snapshot(host, snapshot, sync_mode)
        if not backup.get("ok"):
            return backup
        if sync_mode == "preview":
            return {
                **backup, "ok": True, "severity": "info",
                "message": "Manual Sys preview ready.", "sync": sync,
            }
        if not sync.get("ok", True):
            return {
                **backup, "ok": True, "severity": "warning",
                "message": f"Running-config committed in backup/{host}/cfg, but DB sync failed: {sync.get('message')}.",
                "sync": sync,
            }
        return {
            **backup, "ok": True, "severity": "success",
            "message": f"Running-config committed in backup/{host}/cfg.",
            "sync": sync,
        }
