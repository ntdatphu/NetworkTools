"""Apply and verify Syslog commands through the shared device session registry."""

from __future__ import annotations

import logging
import re
from typing import Any, Callable

from features.devices.save_config_service import SaveConfigService

from .command_builder import build_cancel_commands, build_enable_commands
from .repository import SyslogRepository


SUPPORTED_DEVICE_OS = {"ios", "ios_xe", "cisco_ios", "cisco_xe"}
CLI_ERROR_PATTERN = (
    r"%\s*(?:Invalid input|Incomplete command|Ambiguous command|"
    r"Unknown command|Error)\b"
)
CLI_ERROR_RE = re.compile(CLI_ERROR_PATTERN, re.IGNORECASE)
_INTERFACE_ALIASES = {
    "et": "ethernet",
    "eth": "ethernet",
    "fa": "fastethernet",
    "fastethernet": "fastethernet",
    "gi": "gigabitethernet",
    "gig": "gigabitethernet",
    "gigabitethernet": "gigabitethernet",
    "te": "tengigabitethernet",
    "tengigabitethernet": "tengigabitethernet",
    "fo": "fortygigabitethernet",
    "fortygigabitethernet": "fortygigabitethernet",
    "hu": "hundredgige",
    "hundredgige": "hundredgige",
    "lo": "loopback",
    "loopback": "loopback",
    "po": "port-channel",
    "port-channel": "port-channel",
    "se": "serial",
    "serial": "serial",
    "tu": "tunnel",
    "tunnel": "tunnel",
    "vl": "vlan",
    "vlan": "vlan",
}
logger = logging.getLogger(__name__)


def _contains_cli_error(output: str) -> bool:
    """Return whether IOS/IOS-XE emitted a known command rejection marker."""
    return CLI_ERROR_RE.search(str(output or "")) is not None


def _cli_error_detail(output: str) -> str:
    for line in str(output or "").splitlines():
        if _contains_cli_error(line):
            return line.strip()
    return "Cisco IOS rejected the command."


def _normalized_line(value: str) -> str:
    return " ".join(str(value or "").strip().lower().split())


def _normalize_interface(value: str) -> str:
    compact = re.sub(r"\s+", "", str(value or "")).lower()
    match = re.fullmatch(r"([a-z-]+)(.*)", compact)
    if not match:
        return compact
    prefix, suffix = match.groups()
    return _INTERFACE_ALIASES.get(prefix, prefix) + suffix


