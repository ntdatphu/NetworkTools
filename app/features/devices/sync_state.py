from __future__ import annotations

import re
import sqlite3
from ipaddress import IPv4Address
from typing import Any


ANSI_RE = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
CONTROL_RE = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")


def clean_text(value: Any) -> str:
    text = "" if value is None else str(value)
    text = ANSI_RE.sub("", text)
    text = CONTROL_RE.sub("", text)
    return text.strip()


def clean_label(value: Any) -> str:
    return clean_text(value).strip("\"'`#> ")


def int_or_none(value: Any) -> int | None:
    if value is None or value == "":
        return None
    try:
        return int(str(value).strip())
    except (TypeError, ValueError):
        return None


def bool_int(value: Any) -> int:
    if isinstance(value, str):
        return 1 if value.strip().lower() in {"1", "true", "yes", "on"} else 0
    return 1 if bool(value) else 0


def area_to_int(value: Any) -> int:
    text = clean_text(value)
    if not text:
        return 0
    try:
        return int(text)
    except ValueError:
        try:
            return int(IPv4Address(text))
        except ValueError:
            return 0


def parse_running_config_sections(config_text: str) -> tuple[str, list[dict[str, Any]], dict[int, dict[str, Any]]]:
    text = ANSI_RE.sub("", config_text or "").replace("\r\n", "\n").replace("\r", "\n")
    hostname = ""
    interfaces: list[dict[str, Any]] = []
    ospf_processes: dict[int, dict[str, Any]] = {}
    current_kind = ""
    current_name = ""
    current_body: list[str] = []

    def flush_current() -> None:
        nonlocal current_kind, current_name, current_body
        if current_kind == "interface":
            interfaces.append(parse_interface_block(current_name, current_body))
        elif current_kind == "ospf":
            process = parse_ospf_block(current_name, current_body)
            if process:
                ospf_processes[process["process_id"]] = process
        current_kind = ""
        current_name = ""
        current_body = []

    for raw in text.splitlines():
        line = CONTROL_RE.sub("", raw.rstrip())
        stripped = line.strip()
        if not stripped:
            continue
        if stripped == "!":
            flush_current()
            continue

        if stripped.startswith("hostname "):
            hostname = clean_label(stripped.split(None, 1)[1])

        is_top_level = not line.startswith((" ", "\t"))
        if is_top_level and stripped.startswith("interface "):
            flush_current()
            current_kind = "interface"
            current_name = clean_text(stripped.split(None, 1)[1])
            current_body = []
            continue
        if is_top_level and stripped.startswith("router ospf "):
            flush_current()
            current_kind = "ospf"
            current_name = stripped
            current_body = []
            continue
        if is_top_level:
            flush_current()
            continue
        if current_kind:
            current_body.append(stripped)

    flush_current()
    merge_interface_ospf_settings(ospf_processes, interfaces)
    return hostname, interfaces, ospf_processes


def parse_interface_brief(brief_text: str) -> dict[str, dict[str, Any]]:
    interfaces: dict[str, dict[str, Any]] = {}
    for raw in (brief_text or "").splitlines():
        line = clean_text(raw)
        if not line or line.lower().startswith("interface "):
            continue
        parts = line.split()
        if len(parts) < 6:
            continue
        name = parts[0]
        ip_addr = parts[1]
        status_text = " ".join(parts[4:-1]).lower()
        interfaces[name] = {
            "name": name,
            "ip_address": "" if ip_addr.lower() == "unassigned" else ip_addr,
            "shutdown": 1 if "administratively down" in status_text else 0,
        }
    return interfaces


def merge_interface_brief(interfaces: list[dict[str, Any]], brief_text: str) -> list[dict[str, Any]]:
    brief_rows = parse_interface_brief(brief_text)
    by_name = {row["name"]: row for row in interfaces}
    for name, brief in brief_rows.items():
        if name in by_name:
            if not by_name[name].get("ip_address") and brief.get("ip_address"):
                by_name[name]["ip_address"] = brief["ip_address"]
            if brief.get("shutdown"):
                by_name[name]["shutdown"] = 1
            continue
        row = default_interface(name)
        row["ip_address"] = brief.get("ip_address") or ""
        row["shutdown"] = brief.get("shutdown") or 0
        interfaces.append(row)
    return interfaces


