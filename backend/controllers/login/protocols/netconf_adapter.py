from typing import Optional

from models import LoginResult


try:
    from ncclient import manager
except Exception:  # pragma: no cover
    manager = None


def login_netconf(host: str, port: int, username: Optional[str], password: Optional[str], timeout: int) -> LoginResult:
    if manager is None:
        return LoginResult(False, "ncclient is not installed")

    try:
        with manager.connect(
            host=host,
            port=port,
            username=username,
            password=password,
            hostkey_verify=False,
            allow_agent=False,
            look_for_keys=False,
            timeout=timeout,
        ) as m:
            server_caps = list(m.server_capabilities)
            detected_os = "unknown"
            for cap in server_caps:
                cap_lower = cap.lower()
                if "junos" in cap_lower:
                    detected_os = "Junos"
                    break
                if "cisco" in cap_lower:
                    detected_os = "IOS-XE"
                    break
            return LoginResult(
                ok=True,
                message="NETCONF login success",
                detected_os=detected_os,
                detected_role="unknown",
            )
    except Exception as exc:
        return LoginResult(False, f"NETCONF login failed: {exc}")
