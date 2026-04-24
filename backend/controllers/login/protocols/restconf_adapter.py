from typing import Optional

from models import LoginResult


try:
    import requests
except Exception:  # pragma: no cover
    requests = None


def login_restconf(
    host: str,
    port: int,
    username: Optional[str],
    password: Optional[str],
    timeout: int,
    verify_ssl: bool = False,
) -> LoginResult:
    if requests is None:
        return LoginResult(False, "requests is not installed")

    base = f"https://{host}:{port}"
    headers = {"Accept": "application/yang-data+json"}
    auth = (username or "", password or "")

    endpoints = [
        "/restconf/data",
        "/restconf",
    ]

    last_error = "unknown"
    for path in endpoints:
        try:
            resp = requests.get(
                base + path,
                headers=headers,
                auth=auth,
                timeout=timeout,
                verify=verify_ssl,
            )
            if resp.status_code in (200, 204):
                server = resp.headers.get("Server", "")
                detected_os = server if server else "unknown"
                return LoginResult(
                    ok=True,
                    message=f"RESTCONF login success ({path})",
                    detected_os=detected_os,
                    detected_role="unknown",
                )
            if resp.status_code in (401, 403):
                last_error = f"auth failed ({resp.status_code})"
            else:
                last_error = f"http {resp.status_code}"
        except Exception as exc:
            last_error = str(exc)

    return LoginResult(False, f"RESTCONF login failed: {last_error}")
