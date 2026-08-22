from __future__ import annotations

import re
from typing import Any


def _interface_header(name: str) -> list[str]:
    return [f"interface {name}"]


def _is_port_channel(name: Any) -> bool:
    normalized = str(name or "").strip().lower().replace(" ", "")
    return bool(
        normalized.startswith(("port-channel", "portchannel"))
        or re.match(r"^po\d", normalized)
    )


def render_vlan(payload: dict[str, Any]) -> list[str]:
    commands: list[str] = []
    for vlan in payload["vlans"]:
        if vlan.get("action") == "remove":
            commands.append(f"no vlan {vlan['vlan_id']}")
            continue
        commands.append(f"vlan {vlan['vlan_id']}")
        if vlan["vlan_name"]:
            commands.append(f" name {vlan['vlan_name']}")
        commands.append(f" state {vlan['state']}")
        commands.append(" exit")
    return commands


def render_svi(payload: dict[str, Any]) -> list[str]:
    commands: list[str] = []
    if "ip_routing" in payload:
        commands.append("ip routing" if payload["ip_routing"] else "no ip routing")
    for item in payload.get("svis", []):
        vlan_id = int(item["vlan_id"])
        if item.get("action") == "remove":
            commands.append(f"no interface Vlan{vlan_id}")
            continue
        commands.append(f"interface Vlan{vlan_id}")
        if item.get("ip_address") and item.get("subnet_mask"):
            commands.append(
                f" ip address {item['ip_address']} {item['subnet_mask']}"
            )
        else:
            commands.append(" no ip address")
        commands.append(" shutdown" if item.get("shutdown") else " no shutdown")
        commands.append(" exit")
    return commands


def render_interfaces(payload: dict[str, Any]) -> list[str]:
    commands: list[str] = []
    for item in payload["interfaces"]:
        commands.extend(_interface_header(item["if_name"]))
        commands.append(
            f" description {item['description']}" if item["description"] else " no description"
        )
        commands.append(" shutdown" if item["admin_status"] == "down" else " no shutdown")
        # Port-channel is a logical interface. IOS rejects physical-link
        # negotiation commands such as ``speed auto`` and ``duplex auto`` on
        # it, which used to stop the entire Layer 2 push.
        if not _is_port_channel(item["if_name"]):
            commands.append(f" speed {item['speed']}")
            commands.append(f" duplex {item['duplex']}")
        commands.append(" switchport")
        if item["mode"] == "access":
            commands.extend(
                [" switchport mode access", f" switchport access vlan {item['access_vlan']}"]
            )
            if item["voice_vlan"] is not None:
                commands.append(f" switchport voice vlan {item['voice_vlan']}")
            else:
                commands.append(" no switchport voice vlan")
        elif item["mode"] == "trunk":
            # Set encapsulation before switching to trunk mode. IOS models
            # whose current encapsulation is Auto reject ``mode trunk`` until
            # this has been made explicit.
            commands.append(
                f" switchport trunk encapsulation {item['encapsulation']}"
            )
            commands.extend(
                [
                    " switchport mode trunk",
                    f" switchport trunk native vlan {item['native_vlan']}",
                    f" switchport trunk allowed vlan {item['allowed_vlans']}",
                ]
            )
        commands.append(" exit")
    for channel in payload["etherchannels"]:
        if channel.get("action") == "remove":
            for member in [
                value.strip()
                for value in channel["member_ports"].split(",")
                if value.strip()
            ]:
                commands.extend(
                    [
                        f"interface {member}",
                        " no channel-group",
                        " exit",
                    ]
                )
            commands.append(f"no interface Port-channel{channel['po_number']}")
            continue
        for member in [
            value.strip() for value in channel["member_ports"].split(",") if value.strip()
        ]:
            commands.extend(
                [
                    f"interface {member}",
                    f" channel-group {channel['po_number']} mode {channel['mode']}",
                    " exit",
                ]
            )
        commands.append(f"interface Port-channel{channel['po_number']}")
        commands.append(
            f" description {channel['description']}"
            if channel["description"]
            else " no description"
        )
        commands.append(" exit")
    return commands