def default_interface(name: str) -> dict[str, Any]:
    return {
        "name": clean_text(name),
        "ip_address": "",
        "subnet_mask": "",
        "description": "",
        "shutdown": 0,
        "secondary_ip": "",
        "secondary_mask": "",
        "mtu": 1500,
        "bandwidth": None,
        "delay": None,
        "speed": "auto",
        "duplex": "auto",
        "negotiation": 1,
        "proxy_arp": 1,
        "unreachables": 1,
        "directed_broadcast": 0,
        "tunnel_mode": "gre",
        "tunnel_src": "",
        "tunnel_dst": "",
        "tunnel_key": None,
        "keepalive_sec": None,
        "keepalive_retry": None,
        "ipsec_profile": "",
        "encap_type": "none",
        "pppoe_dialer_pool": None,
        "ppp_auth": "",
        "ppp_username": "",
        "ppp_password": "",
        "clock_rate": None,
        "lmi_type": "",
        "trust_mode": "none",
        "policy_in": "",
        "policy_out": "",
        "shape_rate": None,
        "police_rate": None,
        "police_burst": None,
        "has_qos": 0,
        "ospf_settings": [],
    }


def parse_interface_block(name: str, body: list[str]) -> dict[str, Any]:
    row = default_interface(name)
    ospf_bindings: list[dict[str, Any]] = []
    ospf_options: dict[str, Any] = {}

    for line in body:
        if line.startswith("description "):
            row["description"] = clean_text(line.split(None, 1)[1])
        elif line == "shutdown":
            row["shutdown"] = 1
        elif line == "no shutdown":
            row["shutdown"] = 0
        elif line.startswith("ip address "):
            parts = line.split()
            if len(parts) >= 4 and parts[2].lower() != "dhcp":
                if len(parts) >= 5 and parts[4].lower() == "secondary":
                    row["secondary_ip"] = parts[2]
                    row["secondary_mask"] = parts[3]
                else:
                    row["ip_address"] = parts[2]
                    row["subnet_mask"] = parts[3]
        elif line.startswith("mtu "):
            row["mtu"] = int_or_none(line.split(None, 1)[1]) or 1500
        elif line.startswith("bandwidth "):
            row["bandwidth"] = int_or_none(line.split(None, 1)[1])
        elif line.startswith("delay "):
            row["delay"] = int_or_none(line.split(None, 1)[1])
        elif line.startswith("speed "):
            speed = line.split(None, 1)[1].lower()
            row["speed"] = speed if speed in {"auto", "10", "100", "1000", "10000"} else "auto"
        elif line.startswith("duplex "):
            duplex = line.split(None, 1)[1].lower()
            row["duplex"] = duplex if duplex in {"auto", "full", "half"} else "auto"
        elif line in {"no negotiation auto", "nonegotiate"}:
            row["negotiation"] = 0
        elif line == "negotiation auto":
            row["negotiation"] = 1
        elif line == "no ip proxy-arp":
            row["proxy_arp"] = 0
        elif line == "ip proxy-arp":
            row["proxy_arp"] = 1
        elif line == "no ip unreachables":
            row["unreachables"] = 0
        elif line == "ip unreachables":
            row["unreachables"] = 1
        elif line == "ip directed-broadcast":
            row["directed_broadcast"] = 1
        elif line == "no ip directed-broadcast":
            row["directed_broadcast"] = 0
        elif line.startswith("tunnel mode "):
            mode_text = line.split(None, 2)[2].lower()
            row["tunnel_mode"] = "ipsec" if "ipsec" in mode_text else "ipip" if "ipip" in mode_text else "gre"
        elif line.startswith("tunnel source "):
            row["tunnel_src"] = clean_text(line.split(None, 2)[2])
        elif line.startswith("tunnel destination "):
            row["tunnel_dst"] = clean_text(line.split(None, 2)[2])
        elif line.startswith("tunnel key "):
            row["tunnel_key"] = int_or_none(line.split(None, 2)[2])
        elif line.startswith("keepalive "):
            parts = line.split()
            row["keepalive_sec"] = int_or_none(parts[1]) if len(parts) > 1 else None
            row["keepalive_retry"] = int_or_none(parts[2]) if len(parts) > 2 else None
        elif line.startswith("tunnel protection ipsec profile "):
            row["ipsec_profile"] = clean_text(line.rsplit(" ", 1)[1])
        elif line.startswith("encapsulation "):
            encap = line.split()[1].lower()
            row["encap_type"] = encap if encap in {"hdlc", "ppp", "frame-relay"} else "none"
        elif line.startswith("pppoe-client dial-pool-number "):
            row["encap_type"] = "pppoe"
            row["pppoe_dialer_pool"] = int_or_none(line.rsplit(" ", 1)[1])
        elif line.startswith("ppp authentication "):
            auth = line.split()[2].lower()
            row["ppp_auth"] = auth if auth in {"pap", "chap"} else ""
        elif line.startswith("clock rate "):
            row["clock_rate"] = int_or_none(line.rsplit(" ", 1)[1])
        elif line.startswith("frame-relay lmi-type "):
            lmi = line.rsplit(" ", 1)[1].lower()
            row["lmi_type"] = lmi if lmi in {"cisco", "ansi", "q933a"} else ""
        elif line.startswith("mls qos trust "):
            row["has_qos"] = 1
            row["trust_mode"] = clean_text(line.rsplit(" ", 1)[1])
        elif line.startswith("service-policy input "):
            row["has_qos"] = 1
            row["policy_in"] = clean_text(line.split(None, 2)[2])
        elif line.startswith("service-policy output "):
            row["has_qos"] = 1
            row["policy_out"] = clean_text(line.split(None, 2)[2])
        elif line.startswith("ip ospf "):
            parse_interface_ospf_line(line, ospf_bindings, ospf_options)

    for binding in ospf_bindings:
        merged = dict(ospf_options)
        merged.update(binding)
        row["ospf_settings"].append(merged)

    lowered_name = row["name"].lower()
    if lowered_name.startswith("tunnel"):
        row["interface_kind"] = "Tunnel"
    elif lowered_name.startswith("serial") or row["encap_type"] != "none":
        row["interface_kind"] = "WAN"
    else:
        row["interface_kind"] = "L3"
    return row


