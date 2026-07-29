"""Render Cisco IOS CLI for router-interface desired state."""

from __future__ import annotations

import re
from typing import Any


def _enabled(value: Any) -> bool:
    return bool(int(value or 0))


def _has_bit(action_cfg: Any, index_from_right: int) -> bool:
    bits = str(action_cfg or "")
    if not bits:
        return True
    position = len(bits) - 1 - index_from_right
    return 0 <= position < len(bits) and bits[position] == "1"


def _append_toggle(commands: list[str], enabled: Any, command: str) -> None:
    commands.append(command if _enabled(enabled) else f"no {command}")


def _cleanup_l3(profile: dict[str, Any]) -> list[str]:
    commands: list[str] = []
    if profile.get("secondary_ip") and profile.get("secondary_mask"):
        commands.append(
            f"no ip address {profile['secondary_ip']} {profile['secondary_mask']} secondary"
        )
    commands.extend(
        [
            "default mtu",
            "default bandwidth",
            "default delay",
            "default speed",
            "default duplex",
            "negotiation auto",
            "ip proxy-arp",
            "ip unreachables",
            "no ip directed-broadcast",
        ]
    )
    return commands


def _cleanup_tunnel(_profile: dict[str, Any]) -> list[str]:
    return [
        "no tunnel protection ipsec profile",
        "no keepalive",
        "no tunnel key",
        "no tunnel destination",
        "no tunnel source",
    ]


def _cleanup_wan(_profile: dict[str, Any]) -> list[str]:
    return [
        "default encapsulation",
        "no ppp authentication",
        "no ppp pap sent-username",
        "no ppp chap hostname",
        "no ppp chap password",
        "no pppoe enable group global",
        "no pppoe-client dial-pool-number",
        "no clock rate",
        "no frame-relay lmi-type",
    ]


def _render_l3(profile: dict[str, Any]) -> list[str]:
    commands: list[str] = []
    bits = profile.get("action_Cfg")
    if _has_bit(bits, 0):
        if profile.get("secondary_ip") and profile.get("secondary_mask"):
            commands.append(
                f"ip address {profile['secondary_ip']} {profile['secondary_mask']} secondary"
            )
    if profile.get("mtu"):
        commands.append(f"mtu {profile['mtu']}")
    if profile.get("bandwidth"):
        commands.append(f"bandwidth {profile['bandwidth']}")
    if profile.get("delay"):
        commands.append(f"delay {profile['delay']}")
    if _has_bit(bits, 4):
        speed = str(profile.get("speed") or "auto")
        commands.append("speed auto" if speed == "auto" else f"speed {speed}")
    if _has_bit(bits, 3):
        duplex = str(profile.get("duplex") or "auto")
        commands.append("duplex auto" if duplex == "auto" else f"duplex {duplex}")
    if _has_bit(bits, 2):
        commands.append("negotiation auto" if _enabled(profile.get("negotiation")) else "no negotiation auto")
    if _has_bit(bits, 1):
        _append_toggle(commands, profile.get("proxy_arp"), "ip proxy-arp")
        _append_toggle(commands, profile.get("unreachables"), "ip unreachables")
        _append_toggle(
            commands, profile.get("directed_broadcast"), "ip directed-broadcast"
        )
    return commands


def _render_tunnel(profile: dict[str, Any]) -> list[str]:
    mode_commands = {
        "gre": "tunnel mode gre ip",
        "ipip": "tunnel mode ipip",
        "ipsec": "tunnel mode ipsec ipv4",
        "gre-ipsec": "tunnel mode gre ip",
    }
    commands = [
        mode_commands.get(str(profile.get("tunnel_mode") or "gre"), "tunnel mode gre ip"),
        f"tunnel source {profile['tunnel_src']}",
        f"tunnel destination {profile['tunnel_dst']}",
    ]
    if profile.get("tunnel_key") is not None:
        commands.append(f"tunnel key {profile['tunnel_key']}")
    if profile.get("keepalive_sec"):
        retry = profile.get("keepalive_retry")
        commands.append(
            f"keepalive {profile['keepalive_sec']}"
            + (f" {retry}" if retry else "")
        )
    if profile.get("ipsec_profile"):
        commands.append(f"tunnel protection ipsec profile {profile['ipsec_profile']}")
    return commands