def render_stp(payload: dict[str, Any]) -> list[str]:
    commands: list[str] = []
    global_rows = payload["global"]
    if global_rows:
        commands.append(f"spanning-tree mode {global_rows[0]['stp_mode']}")
    for item in global_rows:
        vlan_id = item["vlan_id"]
        if item["root_role"] in {"primary", "secondary"}:
            commands.append(f"spanning-tree vlan {vlan_id} root {item['root_role']}")
        else:
            commands.append(f"spanning-tree vlan {vlan_id} priority {item['priority']}")
    mapping = (
        ("portfast", "spanning-tree portfast"),
        ("bpduguard", "spanning-tree bpduguard enable"),
        ("bpdufilter", "spanning-tree bpdufilter enable"),
        ("root_guard", "spanning-tree guard root"),
        ("loop_guard", "spanning-tree guard loop"),
    )
    for item in payload["interfaces"]:
        commands.extend(_interface_header(item["if_name"]))
        for field, command in mapping:
            enabled_command = command
            if field == "portfast" and item.get("mode") == "trunk":
                enabled_command = "spanning-tree portfast trunk"
            commands.append(
                f" {enabled_command}"
                if item[field] == "enabled"
                else f" no {command}"
            )
        commands.append(" exit")
    return commands


def render_vtp(payload: dict[str, Any]) -> list[str]:
    rows = payload["vtp"]
    if not rows:
        return []
    first = rows[0]
    commands = [f"vtp domain {first['domain_name']}", f"vtp version {first['version']}"]
    vlan_mode = next((row["mode"] for row in rows if row["database_type"] == "vlan"), None)
    if vlan_mode:
        commands.append(f"vtp mode {vlan_mode}")
    commands.append("vtp pruning" if first["pruning"] else "no vtp pruning")
    return commands


def render_security(payload: dict[str, Any]) -> list[str]:
    commands: list[str] = []
    snooping_vlans = [str(row["vlan_id"]) for row in payload["vlans"] if row["dhcp_snooping"]]
    if snooping_vlans:
        commands.extend(["ip dhcp snooping", f"ip dhcp snooping vlan {','.join(snooping_vlans)}"])
    for item in payload["vlans"]:
        if not item["dhcp_snooping"]:
            commands.append(f"no ip dhcp snooping vlan {item['vlan_id']}")
    dai_vlans = [str(row["vlan_id"]) for row in payload["vlans"] if row["dai_enabled"]]
    if dai_vlans:
        commands.append(f"ip arp inspection vlan {','.join(dai_vlans)}")
    for item in payload["vlans"]:
        if not item["dai_enabled"]:
            commands.append(f"no ip arp inspection vlan {item['vlan_id']}")
    for name in payload["trust_ports"]:
        commands.extend(
            [
                f"interface {name}",
                " ip dhcp snooping trust",
                " ip arp inspection trust",
                " exit",
            ]
        )
    for item in payload["ports"]:
        commands.extend(_interface_header(item["if_name"]))
        if not item["enabled"]:
            commands.append(" no switchport port-security")
            commands.append(" exit")
            continue
        commands.extend(
            [
                " switchport port-security",
                f" switchport port-security maximum {item['max_mac']}",
                f" switchport port-security violation {item['violation']}",
            ]
        )
        if item["sticky"]:
            commands.append(" switchport port-security mac-address sticky")
        if item["aging_time"]:
            commands.extend(
                [
                    f" switchport port-security aging time {item['aging_time']}",
                    f" switchport port-security aging type {item['aging_type']}",
                ]
            )
        commands.append(" exit")
    for item in payload["static_macs"]:
        commands.append(
            f"mac address-table static {item['mac_addr']} vlan {item['vlan_id']} interface {item['if_name']}"
        )
    return commands


RENDERERS = {
    "vlan": render_vlan,
    "svi": render_svi,
    "interfaces": render_interfaces,
    "stp": render_stp,
    "vtp": render_vtp,
    "security": render_security,
}


def render_commands(module_name: str, payload: dict[str, Any]) -> list[str]:
    try:
        return RENDERERS[module_name](payload)
    except KeyError as exc:
        raise ValueError(f"Unsupported Layer 2 module: {module_name}") from exc
