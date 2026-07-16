from __future__ import annotations

import re
from collections.abc import Callable

from .types import PacketSummary


_COMPARISON = re.compile(
    r"^(ip\.addr|ip\.src|ip\.dst|tcp\.port|udp\.port)\s*==\s*([^\s]+)$",
    re.IGNORECASE,
)
_PROTOCOLS = {
    "arp",
    "dns",
    "http",
    "icmp",
    "icmpv6",
    "ospf",
    "ssh",
    "tcp",
    "tls",
    "udp",
}


def build_packet_predicate(expression: str) -> Callable[[PacketSummary], bool]:
    text = str(expression or "").strip()
    if not text:
        return lambda _packet: True

    lowered = text.casefold()
    if lowered in _PROTOCOLS:
        return lambda packet: packet.protocol.casefold() == lowered

    match = _COMPARISON.fullmatch(text)
    if not match:
        raise ValueError(
            "Supported filters: tcp, udp, arp, ip.addr == 192.0.2.1, "
            "tcp.port == 22."
        )

    field, raw_value = match.groups()
    field = field.casefold()
    if field == "ip.addr":
        return lambda packet: raw_value in {packet.src_ip, packet.dst_ip}
    if field == "ip.src":
        return lambda packet: packet.src_ip == raw_value
    if field == "ip.dst":
        return lambda packet: packet.dst_ip == raw_value

    try:
        port = int(raw_value)
    except ValueError as exc:
        raise ValueError("Port must be a number from 0 to 65535.") from exc
    if not 0 <= port <= 65535:
        raise ValueError("Port must be a number from 0 to 65535.")

    protocol = field.split(".", 1)[0]
    return lambda packet: (
        packet.transport_protocol.casefold() == protocol
        and port in {packet.src_port, packet.dst_port}
    )
