"""Thin QML facade for terminal, session, and backup operations."""

from __future__ import annotations

import importlib.util
import sys
from typing import Any

from PyQt6.QtCore import QObject, pyqtSignal, pyqtSlot

from core.app_paths import APP_DIR
from core.tasks import AsyncTaskCoordinator
from features.devices import DeviceLoginService, DeviceRepository, DeviceService
from infrastructure.network.ping import ping_host
from infrastructure.network.session_registry import DeviceSessionRegistry
from infrastructure.system.process_launcher import open_terminal

NETWORK_TASK_TIMEOUT_SECONDS = 15
RUNTIME_MODULES = (
    "PyQt6", "psutil", "netmiko", "paramiko", "ncclient", "nornir",
    "nornir_netmiko", "requests", "urllib3", "jinja2", "yaml", "pyshark",
    "scapy", "napalm", "dulwich",
)
_default_repository = DeviceRepository()
device_login_service = DeviceLoginService(_default_repository)
device_service = DeviceService(_default_repository)
device_session_registry = DeviceSessionRegistry(device_login_service.load)
InfrastructureSessionRegistry = DeviceSessionRegistry

class TerminalHelper(QObject):
    taskStarted = pyqtSignal(str)
    taskProgress = pyqtSignal(str)
    taskFinished = pyqtSignal(bool, str)
    connectHostFinished = pyqtSignal(str, bool, str)
    deviceSessionFinished = pyqtSignal(str, bool, str)
    deviceSessionClosed = pyqtSignal(str)
    deviceCommandFinished = pyqtSignal(str, str, bool, str, str)
    runningConfigFinished = pyqtSignal(str, bool, str)
    manualSyncPreviewFinished = pyqtSignal(str, bool, str, object)

    def __init__(
        self,
        parent: QObject | None = None,
        config_backup_service: Any | None = None,
        config_sync_service: Any | None = None,
        task_coordinator: AsyncTaskCoordinator | None = None,
        session_registry: InfrastructureSessionRegistry | None = None,
        injected_device_service: DeviceService | None = None,
        injected_login_service: DeviceLoginService | None = None,
        bootstrap_report: dict[str, Any] | None = None,
    ) -> None:
        """Initialize task tracking and the versioned config-backup service."""
        super().__init__(parent)
        self._background_tasks: dict[str, dict[str, Any]] = {}
        self._task_coordinator = task_coordinator or AsyncTaskCoordinator(self)
        self._session_registry = session_registry or device_session_registry
        self._device_service = injected_device_service or device_service
        self._device_login_service = injected_login_service or device_login_service
        self._bootstrap_report = bootstrap_report or {
            "ok": True,
            "statusText": "SYSTEM READY",
            "message": "Python runtime is ready.",
        }
        if config_backup_service is None:
            from features.config_backup import ConfigBackupService

            config_backup_service = ConfigBackupService(APP_DIR / "backup")
        self._config_backup_service = config_backup_service
        if config_sync_service is None:
            from features.config_sync import ConfigSyncService
            from infrastructure.database.paths import DEVICE_NETWORK_DB

            config_sync_service = ConfigSyncService(
                DEVICE_NETWORK_DB,
                self._device_login_service.repository.get_role,
            )
        self._config_sync_service = config_sync_service

    def _commit_and_sync_snapshot(
        self,
        host: str,
        snapshot: dict[str, Any],
        sync_mode: str = "automatic",
    ) -> tuple[dict[str, Any], dict[str, Any]]:
        """Commit first, then apply the role/change-aware router sync policy."""
        running_config = str(snapshot.get("running_config") or "")
        backup_result = self._config_backup_service.save_snapshot(host, running_config)
        if not bool(backup_result.get("ok")):
            return backup_result, {
                "ok": False,
                "attempted": False,
                "skipped": True,
                "reason": "backup-failed",
                "message": "Configuration was not synchronized because its backup failed.",
                "summary": {},
            }
        sync_args = (
            host,
            running_config,
            str(snapshot.get("interface_brief") or ""),
            backup_result,
        )
        if sync_mode == "preview" and hasattr(
            self._config_sync_service, "preview_manual_snapshot"
        ):
            sync_result = self._config_sync_service.preview_manual_snapshot(*sync_args)
        elif sync_mode in {"safe", "force_device_state"} and hasattr(
            self._config_sync_service, "sync_manual_snapshot"
        ):
            sync_result = self._config_sync_service.sync_manual_snapshot(
                *sync_args, mode=sync_mode
            )
        else:
            sync_result = self._config_sync_service.sync_committed_snapshot(*sync_args)
        return backup_result, sync_result

    def _start_background_task(
        self,
        task_key: str,
        kind: str,
        host: str,
        start_message: str,
        callback: Any,
        metadata: dict[str, Any] | None = None,
    ) -> bool:
        if task_key in self._background_tasks:
            message = f"A {kind.replace('-', ' ')} task is already running for {host}."
            self.taskFinished.emit(False, message)
            return False

        self._background_tasks[task_key] = {
            "kind": kind,
            "host": host,
            "metadata": metadata or {},
        }

        started = self._task_coordinator.start(
            task_key,
            start_message,
            callback,
            on_started=self._relay_task_started,
            on_progress=self._relay_task_progress,
            on_finished=self._handle_background_task_finished,
        )
        if not started:
            self._background_tasks.pop(task_key, None)
        return started

    @pyqtSlot(str)
    def _relay_task_started(self, message: str) -> None:
        self.taskStarted.emit(message)

    @pyqtSlot(str)
    def _relay_task_progress(self, message: str) -> None:
        self.taskProgress.emit(message)

    @pyqtSlot(str, bool, str, object)
    def _handle_background_task_finished(self, task_key: str, ok: bool, message: str, result: object) -> None:
        entry = self._background_tasks.pop(task_key, {})
        kind = str(entry.get("kind") or "")
        host = str(entry.get("host") or "")
        metadata = entry.get("metadata") if isinstance(entry.get("metadata"), dict) else {}

        if kind == "connect-host":
            self.connectHostFinished.emit(host, ok, message)
        elif kind == "open-session":
            self.deviceSessionFinished.emit(host, ok, message)
        elif kind == "device-command":
            command = str(metadata.get("command") or "")
            output = str(result.get("output") or "") if isinstance(result, dict) else ""
            self.deviceCommandFinished.emit(host, command, ok, message, output)
        elif kind == "running-config":
            self.runningConfigFinished.emit(host, ok, message)
        elif kind == "manual-sync-preview":
            sync = result.get("sync", {}) if isinstance(result, dict) else {}
            summary = sync.get("summary", {}) if isinstance(sync, dict) else {}
            self.manualSyncPreviewFinished.emit(host, ok, message, summary)

        self.taskFinished.emit(ok, message)

    @pyqtSlot()
    def openTerminal(self) -> None:
        open_terminal(APP_DIR)

    @pyqtSlot(str, result="QVariant")
    def pingHost(self, ip: str) -> dict[str, Any]:
        ip = (ip or "").strip()
        if not ip:
            return {"ok": False, "severity": "warning", "message": "Ping failed: host is empty."}
        result = ping_host(APP_DIR, ip)
        return result

    @pyqtSlot(result="QVariant")
    def ensurePythonLoginDeps(self) -> dict[str, Any]:
        missing = [name for name in RUNTIME_MODULES if importlib.util.find_spec(name) is None]
        if missing:
            return {
                "ok": False,
                "statusText": f"MISSING: {len(missing)}",
                "message": "Missing Python packages: " + ", ".join(missing),
            }
        return dict(self._bootstrap_report)

    @pyqtSlot(str, result="QVariant")
    def openDeviceSession(self, host: str) -> dict[str, Any]:
        return self._session_registry.open(host)

    @pyqtSlot(str, result=bool)
    def openDeviceSessionAsync(self, host: str) -> bool:
        host = (host or "").strip()
        if not host:
            message = "Open session failed: host is empty."
            self.deviceSessionFinished.emit("", False, message)
            self.taskFinished.emit(False, message)
            return False

        task_key = f"open-session:{host}"
        start_message = f"Opening CLI session to {host}..."

        def run_open_session(progress: Any) -> dict[str, Any]:
            progress(f"Connecting to {host} with SSH/Telnet...")
            return self._session_registry.open(host)

        return self._start_background_task(task_key, "open-session", host, start_message, run_open_session)

    @pyqtSlot(str, result="QVariant")
    def closeDeviceSession(self, host: str) -> dict[str, Any]:
        result = self._session_registry.close(host)
        reset_result = self._device_service.reset_to_waiting(host)
        if not bool(reset_result.get("ok")):
            print(f"[app] Error updating device to waiting on close: {reset_result.get('message')}")
            
        self.deviceSessionClosed.emit(host)
        return result

    @pyqtSlot(str, result=bool)
    def hasDeviceSession(self, host: str) -> bool:
        return self._session_registry.has_session(host)

    @pyqtSlot(str, str, result="QVariant")
    def runDeviceCommand(self, host: str, command: str) -> dict[str, Any]:
        host = (host or "").strip()
        command = (command or "").strip()
        if not host:
            return {"ok": False, "severity": "warning", "message": "Command failed: host is empty.", "output": ""}
        if not command:
            return {"ok": False, "severity": "warning", "message": "Command failed: command is empty.", "output": ""}

        connector = self._session_registry.get_connector(host)
        if connector is None:
            return {
                "ok": False,
                "severity": "error",
                "message": f"Command failed for {host}: no active tab session.",
                "output": "",
            }

        try:
            output = connector.send_command(command)
            if output is None:
                return {"ok": False, "severity": "error", "message": f"Command failed for {host}: no output returned.", "output": ""}
            return {"ok": True, "severity": "success", "message": f"Command completed for {host}.", "output": str(output)}
        except Exception as exc:
            print(f"[app] Command failed for {host}: {exc}", file=sys.stderr)
            return {"ok": False, "severity": "error", "message": f"Command failed for {host}: {exc}", "output": ""}

    @pyqtSlot(str, str, result=bool)
    def runDeviceCommandAsync(self, host: str, command: str) -> bool:
        host = (host or "").strip()
        command = (command or "").strip()
        if not host or not command:
            message = "Command failed: host or command is empty."
            self.deviceCommandFinished.emit(host, command, False, message, "")
            self.taskFinished.emit(False, message)
            return False

        task_key = f"device-command:{host}:{command}"
        start_message = f"Running command on {host}: {command}"

        def run_command(progress: Any) -> dict[str, Any]:
            progress(f"Waiting for device response from {host}...")
            return self.runDeviceCommand(host, command)

        return self._start_background_task(
            task_key,
            "device-command",
            host,
            start_message,
            run_command,
            {"command": command},
        )

    @pyqtSlot()
    def closeAllDeviceSessions(self) -> None:
        self._session_registry.close_all()

    def shutdown(self) -> None:
        """Stop background jobs and close reusable device sessions."""
        self._task_coordinator.shutdown()
        self.closeAllDeviceSessions()

    @pyqtSlot(str, result="QVariant")
    def saveRunningConfigBackup(self, host: str) -> dict[str, Any]:
        return self._save_running_config_backup(host, "automatic")

    @pyqtSlot(str, result="QVariant")
    def manualSyncSys(self, host: str) -> dict[str, Any]:
        return self._save_running_config_backup(host, "preview")

    @pyqtSlot(str, str, result="QVariant")
    def applyManualSyncSys(self, host: str, mode: str) -> dict[str, Any]:
        """Recollect and apply a previously previewed Sys sync decision."""
        normalized_mode = str(mode or "").strip().lower()
        if normalized_mode not in {"safe", "force_device_state"}:
            return {
                "ok": False,
                "severity": "error",
                "message": "Manual Sys mode must be safe or force_device_state.",
            }
        return self._save_running_config_backup(host, normalized_mode)

    def _save_running_config_backup(
        self, host: str, sync_mode: str
    ) -> dict[str, Any]:
        host = (host or "").strip()
        if not host:
            return {"ok": False, "severity": "warning", "message": "Get running-config failed: host is empty."}

        device = self._device_login_service.load(host)
        if device is None:
            return {"ok": False, "severity": "error", "message": f"Get running-config failed for {host}: device was not found in database."}
        if self._device_login_service.is_dev_device(device):
            return {"ok": False, "severity": "warning", "message": f"{host} is a dev-test host; no running-config can be collected."}

        connector = self._session_registry.get_connector(host)
        owns_connector = False
        if connector is None:
            method = str(device.get("method") or "").strip().lower()
            if method not in {"ssh", "telnet"}:
                return {
                    "ok": False,
                    "severity": "warning",
                    "message": f"Get running-config failed for {host}: {method.upper() or 'non-CLI'} is not supported.",
                }

            try:
                from infrastructure.network.device_connector import DeviceConnector

                connector = DeviceConnector(
                    device["host"],
                    method,
                    device["port"],
                    device["username"],
                    device["password"],
                    device_type=device["device_type"],
                    start_config_mode=False,
                    timeout=NETWORK_TASK_TIMEOUT_SECONDS,
                )
                owns_connector = True
                if not connector.connect():
                    reason = str(getattr(connector, "last_error", "") or "login failed")
                    return {"ok": False, "severity": "error", "message": f"Get running-config failed for {host}: {reason}."}
            except Exception as exc:
                print(f"[app] Get running-config failed for {host}: {exc}", file=sys.stderr)
                return {"ok": False, "severity": "error", "message": f"Get running-config failed for {host}: {exc}"}

        try:
            snapshot = connector.collect_running_config()
            ok = bool(snapshot.get("ok"))
            backup_result: dict[str, Any] = {}
            sync_result: dict[str, Any] = {}
            if ok:
                backup_result, sync_result = self._commit_and_sync_snapshot(
                    host, snapshot, sync_mode
                )
                ok = bool(backup_result.get("ok"))
            sync_summary = sync_result.get("summary", {}) or {}
            sync_text = (
                f" Synced {sync_summary.get('interfaces', 0)} interface(s)"
                f", {sync_summary.get('static_routes', 0)} static route(s)"
                f", {sync_summary.get('default_routes', 0)} default route(s)"
                f", {sync_summary.get('ospf_processes', 0)} OSPF process(es)"
                f" and {sync_summary.get('eigrp_processes', 0)} EIGRP process(es)."
                if sync_summary
                else ""
            )
            if ok and not bool(sync_result.get("ok", True)):
                return {
                    **backup_result,
                    "ok": True,
                    "severity": "warning",
                    "message": f"Running-config committed in backup/{host}/cfg, but DB sync failed: {sync_result.get('message')}.",
                    "sync": sync_result,
                }
            if ok:
                if sync_mode == "preview":
                    conflicts = list(sync_summary.get("conflicts") or [])
                    unsupported = int(sync_summary.get("unsupported_routes") or 0)
                    return {
                        **backup_result,
                        "ok": True,
                        "severity": "warning" if conflicts or unsupported else "info",
                        "message": (
                            "Manual Sys preview ready."
                            + sync_text
                            + (
                                " Pending conflicts: " + ", ".join(conflicts) + "."
                                if conflicts
                                else ""
                            )
                            + (
                                f" Unsupported routes: {unsupported}."
                                if unsupported
                                else ""
                            )
                        ),
                        "sync": sync_result,
                    }
                unchanged_text = (
                    " Configuration is unchanged; router DB sync was skipped."
                    if sync_result.get("reason") == "unchanged"
                    else ""
                )
                return {
                    **backup_result,
                    "ok": True,
                    "severity": "success",
                    "message": f"Running-config committed in backup/{host}/cfg.{sync_text}{unchanged_text}",
                    "sync": sync_result,
                }
            detail = str(backup_result.get("message") or "command returned no output")
            return {"ok": False, "severity": "error", "message": f"Get running-config failed for {host}: {detail}."}
        except Exception as exc:
            print(f"[app] Get running-config failed for {host}: {exc}", file=sys.stderr)
            return {"ok": False, "severity": "error", "message": f"Get running-config failed for {host}: {exc}"}
        finally:
            if owns_connector and connector is not None:
                connector.disconnect()

    @pyqtSlot(str, result=bool)
    def saveRunningConfigBackupAsync(self, host: str) -> bool:
        host = (host or "").strip()
        if not host:
            message = "Get running-config failed: host is empty."
            self.runningConfigFinished.emit("", False, message)
            self.taskFinished.emit(False, message)
            return False

        task_key = f"running-config:{host}"
        start_message = f"Getting running-config from {host}..."

        def run_running_config(progress: Any) -> dict[str, Any]:
            progress(f"Running output rcfg for {host}...")
            result = self.saveRunningConfigBackup(host)
            progress(f"Finished running-config task for {host}.")
            return result

        return self._start_background_task(task_key, "running-config", host, start_message, run_running_config)

    @pyqtSlot(str, result=bool)
    def manualSyncSysAsync(self, host: str) -> bool:
        host = (host or "").strip()
        if not host:
            self.runningConfigFinished.emit(host, False, "Manual Sys sync failed: host is empty.")
            return False
        task_key = f"manual-sys-sync:{host}"
        start_message = f"Manual Sys sync started for {host}..."

        def run_manual_sync(progress):
            progress(f"Collecting complete running-config from {host}...")
            result = self.manualSyncSys(host)
            progress(f"Manual Sys sync finished for {host}.")
            return result

        return self._start_background_task(
            task_key,
            "manual-sync-preview",
            host,
            start_message,
            run_manual_sync,
        )

    @pyqtSlot(str, str, result=bool)
    def applyManualSyncSysAsync(self, host: str, mode: str) -> bool:
        """Apply safe/force mode asynchronously after the preview decision."""
        host = (host or "").strip()
        normalized_mode = str(mode or "").strip().lower()
        if not host or normalized_mode not in {"safe", "force_device_state"}:
            self.runningConfigFinished.emit(
                host, False, "Manual Sys apply request is invalid."
            )
            return False
        task_key = f"manual-sys-apply:{host}:{normalized_mode}"

        def run_apply(progress: Any) -> dict[str, Any]:
            progress(f"Recollecting running-config from {host}...")
            result = self.applyManualSyncSys(host, normalized_mode)
            progress(f"Manual Sys {normalized_mode} finished for {host}.")
            return result

        return self._start_background_task(
            task_key,
            "running-config",
            host,
            f"Applying Manual Sys {normalized_mode} for {host}...",
            run_apply,
        )

    @pyqtSlot(str, result="QVariant")
    def connectHostAndSync(self, host: str) -> dict[str, Any]:
        host = (host or "").strip()
        if not host:
            print("[app] connectHostAndSync failed: host is empty.", file=sys.stderr)
            return {"ok": False, "severity": "warning", "message": "Connect failed: host is empty."}

        connector = None
        try:
            device = self._device_login_service.load(host)
            if device is None:
                print(f"[app] connectHostAndSync failed: device {host} was not found in database.", file=sys.stderr)
                return {"ok": False, "severity": "error", "message": f"Connect failed for {host}: device was not found in database."}
            if self._device_login_service.is_dev_device(device):
                self._device_service.update_flag(host, "success", 1)
                return {
                    "ok": True,
                    "severity": "info",
                    "message": f"{host} is a dev-test host; marked connected without SSH/Telnet login or device sync.",
                }

            from infrastructure.network.device_connector import DeviceConnector

            connector = DeviceConnector(
                device["host"],
                device["method"],
                device["port"],
                device["username"],
                device["password"],
                device_type=device["device_type"],
                start_config_mode=True,
                timeout=NETWORK_TASK_TIMEOUT_SECONDS,
            )

            if not connector.connect():
                self._device_service.update_flag(host, "success", -1)
                reason = str(getattr(connector, "last_error", "") or "login failed")
                print(f"[app] connectHostAndSync failed for {host}: {reason}.", file=sys.stderr)
                return {"ok": False, "severity": "error", "message": f"Connect failed for {host}: {reason}."}

            status_updated = self._device_service.update_flag(host, "success", 1)
            snapshot = connector.collect_running_config()
            backup_ok = bool(snapshot.get("ok"))
            sync_result: dict[str, Any] = {}
            if backup_ok:
                backup_result, sync_result = self._commit_and_sync_snapshot(host, snapshot)
                backup_ok = bool(backup_result.get("ok"))
            sync_summary = sync_result.get("summary", {}) or {}
            sync_text = (
                f" Synced {sync_summary.get('interfaces', 0)} interface(s)"
                f" and {sync_summary.get('ospf_processes', 0)} OSPF process(es)."
                if sync_summary
                else ""
            )

            if backup_ok and status_updated:
                if not bool(sync_result.get("ok", True)):
                    return {
                        "ok": True,
                        "severity": "warning",
                        "message": f"Connected {host}; running-config committed in backup/{host}/cfg, but DB sync failed: {sync_result.get('message')}.",
                        "sync": sync_result,
                    }
                return {"ok": True, "severity": "success", "message": f"Connected {host}; running-config committed in backup/{host}/cfg.{sync_text}", "sync": sync_result}
            if backup_ok:
                return {"ok": True, "severity": "warning", "message": f"Connected {host}; running-config committed, but database status was not updated.{sync_text}"}
            print(f"[app] connectHostAndSync warning: running-config backup failed for {host}.", file=sys.stderr)
            if not status_updated:
                return {"ok": True, "severity": "warning", "message": f"Connected {host}; running-config backup failed and database status was not updated."}
            return {"ok": True, "severity": "warning", "message": f"Connected {host}; running-config backup failed."}
        except Exception as exc:
            try:
                self._device_service.update_flag(host, "success", -1)
            except Exception:
                pass
            print(f"[app] connectHostAndSync failed for {host}: {exc}", file=sys.stderr)
            return {"ok": False, "severity": "error", "message": f"Connect failed for {host}: {exc}"}
        finally:
            if connector is not None:
                connector.disconnect()

    @pyqtSlot(str, result=bool)
    def connectHostAndSyncAsync(self, host: str) -> bool:
        host = (host or "").strip()
        if not host:
            message = "Connect failed: host is empty."
            self.connectHostFinished.emit("", False, message)
            self.taskFinished.emit(False, message)
            return False

        task_key = f"connect:{host}"
        start_message = f"Connecting to {host}..."

        def run_connect(progress: Any) -> dict[str, Any]:
            progress(f"Opening device connection to {host}...")
            result = self.connectHostAndSync(host)
            progress(f"Finished connection task for {host}.")
            return result

        return self._start_background_task(task_key, "connect-host", host, start_message, run_connect)

__all__ = ["TerminalHelper", "device_session_registry"]