def parse_interface_ospf_line(line: str, bindings: list[dict[str, Any]], options: dict[str, Any]) -> None:
    parts = line.split()
    if len(parts) >= 5 and parts[2].isdigit() and parts[3] == "area":
        bindings.append({"process_id": int(parts[2]), "area": area_to_int(parts[4])})
    elif len(parts) >= 4 and parts[2] == "cost":
        options["cost"] = int_or_none(parts[3])
    elif len(parts) >= 4 and parts[2] == "hello-interval":
        options["hello_interval"] = int_or_none(parts[3])
    elif len(parts) >= 4 and parts[2] == "dead-interval":
        options["dead_interval"] = int_or_none(parts[3])
    elif len(parts) >= 3 and parts[2] == "mtu-ignore":
        options["mtu_ignore"] = 1
    elif len(parts) >= 3 and parts[2] == "bfd":
        options["bfd"] = 1
    elif len(parts) >= 4 and parts[2] == "network":
        net_type = parts[3]
        options["network_type"] = net_type if net_type in {"broadcast", "non-broadcast", "point-to-point", "point-to-multipoint"} else ""
    elif len(parts) >= 3 and parts[2] == "authentication":
        options["auth_type"] = "message-digest" if "message-digest" in parts[3:] else "plain"


def default_ospf_process(process_id: int) -> dict[str, Any]:
    return {
        "process_id": process_id,
        "router_id": "",
        "reference_bandwidth": None,
        "passive_default": 0,
        "default_originate": 0,
        "default_originate_always": 0,
        "networks": [],
        "distance": {},
        "areas": {},
        "redistribute": [],
        "passive_interfaces": [],
        "tuning": {},
        "interface_settings": [],
    }


