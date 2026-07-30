"""Send rendered FHRP commands through an app-owned device session."""

from __future__ import annotations

from typing import Any, Callable

from .commands import redact_fhrp_commands, render_fhrp_commands


def push_fhrp_tasks(
    tasks: list[dict[str, Any]],
    template_folder: str,
    session_provider: Callable[[str], Any],
) -> list[dict[str, Any]]:
    """Push tasks independently and return one report item per FHRP member."""
    reports: list[dict[str, Any]] = []
    for task in tasks:
        host = str(task.get("target", {}).get("ip") or "")
        config = task.get("config") or {}
        commands = render_fhrp_commands(task, template_folder)
        try:
            connector = session_provider(host)
            if connector is None:
                raise RuntimeError("No active device session is available")
            connection = getattr(connector, "connection", connector)
            output = connection.send_config_set(
                commands,
                read_timeout=120,
                cmd_verify=False,
            )
            reports.append(
                {
                    "host": host,
                    "member_id": config.get("member_id"),
                    "status": "SUCCESS",
                    "commands": redact_fhrp_commands(commands),
                    "log": str(output or ""),
                    "task": task,
                }
            )
        except Exception as exc:
            reports.append(
                {
                    "host": host,
                    "member_id": config.get("member_id"),
                    "status": "FAILED",
                    "commands": redact_fhrp_commands(commands),
                    "log": str(exc),
                    "task": task,
                }
            )
    return reports
