import argparse
import json
from pathlib import Path
from typing import Callable, Dict, List

from config import DEFAULT_PORTS, LoginConfig
from models import Device
from protocols import SUPPORTED_METHODS


def _resolve_port(method: str, portnumber):
    if isinstance(portnumber, int) and portnumber > 0:
        return portnumber
    return DEFAULT_PORTS.get(method, 22)


def _run_method(method: str, fn: Callable, host: str, port: int, username: str, password: str, cfg: LoginConfig):
    if method == "RESTCONF":
        return fn(host, port, username, password, cfg.connect_timeout, cfg.verify_restconf_ssl)
    return fn(host, port, username, password, cfg.connect_timeout)


def main() -> int:
    parser = argparse.ArgumentParser(description="Manual JSON login flow (no DB interaction)")
    parser.add_argument("--input", required=True, help="Input JSON file path")
    parser.add_argument("--output", required=True, help="Output JSON file path")
    args = parser.parse_args()

    cfg = LoginConfig()

    input_data = json.loads(Path(args.input).read_text(encoding="utf-8"))
    raw_devices = input_data.get("devices", [])

    devices = [Device.from_dict(item) for item in raw_devices]

    output_rows: List[Dict] = []
    total = ok_count = fail_count = 0

    for dev in devices:
        total += 1
        method = (dev.method or "").upper()
        port = _resolve_port(method, dev.portnumber)

        if method not in SUPPORTED_METHODS:
            fail_count += 1
            output_rows.append(
                {
                    **dev.to_dict(),
                    "success": -1,
                    "message": "Unsupported method",
                }
            )
            continue

        login_fn = SUPPORTED_METHODS[method]
        login_result = _run_method(method, login_fn, dev.host, port, dev.username, dev.password, cfg)

        out = dev.to_dict()
        if login_result.ok:
            ok_count += 1
            out["success"] = 1
            out["os"] = login_result.detected_os or out.get("os")
            out["role"] = login_result.detected_role or out.get("role")
        else:
            fail_count += 1
            out["success"] = -1

        out["message"] = login_result.message
        out["route_detected"] = login_result.route_detected
        out["vlan_detected"] = login_result.vlan_detected
        output_rows.append(out)

    output = {
        "summary": {
            "total": total,
            "success": ok_count,
            "failed": fail_count,
        },
        "devices": output_rows,
    }

    Path(args.output).write_text(json.dumps(output, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps(output["summary"], indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
