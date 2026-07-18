from __future__ import annotations

from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from typing import Any


SEVERITY_NAMES = (
    "emergency", "alert", "critical", "error",
    "warning", "notice", "informational", "debug",
)


@dataclass(slots=True)
class SyslogMessage:
    source_ip: str
    severity: int
    message: str
    raw_message: str
    protocol: str
    device_host: str = ""
    device_time: str | None = None
    received_at: str = ""
    facility: str | None = None
    mnemonic: str | None = None
    parse_status: str = "parsed"

    def __post_init__(self) -> None:
        if not 0 <= int(self.severity) <= 7:
            self.severity = 6
        if not self.received_at:
            self.received_at = datetime.now(timezone.utc).isoformat(timespec="milliseconds")
        self.protocol = self.protocol.lower()

    def to_dict(self) -> dict[str, Any]:
        row = asdict(self)
        row["severity_name"] = SEVERITY_NAMES[self.severity]
        return row


@dataclass(slots=True, frozen=True)
class ListenerConfig:
    bind_ip: str
    advertised_ip: str
    port: int
    protocol: str
    max_message_bytes: int = 16 * 1024
    max_tcp_clients: int = 64