def parse_ospf_block(header: str, body: list[str]) -> dict[str, Any] | None:
    match = re.match(r"router\s+ospf\s+(\d+)", header)
    if not match:
        return None
    process = default_ospf_process(int(match.group(1)))

    for line in body:
        if line.startswith("router-id "):
            process["router_id"] = clean_text(line.split(None, 1)[1])
        elif line.startswith("auto-cost reference-bandwidth "):
            process["reference_bandwidth"] = int_or_none(line.rsplit(" ", 1)[1])
        elif line == "passive-interface default":
            process["passive_default"] = 1
        elif line == "no passive-interface default":
            process["passive_default"] = 0
        elif line.startswith("passive-interface "):
            process["passive_interfaces"].append(
                {"interface_name": clean_text(line.split(None, 1)[1]), "passive": 1}
            )
        elif line.startswith("no passive-interface "):
            process["passive_interfaces"].append(
                {"interface_name": clean_text(line.split(None, 2)[2]), "passive": 0}
            )
        elif line.startswith("default-information originate"):
            process["default_originate"] = 1
            if " always" in f" {line} ":
                process["default_originate_always"] = 1
        elif line.startswith("network "):
            parts = line.split()
            if len(parts) >= 5 and parts[3] == "area":
                process["networks"].append(
                    {"network": parts[1], "wildcard": parts[2], "area": area_to_int(parts[4])}
                )
        elif line.startswith("distance ospf"):
            process["distance"] = parse_ospf_distance(line)
        elif line.startswith("maximum-paths "):
            process["tuning"]["maximum_paths"] = int_or_none(line.rsplit(" ", 1)[1])
        elif line.startswith("max-lsa "):
            process["tuning"]["max_lsa"] = int_or_none(line.split()[1])
        elif line.startswith("timers throttle spf "):
            parts = line.split()
            if len(parts) >= 6:
                process["tuning"].update(
                    {
                        "spf_delay": int_or_none(parts[3]),
                        "spf_min_delay": int_or_none(parts[4]),
                        "spf_max_delay": int_or_none(parts[5]),
                    }
                )
        elif line.startswith("timers throttle lsa all "):
            parts = line.split()
            if len(parts) >= 6:
                process["tuning"].update(
                    {
                        "lsa_delay": int_or_none(parts[4]),
                        "lsa_min_delay": int_or_none(parts[5]),
                        "lsa_max_delay": int_or_none(parts[6]) if len(parts) > 6 else None,
                    }
                )
        elif line.startswith("area "):
            parse_ospf_area_line(process, line)
        elif line.startswith("redistribute "):
            redist = parse_ospf_redistribute(line)
            if redist:
                process["redistribute"].append(redist)

    return process


def parse_ospf_distance(line: str) -> dict[str, int | None]:
    parts = line.split()
    distance = {"external": None, "intra_area": None, "inter_area": None}
    index = 2
    while index < len(parts) - 1:
        key = parts[index]
        value = int_or_none(parts[index + 1])
        if key == "external":
            distance["external"] = value
        elif key == "intra-area":
            distance["intra_area"] = value
        elif key == "inter-area":
            distance["inter_area"] = value
        index += 2
    return distance


def area_row(process: dict[str, Any], area_id: int) -> dict[str, Any]:
    areas = process["areas"]
    if area_id not in areas:
        areas[area_id] = {
            "area_id": area_id,
            "area_type": "normal",
            "no_summary": 0,
            "authentication": "",
            "ranges": [],
        }
    return areas[area_id]


def parse_ospf_area_line(process: dict[str, Any], line: str) -> None:
    parts = line.split()
    if len(parts) < 3:
        return
    area_id = area_to_int(parts[1])
    area = area_row(process, area_id)
    if parts[2] in {"stub", "nssa"}:
        area["area_type"] = parts[2]
        area["no_summary"] = 1 if "no-summary" in parts[3:] else 0
    elif parts[2] == "authentication":
        area["authentication"] = "message-digest" if "message-digest" in parts[3:] else "plain"
    elif parts[2] == "range" and len(parts) >= 5:
        range_row = {
            "ip": parts[3],
            "mask": parts[4],
            "advertise": 0 if "not-advertise" in parts[5:] else 1,
            "cost": None,
        }
        if "cost" in parts[5:]:
            cost_index = parts.index("cost")
            if cost_index + 1 < len(parts):
                range_row["cost"] = int_or_none(parts[cost_index + 1])
        area["ranges"].append(range_row)


