from typing import Optional, Tuple


def detect_os_from_version(version_output: str) -> Optional[str]:
    text = (version_output or "").lower()
    if not text:
        return None
    if "ios xe" in text:
        return "IOS-XE"
    if "cisco ios" in text or "ios software" in text:
        return "IOS"
    if "nx-os" in text:
        return "NX-OS"
    if "junos" in text:
        return "Junos"
    if "routeros" in text:
        return "RouterOS"
    return "unknown"


def infer_role(route_detected: bool, vlan_detected: bool) -> str:
    if route_detected and vlan_detected:
        return "sw3"
    if route_detected and not vlan_detected:
        return "rou"
    if vlan_detected and not route_detected:
        return "sw2"
    return "unknown"


def route_table_found(output: str) -> bool:
    text = (output or "").lower()
    tokens = ["gateway of last resort", "routing entry", "c>*", "codes: c - connected", "show ip route"]
    return any(token in text for token in tokens)


def vlan_table_found(output: str) -> bool:
    text = (output or "").lower()
    tokens = ["vlan name", "----", "active", "show vlan"]
    return "vlan" in text and any(token in text for token in tokens)


def detect_from_cli_outputs(version_output: str, route_output: str, vlan_output: str) -> Tuple[Optional[str], str, bool, bool]:
    detected_os = detect_os_from_version(version_output)
    route_detected = route_table_found(route_output)
    vlan_detected = vlan_table_found(vlan_output)
    return detected_os, infer_role(route_detected, vlan_detected), route_detected, vlan_detected
