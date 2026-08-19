from __future__ import annotations

from typing import Any


_ERROR_MARKERS = (
    "% invalid input",
    "% incomplete command",
    "% ambiguous command",
    "% authorization failed",
    "command rejected",
)


def _has_rejected_command(output: str) -> bool:
    """Detect IOS errors, allowing the fixed-dot1q capability probe.

    Some IOS switches only support 802.1Q and reject the explicit
    ``switchport trunk encapsulation dot1q`` command even though the following
    ``switchport mode trunk`` is valid. Flexible-encapsulation switches need
    that exact command to move away from Auto. Only suppress the former error
    when the echoed command is present; all other CLI errors remain fatal.
    """
    lines = str(output or "").splitlines()
    for index, line in enumerate(lines):
        normalized = line.lower()
        if not any(marker in normalized for marker in _ERROR_MARKERS):
            continue
        context = "\n".join(lines[max(0, index - 3) : index + 1]).lower()
        if (
            "% invalid input" in normalized
            and "switchport trunk encapsulation dot1q" in context
        ):
            continue
        return True
    return False


def apply_commands(connector: Any, commands: list[str]) -> str:
    connection = getattr(connector, "connection", None)
    if connection is None:
        raise RuntimeError("The active device session is unavailable")
    output = str(
        connection.send_config_set(commands, read_timeout=120, cmd_verify=False)
    )
    if _has_rejected_command(output):
        raise RuntimeError(output.strip() or "The switch rejected the configuration")
    return output
