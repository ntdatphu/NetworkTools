"""Decide when a committed running-config should update application state."""

from __future__ import annotations

from pathlib import Path
from typing import Any, Callable

from features.devices.sync_state import sync_device_state


RoleLookup = Callable[[str], str | None]
Synchronizer = Callable[[str, str, str, str | None], dict[str, Any]]


class ConfigSyncService:
    """Gate the router sync pipeline by inventory role and Dulwich change state."""

    ROUTER_ROLE = "rou"

    def __init__(
        self,
        db_path: str | Path,
        role_lookup: RoleLookup,
        synchronizer: Synchronizer = sync_device_state,
    ) -> None:
        self.db_path = str(db_path)
        self._role_lookup = role_lookup
        self._synchronizer = synchronizer

    def sync_committed_snapshot(
        self,
        host: str,
        running_config: str,
        interface_brief: str,
        commit_result: dict[str, Any],
    ) -> dict[str, Any]:
        """Sync a changed router snapshot; return a structured decision/result."""
        normalized_host = (host or "").strip()
        base = {
            "host": normalized_host,
            "role": "",
            "attempted": False,
            "skipped": True,
            "changed": bool(commit_result.get("changed")),
            "commitId": str(commit_result.get("commitId") or ""),
        }
        if not bool(commit_result.get("changed")):
            return {
                **base,
                "ok": True,
                "reason": "unchanged",
                "message": "Running-config is unchanged; database sync was not needed.",
                "summary": {},
            }
        try:
            role = str(self._role_lookup(normalized_host) or "").strip().lower()
        except Exception as exc:
            return {
                **base,
                "ok": False,
                "reason": "role-lookup-failed",
                "message": f"Could not verify device role: {exc}",
                "summary": {},
            }
        base["role"] = role
        if role != self.ROUTER_ROLE:
            return {
                **base,
                "ok": True,
                "reason": "not-router",
                "message": f"Config sync skipped because device role is {role or 'unknown'}, not rou.",
                "summary": {},
            }
        try:
            summary = self._synchronizer(
                self.db_path,
                normalized_host,
                str(running_config or ""),
                str(interface_brief or ""),
            )
            return {
                **base,
                "ok": True,
                "attempted": True,
                "skipped": False,
                "reason": "synchronized",
                "message": "Changed router configuration was synchronized.",
                "summary": dict(summary or {}),
            }
        except Exception as exc:
            return {
                **base,
                "ok": False,
                "attempted": True,
                "skipped": False,
                "reason": "sync-failed",
                "message": str(exc),
                "summary": {},
            }