def parse_ospf_redistribute(line: str) -> dict[str, Any] | None:
    parts = line.split()
    if len(parts) < 2:
        return None
    protocol = parts[1]
    allowed = {"static", "connected", "eigrp", "bgp", "rip", "isis"}
    if protocol not in allowed:
        return None
    redist: dict[str, Any] = {
        "protocol": protocol,
        "process_id": None,
        "subnets": 1 if "subnets" in parts[2:] else 0,
        "metric": None,
        "metric_type": None,
        "route_map": "",
    }
    index = 2
    if index < len(parts) and parts[index].isdigit() and protocol in {"eigrp", "bgp"}:
        redist["process_id"] = int(parts[index])
        index += 1
    while index < len(parts):
        token = parts[index]
        if token == "metric" and index + 1 < len(parts):
            redist["metric"] = int_or_none(parts[index + 1])
            index += 2
        elif token == "metric-type" and index + 1 < len(parts):
            redist["metric_type"] = int_or_none(parts[index + 1])
            index += 2
        elif token == "route-map" and index + 1 < len(parts):
            redist["route_map"] = parts[index + 1]
            index += 2
        else:
            index += 1
    return redist


def merge_interface_ospf_settings(processes: dict[int, dict[str, Any]], interfaces: list[dict[str, Any]]) -> None:
    for interface in interfaces:
        for setting in interface.get("ospf_settings", []):
            process_id = int_or_none(setting.get("process_id"))
            if process_id is None:
                continue
            process = processes.setdefault(process_id, default_ospf_process(process_id))
            area = area_to_int(setting.get("area"))
            area_row(process, area)
            process["interface_settings"].append(
                {
                    "interface_name": interface["name"],
                    "area": area,
                    "cost": setting.get("cost"),
                    "hello_interval": setting.get("hello_interval"),
                    "dead_interval": setting.get("dead_interval"),
                    "mtu_ignore": bool_int(setting.get("mtu_ignore")),
                    "bfd": bool_int(setting.get("bfd")),
                    "network_type": clean_text(setting.get("network_type")),
                    "auth_type": clean_text(setting.get("auth_type")),
                }
            )


def sync_device_state(
    db_path: str,
    host: str,
    running_config: str,
    interface_brief: str | None = None,
) -> dict[str, Any]:
    hostname, interfaces, ospf_processes = parse_running_config_sections(running_config)
    interfaces = merge_interface_brief(interfaces, interface_brief or "")

    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON;")
    try:
        with conn:
            if hostname:
                conn.execute(
                    "UPDATE t01_devices SET device_name = ? WHERE host = ?;",
                    (hostname, host),
                )
            sync_interfaces(conn, host, interfaces)
            sync_ospf_processes(conn, host, list(ospf_processes.values()))
    finally:
        conn.close()

    return {
        "hostname": hostname,
        "interfaces": len(interfaces),
        "ospf_processes": len(ospf_processes),
    }


