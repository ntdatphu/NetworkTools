from __future__ import annotations

from contextlib import closing
from typing import Any

from core.view_push import BaseViewPushController

from .commands import render_commands
from .desired_state import collect_vtp_state
from .schema import ensure_switch_schema
from .success_repository import mark_task_success
from .worker import apply_commands


PUBLIC_MODULES = (
    "vlan",
    "interfaces",
    "etherchannel",
    "stp",
    "vtp",
    "l2_security",
    "port_security",
)


class SwitchingViewPushController(BaseViewPushController):
    """Build and apply granular Layer 2 tasks scoped to the active tab."""

    module_label = "Switching"

    def reconciliation_options(self, module_name: str) -> dict[str, Any]:
        """Refresh the complete bounded switch snapshot after every Push."""
        return {"switch_state_keys": None}

    def _modules(self, module_name: str) -> tuple[str, ...]:
        normalized = (module_name or "all").strip().lower()
        if normalized == "all":
            return PUBLIC_MODULES
        if normalized not in PUBLIC_MODULES:
            raise ValueError(f"Unsupported Layer 2 module: {module_name}")
        return (normalized,)

    def _check_platform(self, host: str) -> None:
        context = self.db._routing_device_context(host)
        if context["template_folder"] != "cisco_ios":
            raise ValueError(
                f"Layer 2 View & Push currently supports Cisco IOS only, not {context['platform']}"
            )

    @staticmethod
    def _task(
        host: str,
        module: str,
        entity_key: str,
        label: str,
        payload: dict[str, Any],
        commands: list[str],
        tracking: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        return {
            "target": {"ip": host},
            "module": module,
            "entity_key": entity_key,
            "label": label,
            "config": payload,
            "commands": commands,
            "tracking": tracking or {},
            "success": "pending_apply",
        }

    def _vlan_tasks(self, host: str) -> list[dict[str, Any]]:
        with closing(self.db._connect()) as conn:
            rows = conn.execute(
                """
                SELECT id, vlan_id, vlan_name, state, success
                FROM t06_vlan_db
                WHERE host = ? AND (
                    success IN ('pending_apply','pending_delete') OR success IS NULL
                )
                ORDER BY vlan_id;
                """,
                (host,),
            ).fetchall()
        tasks = []
        for source in rows:
            row = dict(source)
            row_id = int(row.pop("id"))
            success = str(row.pop("success") or "pending_apply")
            row["action"] = "remove" if success == "pending_delete" else "setup"
            payload = {"vlans": [row]}
            tasks.append(self._task(
                host, "vlan", f"vlan:{row['vlan_id']}", f"VLAN {row['vlan_id']}",
                payload, render_commands("vlan", payload),
                {"success_rows": [{
                    "kind": "vlan",
                    "id": row_id,
                    "action": "delete" if success == "pending_delete" else "sync",
                }]},
            ))
            tasks[-1]["success"] = success
        return tasks

    def _interface_tasks(self, host: str) -> list[dict[str, Any]]:
        with closing(self.db._connect()) as conn:
            interfaces = conn.execute(
                """
                SELECT i.id, i.if_name, i.description, i.mode, i.admin_status,
                       i.speed, i.duplex, a.access_vlan, a.voice_vlan,
                       t.allowed_vlans, t.native_vlan, t.encapsulation,
                       t.pruning_vlans, i.success
                FROM t06_interface_l2 AS i
                LEFT JOIN t06_iface_access AS a ON a.iface_id = i.id
                LEFT JOIN t06_iface_trunk AS t ON t.iface_id = i.id
                WHERE i.host = ? AND i.mode <> 'routed' AND (
                    i.success IN ('pending_apply','pending_delete') OR i.success IS NULL
                )
                ORDER BY i.if_name COLLATE NOCASE;
                """,
                (host,),
            ).fetchall()
            stp_interfaces = conn.execute(
                """
                SELECT i.if_name, i.mode, s.portfast, s.bpduguard, s.bpdufilter,
                       s.root_guard, s.loop_guard
                FROM t06_interface_l2 AS i
                JOIN t06_iface_stp AS s ON s.iface_id = i.id
                WHERE i.host = ? AND i.mode <> 'routed' AND (
                    i.success IN ('pending_apply','pending_delete') OR i.success IS NULL
                );
                """,
                (host,),
            ).fetchall()
        stp_by_name = {str(row["if_name"]): dict(row) for row in stp_interfaces}
        tasks: list[dict[str, Any]] = []
        for source in interfaces:
            row = dict(source)
            row_id = int(row.pop("id"))
            success = str(row.pop("success") or "pending_apply")
            if row["mode"] == "hybrid":
                raise ValueError(
                    "Cisco IOS push does not support hybrid port without an "
                    f"explicit trunk profile: {row['if_name']}"
                )
            payload = {"interfaces": [row], "etherchannels": []}
            commands = render_commands("interfaces", payload)
            stp_row = stp_by_name.get(str(row["if_name"]))
            if stp_row is not None:
                commands.extend(render_commands("stp", {"global": [], "interfaces": [stp_row]}))
            tasks.append(
                self._task(
                    host,
                    "interfaces",
                    f"interface:{row['if_name']}",
                    row["if_name"],
                    payload,
                    commands,
                    {"success_rows": [{"kind": "interface", "id": row_id}]},
                )
            )
            tasks[-1]["success"] = success
        return tasks

    def _etherchannel_tasks(self, host: str) -> list[dict[str, Any]]:
        with closing(self.db._connect()) as conn:
            rows = conn.execute(
                """
                SELECT id, po_number, protocol, mode, member_ports, description,
                       success
                FROM t06_etherchannel
                WHERE host = ? AND (
                    success IN ('pending_apply','pending_delete') OR success IS NULL
                )
                ORDER BY po_number;
                """,
                (host,),
            ).fetchall()
            interface_rows = conn.execute(
                "SELECT id, if_name FROM t06_interface_l2 WHERE host = ?;",
                (host,),
            ).fetchall()
        logical_interface_ids: dict[int, int] = {}
        for interface in interface_rows:
            name = str(interface["if_name"] or "").strip().lower()
            compact = name.replace("-", "").replace(" ", "")
            prefix = "portchannel" if compact.startswith("portchannel") else "po"
            suffix = compact[len(prefix):] if compact.startswith(prefix) else ""
            if suffix.isdigit():
                logical_interface_ids[int(suffix)] = int(interface["id"])
        tasks: list[dict[str, Any]] = []
        valid_modes = {
            "lacp": {"active", "passive"},
            "pagp": {"desirable", "auto"},
            "static": {"on"},
        }
        for source in rows:
            row = dict(source)
            row_id = int(row.pop("id"))
            success = str(row.pop("success") or "pending_apply")
            row["action"] = "remove" if success == "pending_delete" else "setup"
            if success != "pending_delete" and (
                row["protocol"] not in valid_modes
                or row["mode"] not in valid_modes[row["protocol"]]
            ):
                raise ValueError(
                    "EtherChannel protocol/mode mismatch on Port-channel"
                    f"{row['po_number']}"
                )
            payload = {"interfaces": [], "etherchannels": [row]}
            success_rows = [{
                "kind": "etherchannel",
                "id": row_id,
                "action": "delete" if success == "pending_delete" else "sync",
            }]
            logical_interface_id = logical_interface_ids.get(int(row["po_number"]))
            if success == "pending_delete" and logical_interface_id is not None:
                success_rows.append({
                    "kind": "interface",
                    "id": logical_interface_id,
                    "action": "delete",
                })
            tasks.append(
                self._task(
                    host,
                    "etherchannel",
                    f"port-channel:{row['po_number']}",
                    f"Port-channel{row['po_number']}",
                    payload,
                    render_commands("interfaces", payload),
                    {"success_rows": success_rows},
                )
            )
            tasks[-1]["success"] = success
        return tasks

    def _stp_tasks(self, host: str) -> list[dict[str, Any]]:
        with closing(self.db._connect()) as conn:
            modes = {
                str(row["stp_mode"])
                for row in conn.execute(
                    "SELECT DISTINCT stp_mode FROM t06_stp_config WHERE host = ?;",
                    (host,),
                ).fetchall()
            }
            rows = conn.execute(
                """
                SELECT id, vlan_id, stp_mode, priority, root_role, success
                FROM t06_stp_config
                WHERE host = ? AND (
                    success IN ('pending_apply','pending_delete') OR success IS NULL
                )
                ORDER BY vlan_id;
                """,
                (host,),
            ).fetchall()
        if len(modes) > 1:
            raise ValueError("A Cisco IOS switch cannot use multiple global STP modes")
        tasks: list[dict[str, Any]] = []
        for source in rows:
            row = dict(source)
            row_id = int(row.pop("id"))
            success = str(row.pop("success") or "pending_apply")
            payload = {"global": [row], "interfaces": []}
            tasks.append(
                self._task(
                    host,
                    "stp",
                    f"vlan:{row['vlan_id']}",
                    f"STP VLAN {row['vlan_id']}",
                    payload,
                    render_commands("stp", payload),
                    {"success_rows": [{"kind": "stp", "id": row_id}]},
                )
            )
            tasks[-1]["success"] = success
        return tasks

    def _vtp_tasks(self, host: str) -> list[dict[str, Any]]:
        with closing(self.db._connect()) as conn:
            pending = conn.execute(
                """
                SELECT vtp_switch_id, success FROM t09_vtp_switches
                WHERE host = ? AND (
                    success IN ('pending_apply','pending_delete') OR success IS NULL
                );
                """,
                (host,),
            ).fetchall()
            if not pending:
                return []
            payload = collect_vtp_state(conn, host)
        if not payload["vtp"]:
            return []
        task = [
            self._task(
                host,
                "vtp",
                "database:vlan",
                "VTP VLAN database",
                payload,
                render_commands("vtp", payload),
                {"success_rows": [
                    {"kind": "vtp", "id": int(row["vtp_switch_id"])}
                    for row in pending
                ]},
            )
        ]
        task[0]["success"] = str(pending[0]["success"])
        return task

    def _security_tasks(self, host: str, module: str) -> list[dict[str, Any]]:
        with closing(self.db._connect()) as conn:
            if module == "port_security":
                port_rows = conn.execute(
                    """
                    SELECT i.if_name, ps.iface_id AS id, ps.enabled, ps.max_mac,
                           ps.violation, ps.sticky, ps.aging_type, ps.aging_time,
                           ps.success
                    FROM t06_iface_port_security AS ps
                    JOIN t06_interface_l2 AS i ON i.id = ps.iface_id
                    WHERE i.host = ? AND i.mode = 'access' AND (
                        ps.success IN ('pending_apply','pending_delete')
                        OR ps.success IS NULL
                    )
                    ORDER BY i.if_name COLLATE NOCASE;
                    """,
                    (host,),
                ).fetchall()
                vlan_rows = trust_rows = static_rows = []
            else:
                port_rows = []
                vlan_rows = conn.execute(
                    """
                    SELECT id, vlan_id, dhcp_snooping, dai_enabled, success
                    FROM t06_security_l2
                    WHERE host = ? AND (
                        success IN ('pending_apply','pending_delete') OR success IS NULL
                    )
                    ORDER BY vlan_id;
                    """,
                    (host,),
                ).fetchall()
                trust_rows = conn.execute(
                    """
                    SELECT id, if_name, success FROM t06_dhcp_trust_ports
                    WHERE host = ? AND (
                        success IN ('pending_apply','pending_delete') OR success IS NULL
                    )
                    ORDER BY if_name COLLATE NOCASE;
                    """,
                    (host,),
                ).fetchall()
                static_rows = conn.execute(
                    """
                    SELECT m.id, m.mac_addr, m.vlan_id, i.if_name, m.success
                    FROM t06_iface_mac_table AS m
                    JOIN t06_interface_l2 AS i ON i.id = m.iface_id
                    WHERE i.host = ? AND m.mac_type = 'static' AND (
                        m.success IN ('pending_apply','pending_delete') OR m.success IS NULL
                    )
                    ORDER BY m.vlan_id, m.mac_addr;
                    """,
                    (host,),
                ).fetchall()
        tasks: list[dict[str, Any]] = []
        if module == "port_security":
            for source in port_rows:
                config_row = dict(source)
                row_id = int(config_row.pop("id"))
                success = str(config_row.pop("success") or "pending_apply")
                payload = {
                    "vlans": [],
                    "trust_ports": [],
                    "ports": [config_row],
                    "static_macs": [],
                }
                tasks.append(
                    self._task(
                        host,
                        module,
                        f"interface:{config_row['if_name']}",
                        f"Port Security {config_row['if_name']}",
                        payload,
                        render_commands("security", payload),
                        {"success_rows": [{
                            "kind": "port_security", "id": row_id
                        }]},
                    )
                )
                tasks[-1]["success"] = success
            return tasks

        for source in vlan_rows:
            row = dict(source)
            row_id = int(row.pop("id"))
            success = str(row.pop("success") or "pending_apply")
            payload = {
                "vlans": [row],
                "trust_ports": [],
                "ports": [],
                "static_macs": [],
            }
            tasks.append(
                self._task(
                    host,
                    module,
                    f"vlan:{row['vlan_id']}",
                    f"L2 Security VLAN {row['vlan_id']}",
                    payload,
                    render_commands("security", payload),
                    {"success_rows": [{"kind": "l2_vlan", "id": row_id}]},
                )
            )
            tasks[-1]["success"] = success
        for source in trust_rows:
            row = dict(source)
            row_id = int(row.pop("id"))
            success = str(row.pop("success") or "pending_apply")
            if_name = str(row["if_name"])
            payload = {
                "vlans": [],
                "trust_ports": [if_name],
                "ports": [],
                "static_macs": [],
            }
            tasks.append(
                self._task(
                    host,
                    module,
                    f"trust:{if_name}",
                    f"Trusted uplink {if_name}",
                    payload,
                    render_commands("security", payload),
                    {"success_rows": [{"kind": "trust_port", "id": row_id}]},
                )
            )
            tasks[-1]["success"] = success
        for source in static_rows:
            row = dict(source)
            row_id = int(row.pop("id"))
            success = str(row.pop("success") or "pending_apply")
            payload = {
                "vlans": [],
                "trust_ports": [],
                "ports": [],
                "static_macs": [row],
            }
            key = f"static:{row['mac_addr']}:{row['vlan_id']}:{row['if_name']}"
            tasks.append(
                self._task(
                    host,
                    module,
                    key,
                    f"Static MAC {row['mac_addr']}",
                    payload,
                    render_commands("security", payload),
                    {"success_rows": [{"kind": "static_mac", "id": row_id}]},
                )
            )
            tasks[-1]["success"] = success
        return tasks

    def _candidate_tasks(self, host: str, module: str) -> list[dict[str, Any]]:
        if module == "vlan":
            return self._vlan_tasks(host)
        if module == "interfaces":
            return self._interface_tasks(host)
        if module == "etherchannel":
            return self._etherchannel_tasks(host)
        if module == "stp":
            return self._stp_tasks(host)
        if module == "vtp":
            return self._vtp_tasks(host)
        return self._security_tasks(host, module)

    def collect_pending_tasks(
        self, host: str, module_name: str = "all"
    ) -> list[dict[str, Any]]:
        self._check_platform(host)
        ensure_switch_schema(self.db)
        tasks: list[dict[str, Any]] = []
        for module in self._modules(module_name):
            tasks.extend(self._candidate_tasks(host, module))
        return tasks

    def render_task_preview(
        self, task: dict[str, Any], module_name: str = "all"
    ) -> list[str]:
        return [
            f"# {task['target']['ip']} / SWITCHING / {task['label']}",
            *task["commands"],
        ]

    def pending_state(self, host: str, module_name: str = "all") -> dict[str, Any]:
        result = super().pending_state(host, module_name)
        result["success"] = bool(result.get("ok"))
        return result

    def preview(self, host: str, module_name: str = "all") -> dict[str, Any]:
        result = super().preview(host, module_name)
        result["success"] = bool(result.get("ok"))
        return result

    def push(self, host: str, module_name: str = "all") -> dict[str, Any]:
        result = super().push(host, module_name)
        result["success"] = bool(result.get("ok"))
        return result

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
        # One Netmiko config transaction is materially faster on serial/virtual
        # IOS sessions than entering and leaving configuration mode once per
        # database row. Renderers terminate their interface/VLAN submodes, so
        # task boundaries remain safe inside this combined command stream.
        commands = [command for task in tasks for command in task["commands"]]
        try:
            output = apply_commands(connector, commands)
            for task in tasks:
                mark_task_success(self.db, task.get("tracking") or {})
                report.append(
                    {
                        "ip": host,
                        "module": task["module"],
                        "entity": task["entity_key"],
                        "status": "SUCCESS",
                        "success": True,
                        "log": output,
                        "db_updated": True,
                    }
                )
        except Exception as exc:
            task = tasks[0]
            report.append(
                {
                    "ip": host,
                    "module": task["module"],
                    "entity": task["entity_key"],
                    "status": "FAIL",
                    "success": False,
                    "log": str(exc),
                    "db_updated": False,
                }
            )

        success = bool(report) and all(item["success"] for item in report)
        detail = next((item["log"] for item in report if not item["success"]), "")
        return {
            "ok": success,
            "success": success,
            "message": (
                f"Applied {len(report)} Layer 2 task(s)."
                if success
                else f"Layer 2 push stopped: {detail}"
            ),
            "report": report,
        }
