import argparse
import json
from pathlib import Path
from typing import Callable, List

from config import DEFAULT_PORTS, LoginConfig
from db_client import DbClient
from protocols import SUPPORTED_METHODS


def _resolve_port(method: str, portnumber):
    if isinstance(portnumber, int) and portnumber > 0:
        return portnumber
    return DEFAULT_PORTS.get(method, 22)


def _run_method(method: str, fn: Callable, host: str, port: int, username: str, password: str, cfg: LoginConfig):
    if method == "RESTCONF":
        return fn(host, port, username, password, cfg.connect_timeout, cfg.verify_restconf_ssl)
    return fn(host, port, username, password, cfg.connect_timeout)


def _parse_hosts(raw_hosts: str) -> List[str]:
    return [h.strip() for h in (raw_hosts or "").split(",") if h.strip()]


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Connect selected host(s) from SQLite and update success/os/role for successful SSH/TELNET login."
    )
    parser.add_argument("--db", required=True, help="Path to device_network.db")
    parser.add_argument("--hosts", required=True, help="Comma-separated host list")
    parser.add_argument(
        "--include-nonzero-success",
        action="store_true",
        help="Include rows with success != 0 (default only success=0)",
    )
    parser.add_argument("--dump-json", default="", help="Optional output file with execution summary")
    args = parser.parse_args()

    hosts = _parse_hosts(args.hosts)
    if not hosts:
        print(json.dumps({"ok": False, "message": "No valid hosts provided.", "results": []}, ensure_ascii=False))
        return 2

    cfg = LoginConfig()
    db = DbClient(args.db)

    results = []
    total = ok_count = fail_count = skipped_count = 0

    try:
        success_filter = None if args.include_nonzero_success else 0
        devices = db.fetch_devices_for_hosts(hosts, success_filter)

        if not devices:
            summary = {
                "ok": False,
                "message": "No matching device rows found (check host or success state).",
                "summary": {"total": 0, "success": 0, "failed": 0, "skipped": 0},
                "results": [],
            }
            print(json.dumps(summary, indent=2, ensure_ascii=False))
            if args.dump_json:
                Path(args.dump_json).write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
            return 1

        for dev in devices:
            total += 1
            method = (dev.method or "").upper()

            if method not in ("SSH", "TELNET"):
                skipped_count += 1
                results.append(
                    {
                        "host": dev.host,
                        "method": method,
                        "ok": False,
                        "message": "Skipped: only SSH/TELNET are supported in this connect flow.",
                    }
                )
                continue

            login_fn = SUPPORTED_METHODS[method]
            port = _resolve_port(method, dev.portnumber)
            login_result = _run_method(method, login_fn, dev.host, port, dev.username, dev.password, cfg)

            with db.transaction():
                if login_result.ok:
                    db.update_login_status(dev.host, 1, login_result.detected_os, login_result.detected_role)
                    ok_count += 1
                else:
                    # Keep success=0 for failed login so the device remains in waiting state.
                    db.update_login_status(dev.host, 0, dev.os, dev.role)
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
            "ok": ok_count > 0,
            "message": f"Connected {ok_count}/{total} host(s). Failed: {fail_count}. Skipped: {skipped_count}.",
            "summary": {
                "total": total,
                "success": ok_count,
                "failed": fail_count,
                "skipped": skipped_count,
            },
            "results": results,
        }

        print(json.dumps(summary, indent=2, ensure_ascii=False))

        if args.dump_json:
            Path(args.dump_json).write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")

        return 0 if ok_count > 0 else 1
    finally:
        db.close()


if __name__ == "__main__":
    raise SystemExit(main())
