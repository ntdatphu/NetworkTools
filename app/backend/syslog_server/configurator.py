"""Apply Syslog commands through the app's existing device session registry."""

from __future__ import annotations

from .command_builder import build_cancel_commands, build_enable_commands
from .repository import SyslogRepository


SUPPORTED_DEVICE_OS = {"ios", "ios_xe", "cisco_ios", "cisco_xe"}


class SyslogConfigurator:
    def __init__(self, repository: SyslogRepository) -> None:
        self.repository = repository

    def configure(self, host: str, server_ip: str, protocol: str, port: int) -> dict[str, object]:
        validation = self._validate_host(host)
        if validation is not None:
            return validation
        interface = self.repository.source_interface(host)
        if not interface:
            return {"ok": False, "message": f"No active interface on {host} has IP {host}."}
        commands = build_enable_commands(server_ip, protocol, port, interface)
        result = self._send(host, commands)
        self.repository.save_device_state(
            host, server_ip, protocol, port, interface, bool(result["ok"]), str(result["message"])
        )
        return result

    def cancel(self, host: str, server_ip: str, protocol: str, port: int) -> dict[str, object]:
        validation = self._validate_host(host)
        if validation is not None:
            return validation
        result = self._send(host, build_cancel_commands(server_ip, protocol, port))
        if result["ok"]:
            self.repository.save_device_state(host, server_ip, protocol, port, None, False, str(result["message"]))
        return result

    def _validate_host(self, host: str) -> dict[str, object] | None:
        if not self.repository.is_connected(host):
            return {"ok": False, "message": f"{host} is not connected."}
        device_os = self.repository.device_os(host).replace("-", "_").replace(" ", "_")
        if device_os not in SUPPORTED_DEVICE_OS:
            return {"ok": False, "message": f"Syslog configuration does not support OS '{device_os or 'unknown'}'."}
        return None

    @staticmethod
    def _send(host: str, commands: list[str]) -> dict[str, object]:
        try:
            from core.runtime import device_session_registry

            connector = device_session_registry.get_connector(host)
            if connector is None:
                opened = device_session_registry.open(host)
                if not opened.get("ok"):
                    return opened
                connector = device_session_registry.get_connector(host)
            connection = getattr(connector, "connection", None)
            if connection is None:
                return {"ok": False, "message": f"No CLI connection for {host}."}
            connection.send_config_set(commands)
            return {"ok": True, "message": f"Syslog configuration applied to {host}."}
        except Exception as exc:
            return {"ok": False, "message": f"Syslog configuration failed for {host}: {exc}"}