def sync_interfaces(conn: sqlite3.Connection, host: str, interfaces: list[dict[str, Any]]) -> None:
    for table in (
        "t02_router_iface_l3",
        "t02_router_iface_tunnel",
        "t02_router_iface_wan",
        "t02_router_iface_qos",
    ):
        conn.execute(
            f"""
            UPDATE {table}
            SET success = -1
            WHERE iface_id IN (
                SELECT iface_id FROM t02_interface_name WHERE host = ?
            );
            """,
            (host,),
        )
    conn.execute("UPDATE t02_interface_name SET success = -1 WHERE host = ?;", (host,))

    for row in interfaces:
        name = clean_text(row.get("name"))
        if not name:
            continue
        found = conn.execute(
            """
            SELECT iface_id
            FROM t02_interface_name
            WHERE host = ? AND t02_interface_name = ?
            ORDER BY iface_id DESC
            LIMIT 1;
            """,
            (host, name),
        ).fetchone()
        if found:
            iface_id = int(found["iface_id"])
            conn.execute(
                """
                UPDATE t02_interface_name
                SET ip_address = ?, subnet_mask = ?, description = ?, shutdown = ?, success = 1
                WHERE iface_id = ?;
                """,
                (
                    clean_text(row.get("ip_address")) or None,
                    clean_text(row.get("subnet_mask")) or None,
                    clean_text(row.get("description")) or None,
                    bool_int(row.get("shutdown")),
                    iface_id,
                ),
            )
        else:
            cursor = conn.execute(
                """
                INSERT INTO t02_interface_name (
                    host, t02_interface_name, ip_address, subnet_mask, description, shutdown, success
                )
                VALUES (?, ?, ?, ?, ?, ?, 1);
                """,
                (
                    host,
                    name,
                    clean_text(row.get("ip_address")) or None,
                    clean_text(row.get("subnet_mask")) or None,
                    clean_text(row.get("description")) or None,
                    bool_int(row.get("shutdown")),
                ),
            )
            iface_id = int(cursor.lastrowid)

        kind = row.get("interface_kind") or "L3"
        if kind == "Tunnel" and row.get("tunnel_src") and row.get("tunnel_dst"):
            sync_tunnel(conn, iface_id, row)
        elif kind == "WAN":
            sync_wan(conn, iface_id, row)
        else:
            sync_l3(conn, iface_id, row)

        if bool_int(row.get("has_qos")):
            sync_qos(conn, iface_id, row)


def sync_l3(conn: sqlite3.Connection, iface_id: int, row: dict[str, Any]) -> None:
    conn.execute(
        """
        INSERT INTO t02_router_iface_l3 (
            iface_id, secondary_ip, secondary_mask, mtu, bandwidth, delay,
            speed, duplex, negotiation, proxy_arp, unreachables,
            directed_broadcast, success, action_Cfg
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, '11111')
        ON CONFLICT(iface_id) DO UPDATE SET
            secondary_ip = excluded.secondary_ip,
            secondary_mask = excluded.secondary_mask,
            mtu = excluded.mtu,
            bandwidth = excluded.bandwidth,
            delay = excluded.delay,
            speed = excluded.speed,
            duplex = excluded.duplex,
            negotiation = excluded.negotiation,
            proxy_arp = excluded.proxy_arp,
            unreachables = excluded.unreachables,
            directed_broadcast = excluded.directed_broadcast,
            success = 1,
            action_Cfg = '11111';
        """,
        (
            iface_id,
            clean_text(row.get("secondary_ip")) or None,
            clean_text(row.get("secondary_mask")) or None,
            int_or_none(row.get("mtu")) or 1500,
            int_or_none(row.get("bandwidth")),
            int_or_none(row.get("delay")),
            row.get("speed") or "auto",
            row.get("duplex") or "auto",
            bool_int(row.get("negotiation")),
            bool_int(row.get("proxy_arp")),
            bool_int(row.get("unreachables")),
            bool_int(row.get("directed_broadcast")),
        ),
    )


def sync_tunnel(conn: sqlite3.Connection, iface_id: int, row: dict[str, Any]) -> None:
    conn.execute(
        """
        INSERT INTO t02_router_iface_tunnel (
            iface_id, tunnel_mode, tunnel_src, tunnel_dst, tunnel_key,
            keepalive_sec, keepalive_retry, ipsec_profile, success, action_Cfg
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, '111')
        ON CONFLICT(iface_id) DO UPDATE SET
            tunnel_mode = excluded.tunnel_mode,
            tunnel_src = excluded.tunnel_src,
            tunnel_dst = excluded.tunnel_dst,
            tunnel_key = excluded.tunnel_key,
            keepalive_sec = excluded.keepalive_sec,
            keepalive_retry = excluded.keepalive_retry,
            ipsec_profile = excluded.ipsec_profile,
            success = 1,
            action_Cfg = '111';
        """,
        (
            iface_id,
            row.get("tunnel_mode") or "gre",
            clean_text(row.get("tunnel_src")),
            clean_text(row.get("tunnel_dst")),
            int_or_none(row.get("tunnel_key")),
            int_or_none(row.get("keepalive_sec")),
            int_or_none(row.get("keepalive_retry")),
            clean_text(row.get("ipsec_profile")) or None,
        ),
    )


