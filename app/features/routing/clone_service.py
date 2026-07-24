"""Clone one OSPF/EIGRP process to one or more connected inventory hosts."""

from __future__ import annotations

from copy import deepcopy
from typing import Any

from .eigrp import get_eigrp_routing, save_eigrp_routing
from .ospf import get_ospf_routing, save_ospf_routing


_DB_ONLY_KEYS = {"id", "ospf_id", "eigrp_id", "area_db_id", "iface_id", "success"}


class RoutingCloneService:
    def __init__(self, db: Any) -> None:
        self.db = db

    def connected_hosts(self) -> list[str]:
        with self.db._connect() as conn:
            rows = conn.execute("SELECT host FROM t01_devices WHERE success = 1 ORDER BY host").fetchall()
        return [str(row["host"]) for row in rows]

    def processes(self, host: str, protocol: str) -> list[dict[str, Any]]:
        key = self._process_key(protocol)
        return [
            {
                "index": index,
                "value": int(process[key]),
                "label": ("PID " if protocol.lower() == "ospf" else "AS ") + str(process[key]),
                "routerId": str(process.get("router_id") or ""),
            }
            for index, process in enumerate(self._load(host, protocol).get("processes") or [])
        ]

    def process_exists(self, host: str, protocol: str, process_id: int) -> bool:
        key = self._process_key(protocol)
        return any(int(item.get(key)) == int(process_id) for item in self._load(host, protocol).get("processes") or [])

    def clone(
        self,
        source_host: str,
        target_host: str,
        protocol: str,
        source_index: int,
        new_id: int,
        router_id: str | None = None,
    ) -> dict[str, Any]:
        protocol = self._protocol(protocol)
        if target_host not in self.connected_hosts():
            return {"ok": False, "message": "Target host must have success = 1."}
        source_processes = self._load(source_host, protocol).get("processes") or []
        if source_index < 0 or source_index >= len(source_processes):
            return {"ok": False, "message": "Source process was not found."}
        if self.process_exists(target_host, protocol, new_id):
            return {"ok": False, "message": f"Process ID {new_id} already exists on {target_host}."}
        target_processes = list(self._load(target_host, protocol).get("processes") or [])
        clone = self._strip_database_state(deepcopy(source_processes[source_index]))
        clone[self._process_key(protocol)] = int(new_id)
        if router_id is not None:
            clone["router_id"] = str(router_id).strip() or None
        target_processes.append(clone)
        saved = save_ospf_routing(self.db, target_host, target_processes) if protocol == "ospf" else save_eigrp_routing(self.db, target_host, target_processes)
        return {
            "ok": bool(saved),
            "message": f"Cloned {protocol.upper()} process to {target_host} with ID {new_id}." if saved else f"Could not save cloned {protocol.upper()} process.",
        }

    def clone_targets(
        self,
        source_host: str,
        targets: list[dict[str, Any]],
        protocol: str,
        source_index: int,
    ) -> dict[str, Any]:
        """Clone with an independent process identifier and router-id per host."""
        successful: list[str] = []
        failed: list[dict[str, str]] = []
        seen: set[str] = set()
        for target in targets:
            host = str(target.get("host") or "").strip()
            if not host or host in seen:
                continue
            seen.add(host)
            try:
                new_id = int(target.get("processId"))
                result = self.clone(
                    source_host,
                    host,
                    protocol,
                    source_index,
                    new_id,
                    str(target.get("routerId") or "").strip(),
                )
            except (TypeError, ValueError) as exc:
                result = {"ok": False, "message": f"Invalid target values: {exc}"}
            if result.get("ok"):
                successful.append(host)
            else:
                failed.append({"host": host, "reason": str(result.get("message") or "Clone failed.")})
        return self._batch_result(successful, failed)

    def clone_many(
        self,
        source_host: str,
        target_hosts: list[str],
        protocol: str,
        source_index: int,
        new_id: int,
    ) -> dict[str, Any]:
        """Clone independently so one invalid/unavailable host does not block the rest."""
        normalized_hosts = list(dict.fromkeys(str(host or "").strip() for host in target_hosts))
        normalized_hosts = [host for host in normalized_hosts if host]
        if not normalized_hosts:
            return {
                "ok": False,
                "message": "Select at least one target host.",
                "successful": [],
                "failed": [],
            }

        successful: list[str] = []
        failed: list[dict[str, str]] = []
        for host in normalized_hosts:
            try:
                result = self.clone(source_host, host, protocol, source_index, new_id)
            except Exception as exc:
                result = {"ok": False, "message": str(exc)}
            if result.get("ok"):
                successful.append(host)
            else:
                failed.append({"host": host, "reason": str(result.get("message") or "Clone failed.")})

        return self._batch_result(successful, failed)

    @staticmethod
    def _batch_result(successful: list[str], failed: list[dict[str, str]]) -> dict[str, Any]:
        ok = bool(successful) and not failed
        message = f"Clone completed: {len(successful)} succeeded"
        if failed:
            message += f", {len(failed)} failed"
        return {
            "ok": ok,
            "partial": bool(successful and failed),
            "message": message + ".",
            "successful": successful,
            "failed": failed,
        }

    def _load(self, host: str, protocol: str) -> dict[str, Any]:
        protocol = self._protocol(protocol)
        return get_ospf_routing(self.db, host) if protocol == "ospf" else get_eigrp_routing(self.db, host)

    @staticmethod
    def _protocol(protocol: str) -> str:
        value = str(protocol or "").strip().lower()
        if value not in {"ospf", "eigrp"}:
            raise ValueError("Protocol must be ospf or eigrp")
        return value

    @staticmethod
    def _process_key(protocol: str) -> str:
        return "process_id" if str(protocol).lower() == "ospf" else "as_number"

    @classmethod
    def _strip_database_state(cls, value: Any) -> Any:
        if isinstance(value, list):
            return [cls._strip_database_state(item) for item in value]
        if not isinstance(value, dict):
            return value
        return {key: cls._strip_database_state(item) for key, item in value.items() if key not in _DB_ONLY_KEYS}