def _render_wan(profile: dict[str, Any]) -> list[str]:
    commands: list[str] = []
    encapsulation = str(profile.get("encap_type") or "none")
    if encapsulation in {"hdlc", "ppp", "frame-relay"}:
        commands.append(f"encapsulation {encapsulation}")
    if encapsulation == "pppoe":
        commands.append("pppoe enable group global")
        if profile.get("pppoe_dialer_pool"):
            commands.append(
                f"pppoe-client dial-pool-number {profile['pppoe_dialer_pool']}"
            )
    if profile.get("ppp_auth"):
        commands.append(f"ppp authentication {profile['ppp_auth']}")
    if profile.get("ppp_username") and profile.get("ppp_password"):
        if str(profile.get("ppp_auth") or "") == "pap":
            commands.append(
                "ppp pap sent-username "
                f"{profile['ppp_username']} password 0 {profile['ppp_password']}"
            )
        else:
            commands.extend(
                [
                    f"ppp chap hostname {profile['ppp_username']}",
                    f"ppp chap password 0 {profile['ppp_password']}",
                ]
            )
    if profile.get("clock_rate"):
        commands.append(f"clock rate {profile['clock_rate']}")
    if profile.get("lmi_type"):
        commands.append(f"frame-relay lmi-type {profile['lmi_type']}")
    return commands


_CLEANUP_RENDERERS = {
    "l3": _cleanup_l3,
    "tunnel": _cleanup_tunnel,
    "wan": _cleanup_wan,
}
_PROFILE_RENDERERS = {
    "l3": _render_l3,
    "tunnel": _render_tunnel,
    "wan": _render_wan,
}


def render_interface_commands(task: dict[str, Any]) -> list[str]:
    """Render one interface task without transport or database side effects."""
    interface = task["interface"]
    name = str(interface.get("interface_name") or "").strip()
    if not name:
        return []
    commands = [f"interface {name}"]
    if task.get("action") == "remove":
        commands.extend(["no ip address", "no description", "shutdown", "exit"])
        return commands

    for kind, profile in task.get("removed_profiles", {}).items():
        cleanup = _CLEANUP_RENDERERS.get(kind)
        if cleanup:
            commands.extend(cleanup(profile))

    description = str(interface.get("description") or "").strip()
    commands.append(f"description {description}" if description else "no description")
    if interface.get("ip_address") and interface.get("subnet_mask"):
        commands.append(
            f"ip address {interface['ip_address']} {interface['subnet_mask']}"
        )
    else:
        commands.append("no ip address")

    kind = task.get("profile_kind")
    profile = task.get("profile")
    renderer = _PROFILE_RENDERERS.get(str(kind))
    if renderer and isinstance(profile, dict):
        commands.extend(renderer(profile))
    commands.append("shutdown" if _enabled(interface.get("shutdown")) else "no shutdown")
    commands.append("exit")
    return commands


def redact_interface_commands(commands: list[str]) -> list[str]:
    """Hide PPP secrets while retaining a useful preview."""
    redacted: list[str] = []
    for command in commands:
        if command.startswith("ppp pap sent-username ") and " password " in command:
            redacted.append(command.split(" password ", 1)[0] + " password <redacted>")
        elif command.startswith("ppp chap password "):
            redacted.append("ppp chap password <redacted>")
        else:
            redacted.append(command)
    return redacted


def redact_interface_output(output: str) -> str:
    """Remove PPP passwords that a CLI server may echo in transport output."""
    text = re.sub(
        r"(?im)(ppp\s+pap\s+sent-username\s+\S+\s+password)(?:\s+\d+)?\s+\S+",
        r"\1 <redacted>",
        str(output or ""),
    )
    return re.sub(
        r"(?im)(ppp\s+chap\s+password)(?:\s+\d+)?\s+\S+",
        r"\1 <redacted>",
        text,
    )


__all__ = [
    "redact_interface_commands",
    "redact_interface_output",
    "render_interface_commands",
]
