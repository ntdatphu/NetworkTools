"""View & Push controller for FHRP."""

from __future__ import annotations

from typing import Any

from core.view_push import BaseViewPushController, _variant_list

from .collector import collect_fhrp_tasks
from .commands import redact_fhrp_commands, render_fhrp_commands
from .push_state import apply_fhrp_success
from .worker import push_fhrp_tasks


class FhrpViewPushController(BaseViewPushController):
    """Preview and push all pending FHRP members for one host."""

    module_label = "FHRP"

    def collect_pending_tasks(
        self, host: str, module_name: str = "all"
    ) -> list[dict[str, Any]]:
        tasks = collect_fhrp_tasks(self.db, self._clean_host(host))
        protocol = str(module_name or "all").strip().lower()
        if protocol in {"hsrp", "vrrp", "glbp"}:
            return [task for task in tasks if task["sub_type"] == protocol]
        return tasks

    def render_task_preview(
        self, task: dict[str, Any], module_name: str = "all"
    ) -> list[str]:
        host = task["target"]["ip"]
        context = self.db._routing_device_context(host)
        commands = render_fhrp_commands(task, context["template_folder"])
        return [
            f"# {host} / {task['sub_type'].upper()} / {task['action'].upper()}",
            *redact_fhrp_commands(commands),
        ]

    def push_tasks(
        self, host: str, module_name: str, tasks: list[dict[str, Any]]
    ) -> dict[str, Any]:
        context = self.db._routing_device_context(host)
        if context["template_folder"] != "cisco_ios":
            return {
                "ok": False,
                "message": "FHRP push currently supports Cisco IOS only.",
                "report": [],
            }
        provider = self._session_provider_for_host(host)
        if provider is None:
            return {
                "ok": False,
                "message": "FHRP RESTCONF push is not integrated.",
                "report": [],
            }
        reports = push_fhrp_tasks(tasks, context["template_folder"], provider)
        for report in reports:
            if report["status"] == "SUCCESS":
                apply_fhrp_success(self.db, report["task"])
        ok = bool(reports) and all(row["status"] == "SUCCESS" for row in reports)
        detail = next(
            (row["log"] for row in reports if row["status"] != "SUCCESS"),
            "",
        )
        return {
            "ok": ok,
            "message": (
                "FHRP push completed."
                if ok
                else f"FHRP push finished with errors: {detail}"
            ),
            "report": _variant_list(
                [{key: value for key, value in row.items() if key != "task"} for row in reports]
            ),
        }
