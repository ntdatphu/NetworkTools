from __future__ import annotations

from typing import Any


_ERROR_MARKERS = ("% invalid input", "% incomplete command", "% ambiguous command")


def apply_commands(connector: Any, commands: list[str]) -> str:
    connection = getattr(connector, "connection", None)
    if connection is None:
        raise RuntimeError("The active device session is unavailable")
    output = str(
        connection.send_config_set(commands, read_timeout=120, cmd_verify=False)
    )
    normalized = output.lower()
    if any(marker in normalized for marker in _ERROR_MARKERS):
        raise RuntimeError(output.strip() or "The switch rejected the configuration")
    return output
