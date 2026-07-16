from __future__ import annotations

from dataclasses import dataclass
from enum import Enum


class CaptureState(str, Enum):
    IDLE = "idle"
    INITIALIZING = "initializing"
    STARTING = "starting"
    CAPTURING = "capturing"
    STOPPING = "stopping"
    ERROR = "error"


@dataclass(slots=True)
class PacketSummary:
    packet_no: int
    frame_number: int
    captured_at: str
    time_offset: float
    source: str
    destination: str
    protocol: str
    length: int
    info: str
    transport_protocol: str = ""
    src_mac: str = ""
    dst_mac: str = ""
    src_ip: str = ""
    dst_ip: str = ""
    src_port: int | None = None
    dst_port: int | None = None
    packet_id: int | None = None
    session_id: int | None = None
