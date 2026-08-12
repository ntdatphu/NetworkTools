"""Safe OpenSSH launch arguments for an interactive terminal child."""

from __future__ import annotations

import ipaddress
import re
import unicodedata
from dataclasses import dataclass
from typing import Any


USERNAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$")
HOST_LABEL_RE = re.compile(r"^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?$")


class TerminalLaunchError(ValueError):
    """Raised when inventory metadata cannot produce a safe launch."""


@dataclass(frozen=True, slots=True)
class OpenSshCommand:
    """Executable and argument list passed after Alacritty's ``-e`` flag."""

    program: str
    arguments: tuple[str, ...]


def sanitize_display_text(value: Any, *, fallback: str, limit: int = 80) -> str:
    """Remove control characters and bound untrusted window metadata."""
    cleaned = "".join(
        " " if str(character).isspace() else str(character)
        for character in str(value or "")
        if not unicodedata.category(character).startswith("C")
    )
    cleaned = " ".join(cleaned.split()).strip()
    return (cleaned or fallback)[:limit]


def validate_host(value: Any) -> str:
    """Return a validated IP literal or conservative DNS hostname."""
    host = str(value or "").strip()
    if not host or len(host) > 253 or host.startswith("-"):
        raise TerminalLaunchError("The terminal host is missing or invalid.")
    if any(character.isspace() or ord(character) < 32 for character in host):
        raise TerminalLaunchError("The terminal host contains unsafe characters.")
    try:
        ipaddress.ip_address(host)
        return host
    except ValueError:
        pass
    if not all(HOST_LABEL_RE.fullmatch(label) for label in host.rstrip(".").split(".")):
        raise TerminalLaunchError("The terminal host is not a valid IP address or hostname.")
    return host


def validate_username(value: Any) -> str:
    """Return a conservative OpenSSH username suitable for ``user@host``."""
    username = str(value or "").strip()
    if not USERNAME_RE.fullmatch(username):
        raise TerminalLaunchError(
            "The SSH username is missing or contains unsupported characters."
        )
    return username


def validate_port(value: Any) -> int:
    """Return a TCP port in the user-addressable range."""
    try:
        port = int(value)
    except (TypeError, ValueError) as exc:
        raise TerminalLaunchError("The SSH port is invalid.") from exc
    if not 1 <= port <= 65535:
        raise TerminalLaunchError("The SSH port must be between 1 and 65535.")
    return port


def build_openssh_command(device: dict[str, Any]) -> OpenSshCommand:
    """Build an argument-only OpenSSH command without copying credentials."""
    method = str(device.get("method") or "ssh").strip().lower()
    if method != "ssh":
        raise TerminalLaunchError(
            "NetworkTools Terminal currently supports managed OpenSSH sessions only."
        )
    host = validate_host(device.get("host"))
    username = validate_username(device.get("username"))
    port = validate_port(device.get("port") or 22)
    return OpenSshCommand(
        program="ssh",
        arguments=("-p", str(port), f"{username}@{host}"),
    )

