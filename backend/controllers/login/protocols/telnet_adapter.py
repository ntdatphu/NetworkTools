from typing import Optional

from models import LoginResult
from protocols.detect_utils import detect_from_cli_outputs


try:
    from netmiko import ConnectHandler
except Exception:  # pragma: no cover
    ConnectHandler = None


TELNET_DEVICE_TYPE_FALLBACKS = [
    "cisco_ios_telnet",
    "terminal_server_telnet",
]


def _run_command(conn, command: str) -> str:
    try:
        return conn.send_command(command, read_timeout=15)
    except TypeError:
        return conn.send_command(command)


def _connect_with_fallback(host: str, port: int, username: Optional[str], password: Optional[str], timeout: int):
    errors = []
    for device_type in TELNET_DEVICE_TYPE_FALLBACKS:
        try:
            conn = ConnectHandler(
                device_type=device_type,
                host=host,
                port=port,
                username=username,
                password=password,
                timeout=timeout,
                conn_timeout=timeout,
                auth_timeout=timeout,
                banner_timeout=timeout,
                session_timeout=timeout,
                fast_cli=False,
            )
            return conn, device_type, errors
        except Exception as exc:
            errors.append(f"{device_type}: {exc}")
    return None, None, errors


def login_telnet(host: str, port: int, username: Optional[str], password: Optional[str], timeout: int) -> LoginResult:
    if ConnectHandler is None:
        return LoginResult(False, "netmiko is not installed")

    conn = None
    used_device_type = None
    try:
        conn, used_device_type, errors = _connect_with_fallback(host, port, username, password, timeout)
        if conn is None:
            return LoginResult(False, f"TELNET login failed (all device_type failed): {' | '.join(errors)}")

        version_output = _run_command(conn, "show version")
        config_output = _run_command(conn, "show running-config")
        route_output = _run_command(conn, "show ip route")
        if not route_output.strip():
            route_output = _run_command(conn, "show route")
        vlan_output = _run_command(conn, "show vlan")
        if not vlan_output.strip():
            vlan_output = _run_command(conn, "show vl")

        detected_os, detected_role, route_detected, vlan_detected = detect_from_cli_outputs(
            version_output, route_output, vlan_output
        )

        return LoginResult(
            ok=True,
            message=f"TELNET login success ({used_device_type})",
            detected_os=detected_os,
            detected_role=detected_role,
            raw_version=version_output[:2000],
            raw_config=config_output,
            route_detected=route_detected,
            vlan_detected=vlan_detected,
        )
    except Exception as exc:
        return LoginResult(False, f"TELNET login failed: {exc}")
    finally:
        try:
            if conn is not None:
                conn.disconnect()
        except Exception:
            pass
