from __future__ import annotations

from typing import Any

from core.view_push import BaseViewPushController

from .commands import render_commands
from .desired_state import MODULES, collect_desired_state
from .push_state_repository import is_payload_pending, mark_payload_applied
from .worker import apply_commands


class SwitchingViewPushController(BaseViewPushController):
    module_label = "Switching"

    def _modules(self, module_name: str) -> tuple[str, ...]:
        normalized = (module_name or "all").strip().lower()
        if normalized == "all":
            return MODULES
        if normalized not in MODULES:
            raise ValueError(f"Unsupported Layer 2 module: {module_name}")
        return (normalized,)

    def _check_platform(self, host: str) -> None:
        context = self.db._routing_device_context(host)
        if context["template_folder"] != "cisco_ios":
            raise ValueError(
                f"Layer 2 View & Push currently supports Cisco IOS only, not {context['platform']}"
            )

    def collect_pending_tasks(
        self, host: str, module_name: str = "all"
    ) -> list[dict[str, Any]]:
        self._check_platform(host)
        tasks: list[dict[str, Any]] = []
        for name in self._modules(module_name):
            payload = collect_desired_state(self.db, host, name)
            commands = render_commands(name, payload)
            if commands and is_payload_pending(self.db, host, name, payload):
                tasks.append(
                    {
                        "target": {"ip": host},
                        "module": name,
                        "config": payload,
                        "commands": commands,
                    }
                )
        return tasks

    def render_task_preview(
        self, task: dict[str, Any], module_name: str = "all"
    ) -> list[str]:
        name = str(task["module"])
        return [
            f"# {task['target']['ip']} / SWITCHING / {name.upper()}",
            *task["commands"],
        ]

    def push_tasks(
        self, host: str, module_name: str, tasks: list[dict[str, Any]]
    ) -> dict[str, Any]:
        provider = self._session_provider_for_host(host)
        if provider is None:
            raise ValueError("Layer 2 RESTCONF push is not implemented")
        connector = provider(host)
        if connector is None:
            raise RuntimeError(f"Could not open a device session for {host}")

        report: list[dict[str, Any]] = []
        for task in tasks:
            name = str(task["module"])
            try:
                output = apply_commands(connector, task["commands"])
                mark_payload_applied(self.db, host, name, task["config"])
                report.append(
                    {
                        "ip": host,
                        "module": name,
                        "status": "SUCCESS",
                        "log": output,
                        "db_updated": True,
                    }
                )
            except Exception as exc:
                report.append(
                    {
                        "ip": host,
                        "module": name,
                        "status": "FAIL",
                        "log": str(exc),
                        "db_updated": False,
                    }
                )
                break

        ok = bool(report) and all(item["status"] == "SUCCESS" for item in report)
        detail = next(
            (item["log"] for item in report if item["status"] != "SUCCESS"), ""
        )
        return {
            "ok": ok,
            "message": (
                "Layer 2 push completed."
                if ok
                else f"Layer 2 push stopped: {detail}"
            ),
            "report": report,
        }