def sync_wan(conn: sqlite3.Connection, iface_id: int, row: dict[str, Any]) -> None:
    conn.execute(
        """
        INSERT INTO t02_router_iface_wan (
            iface_id, encap_type, pppoe_dialer_pool, ppp_auth,
            ppp_username, ppp_password, clock_rate, lmi_type, success, action_Cfg
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, '11')
        ON CONFLICT(iface_id) DO UPDATE SET
            encap_type = excluded.encap_type,
            pppoe_dialer_pool = excluded.pppoe_dialer_pool,
            ppp_auth = excluded.ppp_auth,
            ppp_username = excluded.ppp_username,
            ppp_password = excluded.ppp_password,
            clock_rate = excluded.clock_rate,
            lmi_type = excluded.lmi_type,
            success = 1,
            action_Cfg = '11';
        """,
        (
            iface_id,
            row.get("encap_type") or "none",
            int_or_none(row.get("pppoe_dialer_pool")),
            clean_text(row.get("ppp_auth")) or None,
            clean_text(row.get("ppp_username")) or None,
            clean_text(row.get("ppp_password")) or None,
            int_or_none(row.get("clock_rate")),
            clean_text(row.get("lmi_type")) or None,
        ),
    )


def sync_qos(conn: sqlite3.Connection, iface_id: int, row: dict[str, Any]) -> None:
    conn.execute(
        """
        INSERT INTO t02_router_iface_qos (
            iface_id, trust_mode, policy_in, policy_out, shape_rate,
            police_rate, police_burst, success, action_Cfg
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, 1, '111')
        ON CONFLICT(iface_id) DO UPDATE SET
            trust_mode = excluded.trust_mode,
            policy_in = excluded.policy_in,
            policy_out = excluded.policy_out,
            shape_rate = excluded.shape_rate,
            police_rate = excluded.police_rate,
            police_burst = excluded.police_burst,
            success = 1,
            action_Cfg = '111';
        """,
        (
            iface_id,
            row.get("trust_mode") or "none",
            clean_text(row.get("policy_in")) or None,
            clean_text(row.get("policy_out")) or None,
            int_or_none(row.get("shape_rate")),
            int_or_none(row.get("police_rate")),
            int_or_none(row.get("police_burst")),
        ),
    )


