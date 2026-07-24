"""Prompt-delimited Cisco running-configuration collection."""

from __future__ import annotations

import re
from typing import Any


CONFIG_PROMPT_RE = re.compile(r"(?m)^[^\r\n]*\(config(?:-[^)]+)?\)#[ \t]*$")


class RunningConfigCollector:
    """Read CLI chunks until the configuration prompt is received in full."""

    def __init__(self, connection: Any) -> None:
        self.connection = connection

    def collect(self) -> str:
        self._ensure_configuration_mode()
        prompt = str(self.connection.find_prompt()).strip()
        if not CONFIG_PROMPT_RE.fullmatch(prompt):
            raise RuntimeError(f"Expected a configuration prompt, received: {prompt or '<empty>'}")
        self._send_and_wait_for_prompt("do terminal length 0", prompt)
        output = self._send_and_wait_for_prompt("do show running-config", prompt)
        return self._clean_output(output, "do show running-config", prompt)

    def _ensure_configuration_mode(self) -> None:
        prompt = str(self.connection.find_prompt()).strip()
        if CONFIG_PROMPT_RE.fullmatch(prompt):
            return
        if hasattr(self.connection, "check_enable_mode") and not self.connection.check_enable_mode():
            self.connection.enable()
        if not self.connection.check_config_mode():
            self.connection.config_mode()
        if not CONFIG_PROMPT_RE.fullmatch(str(self.connection.find_prompt()).strip()):
            raise RuntimeError("Could not enter Cisco configuration mode")

    def _send_and_wait_for_prompt(self, command: str, prompt: str) -> str:
        self.connection.clear_buffer()
        self.connection.write_channel(command + self.connection.RETURN)
        chunks: list[str] = []
        while True:
            chunk = self.connection.read_channel()
            if chunk:
                chunks.append(str(chunk))
                buffer = "".join(chunks).replace("\r\n", "\n").replace("\r", "\n")
                if buffer.rstrip().endswith(prompt):
                    return buffer
            elif hasattr(self.connection, "is_alive"):
                state = self.connection.is_alive()
                if isinstance(state, dict) and not bool(state.get("is_alive")):
                    raise ConnectionError("Device connection closed before the configuration prompt returned")

    @staticmethod
    def _clean_output(output: str, command: str, prompt: str) -> str:
        lines = str(output or "").replace("\r\n", "\n").replace("\r", "\n").split("\n")
        if lines and lines[0].strip() == command:
            lines.pop(0)
        while lines and not lines[-1].strip():
            lines.pop()
        if lines and lines[-1].strip() == prompt:
            lines.pop()
        return "\n".join(lines).strip("\n") + "\n"
