from __future__ import annotations

import json
import sqlite3
import sys
from abc import ABC, abstractmethod
from pathlib import Path
from typing import Any

from .runtime import device_session_registry


def _variant_list(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return rows


def _success_state(value: Any) -> str:
    if value is None or value == "pending_apply":
        return "setup"
    if value == "pending_delete":
        return "remove"
    return "ignore"


def _has_text_bit(action_cfg: str, bit_index_from_right: int) -> bool:
    if not action_cfg:
        return True
    pos = len(action_cfg) - 1 - bit_index_from_right
    if pos < 0 or pos >= len(action_cfg):
        return False
    return action_cfg[pos] == "1"


class BaseViewPushController(ABC):
    module_label = "Configuration"

    def __init__(self, db: Any, session_registry: Any | None = None) -> None:
        self.db = db
        # The running application injects its workspace-aware registry.  Keep
        # the module singleton only as a compatibility fallback for standalone
        # controller users.
        self._session_registry = session_registry or device_session_registry

    def _clean_host(self, host: str) -> str:
        return (host or "").strip()

    def _empty_preview(self, message: str) -> dict[str, Any]:
        return {"ok": True, "message": message, "commands": "", "tasks": []}

    def pending_state(self, host: str, module_name: str = "all") -> dict[str, Any]:
        host = self._clean_host(host)
        if not host:
            return {"ok": False, "hasPending": False, "count": 0, "message": "Host is empty."}
        try:
            tasks = self.collect_pending_tasks(host, module_name)
            count = len(tasks)
            return {
                "ok": True,
                "hasPending": count > 0,
                "count": count,
                "message": f"{count} pending {self.module_label.lower()} task(s)." if count else "No configuration required for Push.",
            }
        except Exception as exc:
            return {"ok": False, "hasPending": False, "count": 0, "message": str(exc)}

    def has_pending(self, host: str, module_name: str = "all") -> bool:
        return bool(self.pending_state(host, module_name).get("hasPending"))

    def preview(self, host: str, module_name: str = "all") -> dict[str, Any]:
        host = self._clean_host(host)
        if not host:
            return {"ok": False, "message": "Host is empty.", "commands": "", "tasks": []}

        try:
            tasks = self.collect_pending_tasks(host, module_name)
            if not tasks:
                return self._empty_preview("No configuration required for Push.")

            rendered: list[str] = []
            for task in tasks:
                rendered.extend(self.render_task_preview(task, module_name))
                rendered.append("")

            return {
                "ok": True,
                "message": f"Prepared {len(tasks)} {self.module_label.lower()} task(s).",
                "commands": "\n".join(rendered).strip(),
                "tasks": _variant_list(tasks),
            }
        except Exception as exc:
            message = f"Preview {self.module_label.lower()} failed: {exc}"
            return {"ok": False, "message": message, "commands": "", "tasks": []}

    def push(self, host: str, module_name: str = "all") -> dict[str, Any]:
        host = self._clean_host(host)
        if not host:
            return {"ok": False, "message": "Host is empty.", "report": []}

        try:
            tasks = self.collect_pending_tasks(host, module_name)
            if not tasks:
                return {"ok": True, "message": "No configuration required for Push.", "report": []}
            return self.push_tasks(host, module_name, tasks)
        except Exception as exc:
            return {"ok": False, "message": f"Push {self.module_label.lower()} failed: {exc}", "report": []}

    def _session_provider_for_host(self, host: str):
        context = self.db._routing_device_context(host)
        method = (context.get("method") or "SSH").upper()
        if method in {"SSH", "TELNET"}:
            def provider(target_host: str):
                connector = self._session_registry.get_connector(target_host)
                if connector is not None:
                    return connector
                opened = self._session_registry.open(target_host)
                if opened.get("ok"):
                    connector = self._session_registry.get_connector(target_host)
                    if connector is not None:
                        return connector
                message = str(
                    opened.get("message")
                    or f"Could not open a device session for {target_host}."
                )
                raise RuntimeError(message)
            return provider
        if method == "RESTCONF":
            return None
        raise ValueError(f"persistent tab session is not supported for {method}")

    @abstractmethod
    def collect_pending_tasks(self, host: str, module_name: str = "all") -> list[dict[str, Any]]:
        raise NotImplementedError

    @abstractmethod
    def render_task_preview(self, task: dict[str, Any], module_name: str = "all") -> list[str]:
        raise NotImplementedError

    @abstractmethod
    def push_tasks(self, host: str, module_name: str, tasks: list[dict[str, Any]]) -> dict[str, Any]:
        raise NotImplementedError


class DhcpViewPushController(BaseViewPushController):
    module_label = "DHCP"

    def collect_pending_tasks(self, host: str, module_name: str = "all") -> list[dict[str, Any]]:
        host = self._clean_host(host)
        if not host:
            return []

        with self.db._connect() as conn:
            cursor = conn.cursor()
            config_data = {"pools": [], "excluded_addresses": [], "relays": []}
            ids = {
                "pool_add": [],
                "pool_del": [],
                "exc_add": [],
                "exc_del": [],
                "helper_add": [],
                "helper_del": [],
            }

            for row in cursor.execute(
                """
                SELECT ex_id, start_ip, end_ip, sync_status
                FROM t03_excluded_address
                WHERE host = ? AND (sync_status IN ('pending_apply', 'pending_delete') OR sync_status IS NULL)
                ORDER BY ex_id;
                """,
                (host,),
            ).fetchall():
                state = _success_state(row["sync_status"])
                config_data["excluded_addresses"].append({
                    "start_ip": row["start_ip"],
                    "end_ip": row["end_ip"],
                    "state": state,
                })
                ids["exc_del" if state == "remove" else "exc_add"].append(row["ex_id"])

            for row in cursor.execute(
                """
                SELECT dhcp_id, pool, network, subnetmask, defaut, dns, lease, sync_status, action_Cfg
                FROM t03_dhcp_pool
                WHERE host = ? AND (sync_status IN ('pending_apply', 'pending_delete') OR sync_status IS NULL)
                ORDER BY dhcp_id;
                """,
                (host,),
            ).fetchall():
                state = _success_state(row["sync_status"])
                action_cfg = row["action_Cfg"] or "111"
                config_data["pools"].append({
                    "name": row["pool"],
                    "network": row["network"],
                    "subnet_mask": row["subnetmask"],
                    "default_gateway": row["defaut"],
                    "dns_server": row["dns"],
                    "lease": row["lease"],
                    "push_default": _has_text_bit(action_cfg, 2),
                    "push_dns": _has_text_bit(action_cfg, 1),
                    "push_lease": _has_text_bit(action_cfg, 0),
                    "state": state,
                })
                ids["pool_del" if state == "remove" else "pool_add"].append(row["dhcp_id"])

            if self.db._table_exists(conn, "t03_router_iface_helper") and self.db._table_exists(conn, "t02_interface_name"):
                iface_columns = self.db._table_columns(conn, "t02_interface_name")
                iface_col = "t02_interface_name" if "t02_interface_name" in iface_columns else "interface_name"
                for row in cursor.execute(
                    f"""
                    SELECT h.id, i.{iface_col} AS interface_name, h.helper_ip, h.sync_status
                    FROM t03_router_iface_helper h
                    JOIN t02_interface_name i ON i.iface_id = h.iface_id
                    WHERE i.host = ? AND (h.sync_status IN ('pending_apply', 'pending_delete') OR h.sync_status IS NULL)
                    ORDER BY i.{iface_col} COLLATE NOCASE, h.id;
                    """,
                    (host,),
                ).fetchall():
                    state = _success_state(row["sync_status"])
                    config_data["relays"].append({
                        "interface": row["interface_name"],
                        "helper_address": row["helper_ip"],
                        "state": state,
                    })
                    ids["helper_del" if state == "remove" else "helper_add"].append(row["id"])

        if not any(ids.values()):
            return []

        return [{"target": {"ip": host}, "action": "setup", "ids": ids, "config": [config_data]}]

    def render_task_preview(self, task: dict[str, Any], module_name: str = "all") -> list[str]:
        from features.dhcp.worker import render_dhcp_template

        target = task.get("target", {}).get("ip", "")
        context = self.db._routing_device_context(target)
        raw_config = task.get("config", [])
        configs = raw_config if isinstance(raw_config, list) else [raw_config]

        rendered = [f"# {target} / DHCP / SETUP"]
        for cfg in configs:
            commands = render_dhcp_template(context["platform"], {"config": [cfg]})
            lines = [line.strip() for line in commands.splitlines() if line.strip() and not line.strip().startswith("!")]
            rendered.extend(lines or ["# No commands rendered."])
        return rendered

    def push_tasks(self, host: str, module_name: str, tasks: list[dict[str, Any]]) -> dict[str, Any]:
        self.db._sync_worker_paths()
        from infrastructure.network.config import DHCP_OUTPUT
        from features.dhcp.worker import run_dhcp_config

        output_path = Path(DHCP_OUTPUT)
        session_provider = self._session_provider_for_host(host)
        run_dhcp_config(tasks, str(self.db.db_path), str(output_path), session_provider=session_provider)

        results: list[dict[str, Any]] = []
        if output_path.exists():
            results = json.loads(output_path.read_text(encoding="utf-8"))

        report = self._mark_applied(tasks, results)
        ok = bool(report) and all(item["status"] == "SUCCESS" for item in report)
        if not report:
            return {"ok": True, "message": "No configuration required for Push.", "report": []}

        detail = next((item["log"] for item in report if item["status"] != "SUCCESS" and item.get("log")), "")
        return {
            "ok": ok,
            "message": "DHCP push completed." if ok else f"DHCP push finished with errors: {detail}" if detail else "DHCP push finished with errors.",
            "report": _variant_list(report),
        }

    def _mark_applied(self, tasks: list[dict[str, Any]], results: list[dict[str, Any]]) -> list[dict[str, Any]]:
        task_by_ip = {task.get("target", {}).get("ip"): task for task in tasks}
        report: list[dict[str, Any]] = []

        with self.db._connect() as conn:
            cursor = conn.cursor()
            for result in results:
                ip = result.get("target") or result.get("ip") or result.get("host")
                status = "SUCCESS" if result.get("status") == "success" else "FAIL"
                item = {
                    "ip": ip,
                    "status": status,
                    "log": result.get("message", result.get("msg", "")),
                    "db_updated": False,
                }
                task = task_by_ip.get(ip)
                if status == "SUCCESS" and task:
                    changes = self._apply_task_mark(cursor, task)
                    item["db_updated"] = changes > 0
                    if changes <= 0:
                        item["status"] = "FAIL"
                        item["log"] = (item["log"] + " " if item["log"] else "") + "Worker succeeded, but no DHCP database rows were updated."
                report.append(item)
            conn.commit()

        return report

    def _apply_task_mark(self, cursor: sqlite3.Cursor, task: dict[str, Any]) -> int:
        ids = task.get("ids", {})
        changes = 0

        for row_id in ids.get("exc_add", []):
            cursor.execute("UPDATE t03_excluded_address SET sync_status = 'synchronized' WHERE ex_id = ?", (row_id,))
            changes += cursor.rowcount
        for row_id in ids.get("exc_del", []):
            cursor.execute("DELETE FROM t03_excluded_address WHERE ex_id = ?", (row_id,))
            changes += cursor.rowcount

        for row_id in ids.get("pool_add", []):
            cursor.execute("UPDATE t03_dhcp_pool SET sync_status = 'synchronized' WHERE dhcp_id = ?", (row_id,))
            changes += cursor.rowcount
        for row_id in ids.get("pool_del", []):
            cursor.execute("DELETE FROM t03_dhcp_pool WHERE dhcp_id = ?", (row_id,))
            changes += cursor.rowcount

        for row_id in ids.get("helper_add", []):
            cursor.execute("UPDATE t03_router_iface_helper SET sync_status = 'synchronized' WHERE id = ?", (row_id,))
            changes += cursor.rowcount
        for row_id in ids.get("helper_del", []):
            cursor.execute("DELETE FROM t03_router_iface_helper WHERE id = ?", (row_id,))
            changes += cursor.rowcount

        return changes


class NatViewPushController(BaseViewPushController):
    module_label = "NAT"

    def collect_pending_tasks(self, host: str, module_name: str = "all") -> list[dict[str, Any]]:
        self.db._sync_worker_paths()
        from features.nat.dispatcher import nat_dispatcher

        return nat_dispatcher(target_ip=self._clean_host(host), dry_run=True) or []

    def render_task_preview(self, task: dict[str, Any], module_name: str = "all") -> list[str]:
        from features.nat.worker import render_nat_payload

        target = task.get("target", {}).get("ip", "")
        context = self.db._routing_device_context(target)
        commands = render_nat_payload(task, context["template_folder"])
        return [f"# {target} / NAT / SETUP", *(commands or ["# No commands rendered."])]

    def push_tasks(self, host: str, module_name: str, tasks: list[dict[str, Any]]) -> dict[str, Any]:
        self.db._sync_worker_paths()
        from infrastructure.network.config import NAT_OUTPUT
        from features.nat.dispatcher import apply_nat_results
        from features.nat.worker import run_nat_config

        output_path = Path(NAT_OUTPUT)
        session_provider = self._session_provider_for_host(host)
        run_nat_config(tasks, str(self.db.db_path), str(output_path), session_provider=session_provider)
        results: list[dict[str, Any]] = []
        if output_path.exists():
            results = json.loads(output_path.read_text(encoding="utf-8"))
        report = apply_nat_results(tasks, results, str(self.db.db_path))
        ok = bool(report) and all(item["status"] == "SUCCESS" for item in report)
        if not report:
            return {"ok": False, "message": "NAT worker returned no result; database state was not changed.", "report": []}
        detail = next((item["log"] for item in report if item["status"] != "SUCCESS" and item.get("log")), "")
        return {
            "ok": ok,
            "message": "NAT push completed." if ok else f"NAT push finished with errors: {detail}" if detail else "NAT push finished with errors.",
            "report": _variant_list(report),
        }


class AclViewPushController(BaseViewPushController):
    module_label = "ACL"

    def collect_pending_tasks(self, host: str, module_name: str = "all") -> list[dict[str, Any]]:
        self.db._sync_worker_paths()
        from features.acl.dispatcher import acl_dispatcher

        return acl_dispatcher(target_ip=self._clean_host(host), dry_run=True) or []

    def render_task_preview(self, task: dict[str, Any], module_name: str = "all") -> list[str]:
        from features.acl.worker import render_acl_payload

        target = task.get("target", {}).get("ip", "")
        context = self.db._routing_device_context(target)
        config = task.get("config", {})
        acl_name = str(config.get("acl_name") or "")
        commands = render_acl_payload(task, context["template_folder"])
        return [f"# {target} / ACL / {acl_name}", *(commands or ["# No commands rendered."])]

    def push_tasks(self, host: str, module_name: str, tasks: list[dict[str, Any]]) -> dict[str, Any]:
        self.db._sync_worker_paths()
        from infrastructure.network.config import ACL_OUTPUT
        from features.acl.dispatcher import apply_acl_results
        from features.acl.worker import run_acl_config

        output_path = Path(ACL_OUTPUT)
        session_provider = self._session_provider_for_host(host)
        run_acl_config(tasks, str(self.db.db_path), str(output_path), session_provider=session_provider)
        results: list[dict[str, Any]] = []
        if output_path.exists():
            results = json.loads(output_path.read_text(encoding="utf-8"))
        report = apply_acl_results(tasks, results, str(self.db.db_path))
        ok = bool(report) and all(item["status"] == "SUCCESS" for item in report)
        if not report:
            return {
                "ok": False,
                "message": "ACL worker returned no result; database state was not changed.",
                "report": [],
            }
        detail = next(
            (item["log"] for item in report if item["status"] != "SUCCESS" and item.get("log")),
            "",
        )
        return {
            "ok": ok,
            "message": (
                "ACL push completed."
                if ok
                else f"ACL push finished with errors: {detail}"
                if detail
                else "ACL push finished with errors."
            ),
            "report": _variant_list(report),
        }


class ViewPushControllerFactory:
    def __init__(self, db: Any, session_registry: Any | None = None) -> None:
        from features.fhrp.view_push import FhrpViewPushController
        from features.interfaces.view_push import InterfaceViewPushController
        from features.routing.view_push import RoutingViewPushController
        from features.switching.view_push import SwitchingViewPushController

        self._controllers = {
            "routing": RoutingViewPushController(db, session_registry),
            "dhcp": DhcpViewPushController(db, session_registry),
            "nat": NatViewPushController(db, session_registry),
            "acl": AclViewPushController(db, session_registry),
            "interface": InterfaceViewPushController(db, session_registry),
            "fhrp": FhrpViewPushController(db, session_registry),
            "switching": SwitchingViewPushController(db, session_registry),
        }

    def get(self, controller_name: str) -> BaseViewPushController:
        key = (controller_name or "").strip().lower()
        if key not in self._controllers:
            raise ValueError(f"Unsupported View & Push controller: {controller_name}")
        return self._controllers[key]


def __getattr__(name: str) -> Any:
    """Keep the former routing-controller import working after extraction."""
    if name == "RoutingViewPushController":
        from features.routing.view_push import RoutingViewPushController

        return RoutingViewPushController
    raise AttributeError(name)
