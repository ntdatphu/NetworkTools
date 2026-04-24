import argparse
import json
from pathlib import Path
from typing import Callable, Dict

from config import DEFAULT_PORTS, LoginConfig
from db_client import DbClient
from parser.acl_parser import parse_acl_payload
from parser.routing_parser import parse_routing_payload
from protocols import SUPPORTED_METHODS
from services.acl_service import save_acl_payload
from services.routing_service import save_routing_payload


def _resolve_port(method: str, portnumber):
    if isinstance(portnumber, int) and portnumber > 0:
        return portnumber
    return DEFAULT_PORTS.get(method, 22)


def _run_method(method: str, fn: Callable, host: str, port: int, username: str, password: str, cfg: LoginConfig):
    if method == "RESTCONF":
        return fn(host, port, username, password, cfg.connect_timeout, cfg.verify_restconf_ssl)
    return fn(host, port, username, password, cfg.connect_timeout)


def main() -> int:
    parser = argparse.ArgumentParser(description="Login devices from SQLite and update success/os/role.")
    parser.add_argument("--db", required=True, help="Path to device_network.db")
    parser.add_argument("--write-routing-acl", action="store_true", help="Parse and write routing tables + ACL_DB after login success")
    parser.add_argument("--dump-json", default="", help="Optional output file with execution summary")
    args = parser.parse_args()

    cfg = LoginConfig()
    db = DbClient(args.db)

    total = ok_count = fail_count = 0
    results = []

    try:
        devices = db.fetch_devices()
        for dev in devices:
            total += 1
            method = (dev.method or "").upper()
            if method not in SUPPORTED_METHODS:
                db.update_login_status(dev.host, -1, dev.os, dev.role)
                fail_count += 1
                results.append({"host": dev.host, "method": method, "ok": False, "message": "Unsupported method"})
                continue

            login_fn = SUPPORTED_METHODS[method]
            port = _resolve_port(method, dev.portnumber)
            login_result = _run_method(method, login_fn, dev.host, port, dev.username, dev.password, cfg)

            with db.transaction():
                if login_result.ok:
                    db.update_login_status(dev.host, 1, login_result.detected_os, login_result.detected_role)
                    ok_count += 1

                    if args.write_routing_acl and method in ("SSH", "TELNET"):
                        raw = login_result.raw_config or ""
                        routing_payload = parse_routing_payload(raw, dev.host)
                        acl_payload = parse_acl_payload(raw, dev.host)
                        save_routing_payload(db, routing_payload)
                        save_acl_payload(db, acl_payload)
                else:
                    db.update_login_status(dev.host, -1, dev.os, dev.role)
                    fail_count += 1

            results.append(
                {
                    "host": dev.host,
                    "method": method,
                    "port": port,
                    "ok": login_result.ok,
                    "message": login_result.message,
                    "detected_os": login_result.detected_os,
                    "detected_role": login_result.detected_role,
                    "route_detected": login_result.route_detected,
                    "vlan_detected": login_result.vlan_detected,
                }
            )

        summary = {
            "total": total,
            "success": ok_count,
            "failed": fail_count,
            "results": results,
        }
        print(json.dumps(summary, indent=2, ensure_ascii=False))

        if args.dump_json:
            Path(args.dump_json).write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")

        return 0
    finally:
        db.close()


if __name__ == "__main__":
    raise SystemExit(main())