class SyslogConfigurator:
    def __init__(self, repository: SyslogRepository, session_registry: Any | None = None) -> None:
        self.repository = repository
        self._session_registry = session_registry

    def configure(
        self,
        host: str,
        server_ip: str,
        protocol: str,
        port: int,
        source_interface: str = "",
    ) -> dict[str, object]:
        validation = self._validate_host(host)
        if validation is not None:
            return validation
        # A validated manual value is accepted only when database discovery failed.
        try:
            interface = source_interface.strip() or self.repository.source_interface(host)
        except Exception as exc:
            return self._database_read_failure(host, "source interface", exc)
        if not interface:
            return {
                "ok": False,
                "code": "source_interface_required",
                "stage": "validate",
                "message": (
                    f"Interface data for {host} is not synchronized. "
                    "Enter the Cisco source interface manually."
                ),
            }
        try:
            commands = build_enable_commands(server_ip, protocol, port, interface)
        except (TypeError, ValueError) as exc:
            return {"ok": False, "stage": "validate", "message": str(exc)}

        result = self._run_transaction(
            host,
            lambda connector: self._configure_transaction(
                host, connector, commands, server_ip, protocol, port, interface
            ),
        )
        try:
            self.repository.save_device_state(
                host,
                server_ip,
                protocol,
                port,
                interface,
                bool(result["ok"]),
                str(result["message"]),
            )
        except Exception as exc:
            return self._database_failure(host, result, exc)
        return result

    def cancel(self, host: str, server_ip: str, protocol: str, port: int) -> dict[str, object]:
        validation = self._validate_host(host)
        if validation is not None:
            return validation
        try:
            commands = build_cancel_commands(server_ip, protocol, port)
        except (TypeError, ValueError) as exc:
            return {"ok": False, "stage": "validate", "message": str(exc)}

        result = self._run_transaction(
            host,
            lambda connector: self._cancel_transaction(
                host, connector, commands, server_ip, protocol, port
            ),
        )
        try:
            if result["ok"]:
                self.repository.save_device_state(
                    host, server_ip, protocol, port, None, False, str(result["message"])
                )
            else:
                record_attempt = getattr(self.repository, "save_device_attempt", None)
                if callable(record_attempt):
                    record_attempt(host, server_ip, protocol, port, str(result["message"]))
        except Exception as exc:
            return self._database_failure(host, result, exc)
        return result

    def _validate_host(self, host: str) -> dict[str, object] | None:
        try:
            connected = self.repository.is_connected(host)
            device_os = self.repository.device_os(host).replace("-", "_").replace(" ", "_")
        except Exception as exc:
            return self._database_read_failure(host, "device metadata", exc)
        if not connected:
            return {"ok": False, "stage": "validate", "message": f"{host} is not connected."}
        if device_os not in SUPPORTED_DEVICE_OS:
            return {
                "ok": False,
                "stage": "validate",
                "message": f"Syslog configuration does not support OS '{device_os or 'unknown'}'.",
            }
        return None

    def _registry(self) -> Any:
        if self._session_registry is None:
            from core.sessions import device_session_registry

            self._session_registry = device_session_registry
        return self._session_registry

    def _run_transaction(
        self, host: str, operation: Callable[[Any], dict[str, object]]
    ) -> dict[str, object]:
        try:
            execution = self._registry().execute(host, operation, ensure_open=True)
        except Exception as exc:
            message = f"Could not execute the Syslog transaction for {host}: {exc}"
            logger.exception("Syslog session execution failed for %s", host)
            return {"ok": False, "stage": "session", "message": message}
        if not bool(execution.get("ok")):
            message = str(execution.get("message") or f"No CLI session for {host}.")
            logger.error("Syslog session failure for %s: %s", host, message)
            return {"ok": False, "stage": "session", "message": message}
        value = execution.get("value")
        if not isinstance(value, dict):
            message = f"Syslog transaction for {host} returned no result."
            logger.error(message)
            return {"ok": False, "stage": "internal", "message": message}
        return value

    def _configure_transaction(
        self,
        host: str,
        connector: Any,
        commands: list[str],
        server_ip: str,
        protocol: str,
        port: int,
        interface: str,
    ) -> dict[str, object]:
        try:
            connection = self._connection(connector)
        except Exception as exc:
            return self._failure(host, "session", f"No usable CLI connection for {host}: {exc}")
        try:
            if not self._interface_exists(connection, interface):
                return self._failure(
                    host,
                    "interface",
                    f"Source interface '{interface}' does not exist on {host}.",
                )
        except Exception as exc:
            return self._failure(
                host, "interface", f"Could not validate source interface on {host}: {exc}"
            )
        try:
            apply_output = self._send(connection, commands)
        except Exception as exc:
            return self._failure(host, "apply", f"Syslog apply failed for {host}: {exc}")
        try:
            running = self._show_logging(connection, startup=False)
        except Exception as exc:
            return self._failure(
                host, "verify_running", f"Could not verify running-config on {host}: {exc}"
            )
        try:
            verification = self._verify_destination(
                running, server_ip, protocol, port, expected=True
            )
            if verification is not None:
                return self._failure(host, "verify_running", verification)
            if not self._verify_source_interface(running, interface):
                return self._failure(
                    host,
                    "verify_running",
                    (
                        f"Running-config on {host} does not contain "
                        f"logging source-interface {interface}."
                    ),
                )
        except Exception as exc:
            return self._failure(
                host, "verify_running", f"Running-config verification failed for {host}: {exc}"
            )
        try:
            save_output = self._save(connector)
        except Exception as exc:
            return self._failure(
                host,
                "save",
                f"copy running-config startup-config failed for {host}: {exc}",
            )
        try:
            startup = self._show_logging(connection, startup=True)
        except Exception as exc:
            return self._failure(
                host, "verify_startup", f"Could not verify startup-config on {host}: {exc}"
            )
        try:
            persistence = self._verify_destination(
                startup, server_ip, protocol, port, expected=True
            )
            if persistence is not None:
                return self._failure(host, "verify_startup", persistence)
            if not self._verify_source_interface(startup, interface):
                return self._failure(
                    host,
                    "verify_startup",
                    (
                        f"Startup-config on {host} does not contain "
                        f"logging source-interface {interface}."
                    ),
                )
        except Exception as exc:
            return self._failure(
                host, "verify_startup", f"Startup-config verification failed for {host}: {exc}"
            )
        message = f"Syslog configuration applied, verified, and saved on {host}."
        logger.info(message)
        return {
            "ok": True,
            "stage": "complete",
            "message": message,
            "apply_output": apply_output,
            "save_output": save_output,
        }

    def _cancel_transaction(
        self,
        host: str,
        connector: Any,
        commands: list[str],
        server_ip: str,
        protocol: str,
        port: int,
    ) -> dict[str, object]:
        try:
            connection = self._connection(connector)
        except Exception as exc:
            return self._failure(host, "session", f"No usable CLI connection for {host}: {exc}")
        try:
            apply_output = self._send(connection, commands)
        except Exception as exc:
            return self._failure(host, "apply", f"Syslog cancellation failed for {host}: {exc}")
        try:
            running = self._show_logging(connection, startup=False)
        except Exception as exc:
            return self._failure(
                host, "verify_running", f"Could not verify running-config on {host}: {exc}"
            )
        try:
            verification = self._verify_destination(
                running, server_ip, protocol, port, expected=False
            )
            if verification is not None:
                return self._failure(host, "verify_running", verification)
        except Exception as exc:
            return self._failure(
                host, "verify_running", f"Running-config verification failed for {host}: {exc}"
            )
        try:
            save_output = self._save(connector)
        except Exception as exc:
            return self._failure(
                host,
                "save",
                f"copy running-config startup-config failed for {host}: {exc}",
            )
        try:
            startup = self._show_logging(connection, startup=True)
        except Exception as exc:
            return self._failure(
                host, "verify_startup", f"Could not verify startup-config on {host}: {exc}"
            )
        try:
            persistence = self._verify_destination(
                startup, server_ip, protocol, port, expected=False
            )
            if persistence is not None:
                return self._failure(host, "verify_startup", persistence)
        except Exception as exc:
            return self._failure(
                host, "verify_startup", f"Startup-config verification failed for {host}: {exc}"
            )
        message = f"Syslog destination removed, verified, and saved on {host}."
        logger.info(message)
        return {
            "ok": True,
            "stage": "complete",
            "message": message,
            "apply_output": apply_output,
            "save_output": save_output,
        }

    @staticmethod
    def _connection(connector: Any) -> Any:
        connection = getattr(connector, "connection", None)
        if connection is None:
            raise RuntimeError("The active device session has no CLI connection")
        return connection

    @staticmethod
    def _send(connection: Any, commands: list[str]) -> str:
        output = str(
            connection.send_config_set(
                commands,
                read_timeout=120,
                error_pattern=CLI_ERROR_PATTERN,
            )
            or ""
        )
        if _contains_cli_error(output):
            raise RuntimeError(
                f"Cisco CLI rejected the Syslog command: {_cli_error_detail(output)}"
            )
        return output

    @staticmethod
    def _show_logging(connection: Any, *, startup: bool) -> str:
        config = "startup-config" if startup else "running-config"
        output = str(connection.send_command(f"show {config} | include logging") or "")
        if _contains_cli_error(output):
            raise RuntimeError(f"Could not read {config}: {_cli_error_detail(output)}")
        return output

    @staticmethod
    def _save(connector: Any) -> str:
        output = SaveConfigService.copy_running_to_startup(connector)
        if _contains_cli_error(output):
            raise RuntimeError(
                "copy running-config startup-config failed: " + _cli_error_detail(output)
            )
        return output

    @staticmethod
    def _interface_exists(connection: Any, interface: str) -> bool:
        output = str(connection.send_command("show ip interface brief") or "")
        if _contains_cli_error(output):
            raise RuntimeError(
                "Could not validate source interface: " + _cli_error_detail(output)
            )
        expected = _normalize_interface(interface)
        for line in output.splitlines():
            fields = line.strip().split()
            if fields and _normalize_interface(fields[0]) == expected:
                return True
        return False

    @staticmethod
    def _verify_destination(
        output: str,
        server_ip: str,
        protocol: str,
        port: int,
        *,
        expected: bool,
    ) -> str | None:
        command = _normalized_line(
            f"logging host {server_ip} transport {protocol.lower()} port {int(port)}"
        )
        present = any(_normalized_line(line) == command for line in output.splitlines())
        if present == expected:
            return None
        config = "does not contain" if expected else "still contains"
        return f"Device configuration {config} '{command}'."

    @staticmethod
    def _verify_source_interface(output: str, interface: str) -> bool:
        prefix = "logging source-interface "
        expected = _normalize_interface(interface)
        for line in output.splitlines():
            normalized = _normalized_line(line)
            if normalized.startswith(prefix):
                configured = normalized[len(prefix):].split()[0]
                if _normalize_interface(configured) == expected:
                    return True
        return False

    @staticmethod
    def _failure(host: str, stage: str, message: str) -> dict[str, object]:
        logger.warning("Syslog transaction failed for %s at %s: %s", host, stage, message)
        return {"ok": False, "stage": stage, "message": message}

    @staticmethod
    def _database_failure(
        host: str, prior_result: dict[str, object], exc: Exception
    ) -> dict[str, object]:
        message = (
            f"{prior_result.get('message', 'Syslog device operation finished')} "
            f"Database state update failed for {host}: {exc}"
        )
        logger.exception("Syslog database state update failed for %s", host)
        return {
            **prior_result,
            "ok": False,
            "stage": "database",
            "message": message,
        }

    @staticmethod
    def _database_read_failure(
        host: str, data_name: str, exc: Exception
    ) -> dict[str, object]:
        message = f"Could not read Syslog {data_name} for {host} from the database: {exc}"
        logger.exception("Syslog database read failed for %s", host)
        return {"ok": False, "stage": "database", "message": message}


__all__ = ["SyslogConfigurator", "_contains_cli_error"]
