from __future__ import annotations

import re
from datetime import datetime

from .models import SyslogMessage


PRI_RE = re.compile(r"^<(?P<pri>\d{1,3})>")
CISCO_RE = re.compile(
    r"%(?P<facility>[A-Z0-9_]+)-(?P<severity>[0-7])-(?P<mnemonic>[A-Z0-9_]+):\s*(?P<message>.*)",
    re.DOTALL,
)
RFC3164_RE = re.compile(
    r"^(?P<stamp>[A-Z][a-z]{2}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2}(?:\.\d+)?)\s+(?P<body>.*)$",
    re.DOTALL,
)
ISO_RE = re.compile(r"^(?P<stamp>\d{4}-\d{2}-\d{2}T\S+)\s+(?P<body>.*)$", re.DOTALL)


def _device_time(text: str) -> tuple[str | None, str]:
    match = ISO_RE.match(text)
    if match:
        stamp = match.group("stamp")
        try:
            return datetime.fromisoformat(stamp.replace("Z", "+00:00")).isoformat(), match.group("body")
        except ValueError:
            return None, text

    match = RFC3164_RE.match(text)
    if not match:
        return None, text
    stamp = match.group("stamp")
    year = datetime.now().year
    for fmt in ("%Y %b %d %H:%M:%S.%f", "%Y %b %d %H:%M:%S"):
        try:
            return datetime.strptime(f"{year} {stamp}", fmt).isoformat(), match.group("body")
        except ValueError:
            continue
    return None, text


def parse_message(data: bytes, source_ip: str, protocol: str) -> SyslogMessage:
    raw = data.decode("utf-8", errors="replace").replace("\x00", "").strip("\r\n ")
    text = raw
    severity = 6
    facility: str | None = None
    status = "raw"

    pri_match = PRI_RE.match(text)
    if pri_match:
        pri = min(int(pri_match.group("pri")), 191)
        severity = pri % 8
        facility = str(pri // 8)
        text = text[pri_match.end():].lstrip()
        status = "partial"

    device_time, text = _device_time(text)
    cisco = CISCO_RE.search(text)
    mnemonic: str | None = None
    message = text
    if cisco:
        facility = cisco.group("facility")
        severity = int(cisco.group("severity"))
        mnemonic = cisco.group("mnemonic")
        message = cisco.group("message").strip()
        status = "parsed"

    return SyslogMessage(
        source_ip=source_ip,
        severity=severity,
        facility=facility,
        mnemonic=mnemonic,
        message=message or raw,
        raw_message=raw,
        protocol=protocol,
        device_time=device_time,
        parse_status=status,
    )

