"""Prompt-delimited Cisco running-configuration collection."""

from __future__ import annotations

import re
import time
from typing import Any


CONFIG_PROMPT_RE = re.compile(r"(?m)^[^\r\n]*\(config(?:-[^)]+)?\)#[ \t]*$")
PROMPT_NOISE_RE = re.compile(r"(?:\x00|\^@)+")


class RunningConfigCollector:
    """Read CLI chunks until the configuration prompt is received in full."""

    def __init__(
        self,
        connection: Any,
        *,
        read_timeout: float = 15.0,
        poll_interval: float = 0.02,
    ) -> None:
        self.connection = connection
        self.read_timeout = max(0.1, float(read_timeout))
        self.poll_interval = max(0.0, float(poll_interval))

    def collect(self) -> str:
        self._ensure_configuration_mode()
        prompt = self._clean_prompt(self.connection.find_prompt())
        if not CONFIG_PROMPT_RE.fullmatch(prompt):
            raise RuntimeError(f"Expected a configuration prompt, received: {prompt or '<empty>'}")
        self._send_and_wait_for_prompt("do terminal length 0", prompt)
        output = self._send_and_wait_for_prompt("do show running-config", prompt)
        return self._clean_output(output, "do show running-config", prompt)

    def _ensure_configuration_mode(self) -> None:
        prompt = self._clean_prompt(self.connection.find_prompt())
        if CONFIG_PROMPT_RE.fullmatch(prompt):
            return
        if hasattr(self.connection, "check_enable_mode") and not self.connection.check_enable_mode():
            self.connection.enable()
        if not self.connection.check_config_mode():
            self.connection.config_mode()
        if not CONFIG_PROMPT_RE.fullmatch(
            self._clean_prompt(self.connection.find_prompt())
        ):
            raise RuntimeError("Could not enter Cisco configuration mode")

    def _send_and_wait_for_prompt(self, command: str, prompt: str) -> str:
        self.connection.clear_buffer()
        self.connection.write_channel(command + self.connection.RETURN)
        chunks: list[str] = []
        deadline = time.monotonic() + self.read_timeout
        while True:
            chunk = self.connection.read_channel()
            if chunk:
                chunks.append(str(chunk))
                buffer = "".join(chunks).replace("\r\n", "\n").replace("\r", "\n")
                if self._ends_with_prompt(buffer, prompt):
                    return buffer
            elif hasattr(self.connection, "is_alive"):
                state = self.connection.is_alive()
                if isinstance(state, dict) and not bool(state.get("is_alive")):
                    raise ConnectionError("Device connection closed before the configuration prompt returned")
            if time.monotonic() >= deadline:
                raise TimeoutError(
                    f"Timed out after {self.read_timeout:g}s waiting for the prompt "
                    f"after: {command}"
                )
            if not chunk and self.poll_interval:
                time.sleep(self.poll_interval)

    @staticmethod
    def _clean_prompt(value: Any) -> str:
        return PROMPT_NOISE_RE.sub("", str(value or "")).strip()

    @classmethod
    def _ends_with_prompt(cls, output: str, prompt: str) -> bool:
        lines = str(output or "").split("\n")
        last_line = next((line for line in reversed(lines) if line.strip()), "")
        return cls._clean_prompt(last_line) == cls._clean_prompt(prompt)

    @classmethod
    def _clean_output(cls, output: str, command: str, prompt: str) -> str:
        lines = str(output or "").replace("\r\n", "\n").replace("\r", "\n").split("\n")
        if lines and lines[0].strip() == command:
            lines.pop(0)
        while lines and not lines[-1].strip():
            lines.pop()
        if lines and cls._clean_prompt(lines[-1]) == cls._clean_prompt(prompt):
            lines.pop()
        return "\n".join(lines).strip("\n") + "\n"