def sync_ospf_processes(conn: sqlite3.Connection, host: str, processes: list[dict[str, Any]]) -> None:
    conn.execute("DELETE FROM t04_ospf_processes WHERE host = ?;", (host,))
    for process in processes:
        cursor = conn.execute(
            """
            INSERT INTO t04_ospf_processes (
                host, process_id, router_id, reference_bandwidth,
                passive_default, default_originate, default_originate_always, success
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, 1);
            """,
            (
                host,
                process["process_id"],
                clean_text(process.get("router_id")) or None,
                int_or_none(process.get("reference_bandwidth")),
                bool_int(process.get("passive_default")),
                bool_int(process.get("default_originate")),
                bool_int(process.get("default_originate_always")),
            ),
        )
        ospf_id = int(cursor.lastrowid)
        for network in process.get("networks", []):
            if network.get("network") and network.get("wildcard"):
                conn.execute(
                    """
                    INSERT INTO t04_ospf_networks (ospf_id, network, wildcard, area, success)
                    VALUES (?, ?, ?, ?, 1);
                    """,
                    (ospf_id, network["network"], network["wildcard"], area_to_int(network.get("area"))),
                )
        distance = process.get("distance") or {}
        if any(distance.get(key) is not None for key in ("external", "intra_area", "inter_area")):
            conn.execute(
                """
                INSERT INTO t04_ospf_distance (ospf_id, external, intra_area, inter_area, success)
                VALUES (?, ?, ?, ?, 1);
                """,
                (ospf_id, distance.get("external"), distance.get("intra_area"), distance.get("inter_area")),
            )
        for area in process.get("areas", {}).values():
            area_cursor = conn.execute(
                """
                INSERT INTO t04_ospf_areas (
                    ospf_id, area_id, area_type, no_summary, authentication, success
                )
                VALUES (?, ?, ?, ?, ?, 1);
                """,
                (
                    ospf_id,
                    area_to_int(area.get("area_id")),
                    area.get("area_type") or "normal",
                    bool_int(area.get("no_summary")),
                    clean_text(area.get("authentication")) or None,
                ),
            )
            area_db_id = int(area_cursor.lastrowid)
            for range_row in area.get("ranges", []):
                if range_row.get("ip") and range_row.get("mask"):
                    conn.execute(
                        """
                        INSERT INTO t04_ospf_area_ranges (area_db_id, ip, mask, advertise, cost, success)
                        VALUES (?, ?, ?, ?, ?, 1);
                        """,
                        (
                            area_db_id,
                            range_row["ip"],
                            range_row["mask"],
                            bool_int(range_row.get("advertise", True)),
                            int_or_none(range_row.get("cost")),
                        ),
                    )
        for redist in process.get("redistribute", []):
            conn.execute(
                """
                INSERT INTO t04_ospf_redistribute (
                    ospf_id, protocol, process_id, subnets, metric, metric_type, route_map, success
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, 1);
                """,
                (
                    ospf_id,
                    redist["protocol"],
                    int_or_none(redist.get("process_id")),
                    bool_int(redist.get("subnets")),
                    int_or_none(redist.get("metric")),
                    int_or_none(redist.get("metric_type")),
                    clean_text(redist.get("route_map")) or None,
                ),
            )
        for passive in process.get("passive_interfaces", []):
            if clean_text(passive.get("interface_name")):
                conn.execute(
                    """
                    INSERT INTO t04_ospf_passive_interfaces (
                        ospf_id, interface_name, passive, success
                    )
                    VALUES (?, ?, ?, 1);
                    """,
                    (
                        ospf_id,
                        clean_text(passive.get("interface_name")),
                        bool_int(passive.get("passive", True)),
                    ),
                )
        tuning = process.get("tuning") or {}
        if tuning:
            conn.execute(
                """
                INSERT INTO t04_ospf_tuning (
                    ospf_id, maximum_paths, max_lsa, spf_delay, spf_min_delay, spf_max_delay,
                    lsa_delay, lsa_min_delay, lsa_max_delay, success
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1);
                """,
                (
                    ospf_id,
                    int_or_none(tuning.get("maximum_paths")),
                    int_or_none(tuning.get("max_lsa")),
                    int_or_none(tuning.get("spf_delay")),
                    int_or_none(tuning.get("spf_min_delay")),
                    int_or_none(tuning.get("spf_max_delay")),
                    int_or_none(tuning.get("lsa_delay")),
                    int_or_none(tuning.get("lsa_min_delay")),
                    int_or_none(tuning.get("lsa_max_delay")),
                ),
            )
        for iface in process.get("interface_settings", []):
            if clean_text(iface.get("interface_name")):
                conn.execute(
                    """
                    INSERT INTO t04_router_iface_ospf (
                        ospf_id, iface_id, area, cost, hello_interval, dead_interval,
                        mtu_ignore, bfd, network_type, auth_type, success
                    )
                    VALUES (?, (SELECT iface_id FROM t02_interface_name WHERE host = ? AND interface_name = ?),
                            ?, ?, ?, ?, ?, ?, ?, ?, 1);
                    """,
                    (
                        ospf_id,
                        host,
                        clean_text(iface.get("interface_name")),
                        area_to_int(iface.get("area")),
                        int_or_none(iface.get("cost")),
                        int_or_none(iface.get("hello_interval")),
                        int_or_none(iface.get("dead_interval")),
                        bool_int(iface.get("mtu_ignore")),
                        bool_int(iface.get("bfd")),
                        clean_text(iface.get("network_type")) or None,
                        clean_text(iface.get("auth_type")) or None,
                    ),
                )
