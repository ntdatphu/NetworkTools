from __future__ import annotations


SEVERITY_WORDS = (
    "emergencies", "alerts", "critical", "errors",
    "warnings", "notifications", "informational", "debugging",
)


def build_enable_commands(server_ip: str, protocol: str, port: int,
                          source_interface: str, trap_severity: int = 4,
                          console_severity: int = 6, timestamps: bool = True) -> list[str]:
    protocol = protocol.lower()
    if protocol not in {"udp", "tcp"}:
        raise ValueError("Unsupported syslog transport")
    if not 1 <= port <= 65535:
        raise ValueError("Invalid syslog port")
    commands = [
        f"logging host {server_ip} transport {protocol} port {port}",
        f"logging trap {SEVERITY_WORDS[trap_severity]}",
        f"logging console {SEVERITY_WORDS[console_severity]}",
    ]
    if timestamps:
        commands.append("service timestamps log datetime msec")
    commands.append(f"logging source-interface {source_interface}")
    return commands


def build_cancel_commands(server_ip: str, protocol: str, port: int) -> list[str]:
    return [f"no logging host {server_ip} transport {protocol.lower()} port {port}"]

