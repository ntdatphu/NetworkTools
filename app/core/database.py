from __future__ import annotations

import json
import shutil
import sqlite3
import sys
import zipfile
from collections.abc import Mapping, Sequence
from pathlib import Path
from typing import Any
from urllib.parse import unquote, urlparse
from xml.etree import ElementTree

from PyQt6.QtCore import QObject, pyqtSlot

from .runtime import APP_DIR, BACKEND_SERVICES_DIR, DB_PATH, NETWORK_CODE_DB_JSON_PATH, SQL_PATH
from .app_logger import AppLogger

if str(BACKEND_SERVICES_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_SERVICES_DIR))
NETWORK_CODE_DIR = APP_DIR / "network_code"
NETWORK_CODE_ROUTING_DIR = NETWORK_CODE_DIR / "routing"
if str(NETWORK_CODE_DIR) not in sys.path:
    sys.path.insert(0, str(NETWORK_CODE_DIR))
if str(NETWORK_CODE_ROUTING_DIR) not in sys.path:
    sys.path.insert(0, str(NETWORK_CODE_ROUTING_DIR))

from route import (
    get_eigrp_routing,
    get_ospf_routing,
    get_static_routing,
    save_eigrp_routing,
    save_ospf_routing,
    save_static_routing,
)

from .dhcp_slots import DhcpSlotsMixin
from .database_stubs import StubSlotsMixin


def _variant_list(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return rows


LEGACY_TABLE_MAP: tuple[tuple[str, str], ...] = (
    ("devices", "t01_devices"),
    ("yangcfg", "t01_yangcfg"),
    ("static_default_routes", "t04_static_default_routes"),
    ("static_routes", "t04_static_routes"),
    ("ospf_processes", "t04_ospf_processes"),
    ("ospf_networks", "t04_ospf_networks"),
    ("ospf_distance", "t04_ospf_distance"),
    ("ospf_areas", "t04_ospf_areas"),
    ("ospf_area_ranges", "t04_ospf_area_ranges"),
    ("ospf_redistribute", "t04_ospf_redistribute"),
    ("ospf_passive_interfaces", "t04_ospf_passive_interfaces"),
    ("ospf_tuning", "t04_ospf_tuning"),
    ("ospf_interface_settings", "t04_ospf_interface_settings"),
    ("router_iface_ospf", "t04_router_iface_ospf"),
    ("eigrp_processes", "t04_eigrp_processes"),
    ("eigrp_networks", "t04_eigrp_networks"),
    ("eigrp_interface_settings", "t04_eigrp_interface_settings"),
    ("router_iface_eigrp", "t04_router_iface_eigrp"),
    ("eigrp_passive_interfaces", "t04_eigrp_passive_interfaces"),
    ("eigrp_distribute_lists", "t04_eigrp_distribute_lists"),
    ("eigrp_offset_lists", "t04_eigrp_offset_lists"),
    ("eigrp_redistribute", "t04_eigrp_redistribute"),
    ("eigrp_key_chains", "t04_eigrp_key_chains"),
    ("info_routing_table", "t08_info_routing_table"),
)


class DatabaseManager(DhcpSlotsMixin, StubSlotsMixin, QObject):
    def __init__(self, parent: QObject | None = None, app_logger: AppLogger | None = None) -> None:
        super().__init__(parent)
        self.app_dir = APP_DIR
        self.db_path = DB_PATH
        self.sql_path = SQL_PATH
        self._last_routing_error = ""
        self._logger = app_logger
        self.initializeDatabase()

    def _log(self, status: str, message: str, category: str = "SYSTEM", source: str = "db") -> None:
        if self._logger is not None:
            self._logger.log(status, message, source, category)

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA foreign_keys = ON;")
        return conn

    def _ensure_column(self, conn: sqlite3.Connection, table: str, column: str, ddl: str) -> None:
        columns = {row["name"] for row in conn.execute(f"PRAGMA table_info({table});")}
        if column not in columns:
            conn.execute(ddl)

    def _table_exists(self, conn: sqlite3.Connection, table: str) -> bool:
        row = conn.execute(
            """
            SELECT 1
            FROM sqlite_master
            WHERE type = 'table' AND name = ?
            LIMIT 1;
            """,
            (table,),
        ).fetchone()
        return row is not None

    def _table_columns(self, conn: sqlite3.Connection, table: str) -> set[str]:
        return {row["name"] for row in conn.execute(f"PRAGMA table_info({table});")}

    def _migrate_legacy_tables(self, conn: sqlite3.Connection) -> None:
        for source, target in LEGACY_TABLE_MAP:
            if not self._table_exists(conn, source) or not self._table_exists(conn, target):
                continue

            source_columns = self._table_columns(conn, source)
            target_columns = self._table_columns(conn, target)
            columns = [column for column in target_columns if column in source_columns]
            select_columns = list(columns)

            if source == "devices" and "yangcfg" in source_columns and "t01_yangcfg" in target_columns:
                columns.append("t01_yangcfg")
                select_columns.append("yangcfg")

            if not columns:
                continue

            column_sql = ", ".join(columns)
            select_sql = ", ".join(select_columns)
            conn.execute(
                f"""
                INSERT OR IGNORE INTO {target} ({column_sql})
                SELECT {select_sql}
                FROM {source};
                """
            )

    def _as_list(self, value: Any) -> list[Any]:
        if hasattr(value, "toVariant"):
            value = value.toVariant()
        if value is None:
            return []
        if isinstance(value, str):
            try:
                decoded = json.loads(value)
            except json.JSONDecodeError:
                return []
            return self._as_list(decoded)
        if isinstance(value, list):
            return value
        if isinstance(value, tuple):
            return list(value)
        if isinstance(value, Sequence) and not isinstance(value, (str, bytes, bytearray)):
            return list(value)
        return []

    def _as_dict(self, value: Any) -> dict[str, Any]:
        if hasattr(value, "toVariant"):
            value = value.toVariant()
        if isinstance(value, str):
            try:
                decoded = json.loads(value)
            except json.JSONDecodeError:
                return {}
            return self._as_dict(decoded)
        if isinstance(value, dict):
            return value
        if isinstance(value, Mapping):
            return dict(value)
        return {}

    def _int_or_none(self, value: Any) -> int | None:
        if value is None or value == "":
            return None
        if isinstance(value, bool):
            return int(value)
        if isinstance(value, int):
            return value
        if isinstance(value, float):
            return int(value) if value.is_integer() else None
        try:
            text = str(value).strip()
            return int(text)
        except (TypeError, ValueError):
            try:
                number = float(str(value).strip())
            except (TypeError, ValueError):
                return None
            return int(number) if number.is_integer() else None

    def _int_or_zero(self, value: Any) -> int:
        return self._int_or_none(value) or 0

    def _bool_int(self, value: Any) -> int:
        if isinstance(value, str):
            return 1 if value.strip().lower() in {"1", "true", "yes", "on"} else 0
        return 1 if bool(value) else 0

    def _str_or_none(self, value: Any) -> str | None:
        if value is None:
            return None
        text = str(value).strip()
        return text or None

    def _dict_rows(self, rows: list[sqlite3.Row]) -> list[dict[str, Any]]:
        return [dict(row) for row in rows]

    def _set_last_routing_error(self, message: str) -> None:
        self._last_routing_error = (message or "").strip()

    def _write_network_code_db_paths(self) -> None:
        NETWORK_CODE_DB_JSON_PATH.parent.mkdir(parents=True, exist_ok=True)
        data = {
            "device_network_db": str(self.db_path.resolve()),
            "main_sql": str(self.sql_path.resolve()),
        }
        NETWORK_CODE_DB_JSON_PATH.write_text(json.dumps(data, indent=4), encoding="utf-8")

    def _file_url_to_path(self, value: str) -> Path:
        text = (value or "").strip()
        parsed = urlparse(text)
        if parsed.scheme == "file":
            path = unquote(parsed.path)
            if parsed.netloc:
                path = f"//{parsed.netloc}{path}"
            if sys.platform.startswith("win") and path.startswith("/") and len(path) > 2 and path[2] == ":":
                path = path[1:]
            return Path(path)
        return Path(text)

    def _normalize_import_key(self, key: Any) -> str:
        text = str(key or "").strip().lower().replace(" ", "_").replace("-", "_")
        aliases = {
            "ip": "host",
            "hostname": "host",
            "device_name": "name",
            "protocol": "method",
            "port": "portnumber",
            "port_number": "portnumber",
            "user": "username",
            "pass": "password",
            "device_type": "type",
            "netmiko_type": "os",
        }
        return aliases.get(text, text)

    def _normalize_import_row(self, raw: Mapping[str, Any], line_number: int) -> dict[str, Any]:
        row = {self._normalize_import_key(key): value for key, value in raw.items()}
        method = str(row.get("method") or "SSH").strip().upper()
        default_port = 23 if method == "TELNET" else 830 if method == "NETCONF" else 443 if method == "RESTCONF" else 22
        role = str(row.get("role") or "").strip()
        device_type = str(row.get("type") or row.get("device_type") or role or "unknown").strip() or "unknown"
        return {
            "lineNumber": line_number,
            "host": str(row.get("host") or "").strip(),
            "name": str(row.get("name") or "").strip(),
            "method": method,
            "port": self._int_or_none(row.get("portnumber")) or default_port,
            "username": str(row.get("username") or "").strip(),
            "password": str(row.get("password") or "").strip(),
            "os": str(row.get("os") or "cisco_ios").strip() or "cisco_ios",
            "role": role,
            "type": device_type,
        }

    def _read_json_import_rows(self, path: Path) -> list[dict[str, Any]]:
        data = json.loads(path.read_text(encoding="utf-8-sig"))
        if isinstance(data, dict):
            for key in ("devices", "rows", "items"):
                if isinstance(data.get(key), list):
                    data = data[key]
                    break
        rows = self._as_list(data)
        return [self._normalize_import_row(self._as_dict(row), index + 1) for index, row in enumerate(rows)]

    def _xlsx_cell_text(self, cell: ElementTree.Element, shared_strings: list[str], ns: dict[str, str]) -> str:
        cell_type = cell.attrib.get("t", "")
        value = cell.find("x:v", ns)
        inline = cell.find("x:is/x:t", ns)
        text = inline.text if inline is not None else value.text if value is not None else ""
        if cell_type == "s":
            index = self._int_or_none(text)
            if index is not None and 0 <= index < len(shared_strings):
                return shared_strings[index]
        return text or ""

    def _xlsx_column_index(self, cell_ref: str) -> int:
        letters = "".join(ch for ch in (cell_ref or "") if ch.isalpha()).upper()
        index = 0
        for ch in letters:
            index = index * 26 + (ord(ch) - ord("A") + 1)
        return max(index - 1, 0)

    def _read_xlsx_import_rows(self, path: Path) -> list[dict[str, Any]]:
        ns = {"x": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
        with zipfile.ZipFile(path) as workbook:
            shared_strings: list[str] = []
            if "xl/sharedStrings.xml" in workbook.namelist():
                root = ElementTree.fromstring(workbook.read("xl/sharedStrings.xml"))
                for item in root.findall("x:si", ns):
                    shared_strings.append("".join(node.text or "" for node in item.findall(".//x:t", ns)))

            sheet_name = "xl/worksheets/sheet1.xml"
            root = ElementTree.fromstring(workbook.read(sheet_name))
            table: list[list[str]] = []
            for row in root.findall(".//x:sheetData/x:row", ns):
                values: list[str] = []
                for cell in row.findall("x:c", ns):
                    column = self._xlsx_column_index(cell.attrib.get("r", ""))
                    while len(values) <= column:
                        values.append("")
                    values[column] = self._xlsx_cell_text(cell, shared_strings, ns).strip()
                if any(values):
                    table.append(values)

        if not table:
            return []
        headers = [self._normalize_import_key(value) for value in table[0]]
        rows: list[dict[str, Any]] = []
        for index, values in enumerate(table[1:], start=2):
            raw = {headers[col]: values[col] if col < len(values) else "" for col in range(len(headers))}
            rows.append(self._normalize_import_row(raw, index))
        return rows

    def _import_devices_from_path(self, path: Path) -> dict[str, Any]:
        if not path.exists():
            self._log("ERROR", f"Device import failed: file not found: {path}", "VALIDATION", "devices")
            return {"ok": False, "message": f"File not found: {path}", "added": 0, "skipped": 0}

        suffix = path.suffix.lower()
        if suffix == ".json":
            rows = self._read_json_import_rows(path)
        elif suffix == ".xlsx":
            rows = self._read_xlsx_import_rows(path)
        else:
            self._log("ERROR", f"Device import failed: unsupported file type {suffix or '(none)'}.", "VALIDATION", "devices")
            return {"ok": False, "message": "Only .xlsx and .json imports are supported.", "added": 0, "skipped": 0}

        if not rows:
            self._log("WARNING", f"Device import failed: no device rows found in {path.name}.", "VALIDATION", "devices")
            return {"ok": False, "message": "No device rows found in import file.", "added": 0, "skipped": 0}

        added = 0
        skipped = 0
        with self._connect() as conn:
            for row in rows:
                if not row["host"]:
                    skipped += 1
                    continue
                cursor = conn.execute(
                    """
                    INSERT OR IGNORE INTO t01_devices
                        (host, device_name, method, portnumber, username, password, os, role, success, admin, device_type)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, 0, ?);
                    """,
                    (
                        row["host"],
                        row["name"] or None,
                        row["method"] or None,
                        row["port"],
                        row["username"] or None,
                        row["password"] or None,
                        row["os"] or None,
                        row["role"] or None,
                        row["type"] or "unknown",
                    ),
                )
                if cursor.rowcount:
                    added += 1
                else:
                    skipped += 1
            conn.commit()

        self.createFoldersFromDevices()
        status = "SUCCESS" if added > 0 else "WARNING"
        self._log(status, f"Imported {added}/{len(rows)} device(s) from {path.name}. Skipped: {skipped}.", "ACTIVITY", "devices")
        return {"ok": added > 0, "message": f"Imported {added}/{len(rows)} devices. Skipped: {skipped}.", "added": added, "skipped": skipped}

    @pyqtSlot(result=str)
    def getLastRoutingError(self) -> str:
        return self._last_routing_error

    def _routing_device_context(self, host: str) -> dict[str, str]:
        with self._connect() as conn:
            row = conn.execute(
                """
                SELECT os, method
                FROM t01_devices
                WHERE host = ?;
                """,
                (host,),
            ).fetchone()
        if row is None:
            return {"platform": "cisco_ios", "template_folder": "cisco_ios", "method": "SSH"}
        os_name = (row["os"] or "cisco_ios").strip()
        platform = "cisco_ios" if os_name == "cisco" else os_name
        template_folder = "cisco_ios" if platform == "cisco_ios_telnet" else platform
        return {
            "platform": platform,
            "template_folder": template_folder,
            "method": (row["method"] or "SSH").strip().upper(),
        }

    def _routing_module(self, module_name: str) -> str:
        text = (module_name or "all").strip().lower()
        return text if text in {"static", "ospf", "eigrp", "all"} else "all"

    @pyqtSlot(str, str, result="QVariant")
    def previewRoutingConfig(self, host: str, module_name: str) -> dict[str, Any]:
        host = (host or "").strip()
        if not host:
            return {"ok": False, "message": "Host is empty.", "commands": "", "tasks": []}

        try:
            self._write_network_code_db_paths()
            from routing.main import routing_dispatcher
            from routing.worker_routing import render_routing_config

            module = self._routing_module(module_name)
            tasks = routing_dispatcher(target_ip=host, target_module=module, dry_run=True) or []
            if not tasks:
                self._log("INFO", f"Routing preview for {host}: no pending {module.upper()} configuration.", "CONFIGURATION", "routing")
                return {"ok": True, "message": "No pending routing configuration to push.", "commands": "", "tasks": []}

            rendered: list[str] = []
            for task in tasks:
                target = task.get("target", {}).get("ip", host)
                context = self._routing_device_context(target)
                sub_type = str(task.get("sub_type") or module).lower()
                action = str(task.get("action") or "setup").lower()
                raw_config = task.get("config", [])
                configs = raw_config if isinstance(raw_config, list) else [raw_config]
                rendered.append(f"# {target} / {sub_type.upper()} / {action.upper()}")
                for cfg in configs:
                    commands = render_routing_config(context["template_folder"], sub_type, cfg, action)
                    lines = [line.strip() for line in commands.splitlines() if line.strip() and not line.strip().startswith("!")]
                    rendered.extend(lines or ["# No commands rendered."])
                rendered.append("")

            self._log("SUCCESS", f"Routing preview prepared {len(tasks)} {module.upper()} task(s) for {host}.", "CONFIGURATION", "routing")
            return {
                "ok": True,
                "message": f"Prepared {len(tasks)} routing task(s).",
                "commands": "\n".join(rendered).strip(),
                "tasks": _variant_list(tasks),
            }
        except Exception as exc:
            message = f"Preview routing failed: {exc}"
            self._set_last_routing_error(message)
            self._log("ERROR", message, "CONFIGURATION", "routing")
            print(f"[db] {message}", file=sys.stderr)
            return {"ok": False, "message": message, "commands": "", "tasks": []}

    @pyqtSlot(str, str, result="QVariant")
    def pushRoutingConfig(self, host: str, module_name: str) -> dict[str, Any]:
        host = (host or "").strip()
        if not host:
            return {"ok": False, "message": "Host is empty.", "report": []}

        try:
            self._write_network_code_db_paths()
            from PyCode.share.config import TMP_DIR
            from routing.main import routing_dispatcher

            module = self._routing_module(module_name)
            routing_dispatcher(target_ip=host, target_module=module)

            log_name = f"routing_log_{module}_{host.replace('.', '_')}.json"
            log_path = Path(TMP_DIR) / log_name
            report: list[dict[str, Any]] = []
            if log_path.exists():
                report = json.loads(log_path.read_text(encoding="utf-8"))

            ok = bool(report) and all(str(item.get("status", "")).upper() == "SUCCESS" for item in report)
            if not report:
                self._log("INFO", f"Routing push for {host}: no pending {module.upper()} configuration.", "CONFIGURATION", "routing")
                return {"ok": True, "message": "No pending routing configuration to push.", "report": []}
            self._log("SUCCESS" if ok else "ERROR", "Routing push completed for " + host + "." if ok else "Routing push finished with errors for " + host + ".", "CONFIGURATION", "routing")
            return {
                "ok": ok,
                "message": "Routing push completed." if ok else "Routing push finished with errors.",
                "report": _variant_list(report),
            }
        except Exception as exc:
            message = f"Push routing failed: {exc}"
            self._set_last_routing_error(message)
            self._log("ERROR", message, "CONFIGURATION", "routing")
            print(f"[db] {message}", file=sys.stderr)
            return {"ok": False, "message": message, "report": []}

    @pyqtSlot(result=bool)
    def initializeDatabase(self) -> bool:
        try:
            APP_DIR.mkdir(parents=True, exist_ok=True)
            db_exists = self.db_path.exists()
            with self._connect() as conn:
                if not db_exists or not self._table_exists(conn, "t01_devices"):
                    script = self.sql_path.read_text(encoding="utf-8")
                    conn.executescript(script)
                self._ensure_column(conn, "t01_devices", "os", "ALTER TABLE t01_devices ADD COLUMN os TEXT;")
                self._ensure_column(conn, "t01_devices", "role", "ALTER TABLE t01_devices ADD COLUMN role TEXT;")
                self._ensure_column(conn, "t01_devices", "admin", "ALTER TABLE t01_devices ADD COLUMN admin INTEGER DEFAULT 0;")
                self._ensure_column(conn, "t01_devices", "device_type", "ALTER TABLE t01_devices ADD COLUMN device_type TEXT DEFAULT 'unknown';")
                self._ensure_column(conn, "t01_devices", "t01_yangcfg", "ALTER TABLE t01_devices ADD COLUMN t01_yangcfg INTEGER DEFAULT 0;")
                self._migrate_legacy_tables(conn)
                conn.execute(
                    """
                    CREATE TABLE IF NOT EXISTS t01_yangcfg (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        host TEXT NOT NULL,
                        username TEXT,
                        password TEXT,
                        success INTEGER DEFAULT 0,
                        FOREIGN KEY (host) REFERENCES t01_devices(host)
                            ON UPDATE CASCADE ON DELETE CASCADE
                    );
                    """
                )
                conn.commit()
            self._write_network_code_db_paths()
            return True
        except Exception as exc:
            print(f"[db] initialize failed: {exc}", file=sys.stderr)
            return False

    @pyqtSlot(str, str, str, str, str, str, result=bool)
    @pyqtSlot(str, str, str, str, str, str, str, str, str, result=bool)
    def addDevice(
        self,
        host: str,
        device_name: str,
        method: str,
        port_text: str,
        username: str,
        password: str,
        os_name: str = "",
        role: str = "",
        device_type: str = "",
    ) -> bool:
        host = (host or "").strip()
        if not host:
            self._log("WARNING", "Add device failed: host is empty.", "VALIDATION", "devices")
            return False
        try:
            port = int(port_text) if str(port_text).strip() else None
        except ValueError:
            self._log("WARNING", f"Add device failed for {host}: port must be an integer.", "VALIDATION", "devices")
            port = None
        try:
            with self._connect() as conn:
                conn.execute(
                    """
                    INSERT INTO t01_devices
                        (host, device_name, method, portnumber, username, password, os, role, success, admin, device_type)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, 0, ?);
                    """,
                    (
                        host,
                        device_name or None,
                        method or None,
                        port,
                        username or None,
                        password or None,
                        os_name or None,
                        role or None,
                        (device_type or role or "unknown"),
                    ),
                )
                conn.commit()
            self._log("SUCCESS", f"Device {host} added successfully.", "ACTIVITY", "devices")
            return True
        except sqlite3.IntegrityError:
            self._log("WARNING", f"Add device skipped: {host} already exists.", "VALIDATION", "devices")
            return False
        except sqlite3.Error as exc:
            self._log("ERROR", f"Add device failed for {host}: {exc}", "SYSTEM", "db")
            print(f"[db] addDevice failed: {exc}", file=sys.stderr)
            return False

    @pyqtSlot(str, result="QVariant")
    def importDevicesFromFile(self, file_url: str) -> dict[str, Any]:
        try:
            return self._import_devices_from_path(self._file_url_to_path(file_url))
        except Exception as exc:
            self._log("ERROR", f"Device import failed: {exc}", "SYSTEM", "devices")
            print(f"[db] importDevicesFromFile failed: {exc}", file=sys.stderr)
            return {"ok": False, "message": str(exc), "added": 0, "skipped": 0}

    @pyqtSlot(str, result="QVariant")
    def saveDeviceImportSample(self, file_url: str) -> dict[str, Any]:
        try:
            source = self.app_dir / "EX" / "EXdevices.xlsx"
            if not source.exists():
                self._log("ERROR", f"Sample device import file was not found: {source}", "SYSTEM", "devices")
                return {"ok": False, "message": f"Sample file not found: {source}"}

            target = self._file_url_to_path(file_url)
            if target.suffix.lower() != ".xlsx":
                target = target.with_suffix(".xlsx")
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
            self._log("SUCCESS", f"Sample device import file saved to {target}.", "ACTIVITY", "devices")
            return {"ok": True, "message": f"Saved sample Excel file:\n{target}"}
        except Exception as exc:
            self._log("ERROR", f"Save sample device import file failed: {exc}", "SYSTEM", "devices")
            print(f"[db] saveDeviceImportSample failed: {exc}", file=sys.stderr)
            return {"ok": False, "message": str(exc)}

    @pyqtSlot(str, result=bool)
    def deleteDevice(self, host: str) -> bool:
        try:
            target_host = (host or "").strip()
            with self._connect() as conn:
                cursor = conn.execute("DELETE FROM devices WHERE host = ?;", (target_host,))
                conn.commit()
            if cursor.rowcount:
                self._log("SUCCESS", f"Device {target_host} deleted.", "ACTIVITY", "devices")
            else:
                self._log("WARNING", f"Delete device skipped: {target_host} was not found.", "VALIDATION", "devices")
            return True
        except sqlite3.Error as exc:
            self._log("ERROR", f"Delete device failed for {(host or '').strip()}: {exc}", "SYSTEM", "db")
            print(f"[db] deleteDevice failed: {exc}", file=sys.stderr)
            return False

    @pyqtSlot(str, int, result=bool)
    def updateDeviceSuccess(self, host: str, success: int) -> bool:
        try:
            target_host = (host or "").strip()
            with self._connect() as conn:
                conn.execute("UPDATE devices SET success = ? WHERE host = ?;", (success, target_host))
                conn.commit()
            status_name = {1: "connected", 0: "waiting", -1: "disconnected", 3: "hidden"}.get(success, str(success))
            self._log("INFO", f"Device {target_host} status set to {status_name}.", "CONFIGURATION", "devices")
            return True
        except sqlite3.Error as exc:
            self._log("ERROR", f"Update device status failed for {(host or '').strip()}: {exc}", "SYSTEM", "db")
            print(f"[db] updateDeviceSuccess failed: {exc}", file=sys.stderr)
            return False

    @pyqtSlot(str, int, result=bool)
    def updateDeviceAdmin(self, host: str, admin: int) -> bool:
        try:
            target_host = (host or "").strip()
            with self._connect() as conn:
                conn.execute("UPDATE devices SET admin = ? WHERE host = ?;", (1 if admin else 0, target_host))
                conn.commit()
            self._log("INFO", f"Device {target_host} admin flag set to {'enabled' if admin else 'disabled'}.", "CONFIGURATION", "devices")
            return True
        except sqlite3.Error as exc:
            self._log("ERROR", f"Update device admin flag failed for {(host or '').strip()}: {exc}", "SYSTEM", "db")
            print(f"[db] updateDeviceAdmin failed: {exc}", file=sys.stderr)
            return False

    @pyqtSlot(str, str, str, str, str, str, result=bool)
    @pyqtSlot(str, str, str, str, str, str, str, str, str, result=bool)
    def updateDevice(
        self,
        host: str,
        device_name: str,
        method: str,
        port_text: str,
        username: str,
        password: str,
        os_name: str = "",
        role: str = "",
        device_type: str = "",
    ) -> bool:
        try:
            port = int(port_text) if str(port_text).strip() else None
        except ValueError:
            self._log("WARNING", f"Update device failed for {(host or '').strip()}: port must be an integer.", "VALIDATION", "devices")
            port = None
        try:
            target_host = (host or "").strip()
            with self._connect() as conn:
                conn.execute(
                    """
                    UPDATE t01_devices
                    SET device_name = ?, method = ?, portnumber = ?, username = ?, password = ?,
                        os = ?, role = ?, device_type = ?
                    WHERE host = ?;
                    """,
                    (
                        device_name or None,
                        method or None,
                        port,
                        username or None,
                        password or None,
                        os_name or None,
                        role or None,
                        (device_type or role or "unknown"),
                        target_host,
                    ),
                )
                conn.commit()
            self._log("SUCCESS", f"Device {target_host} updated successfully.", "ACTIVITY", "devices")
            return True
        except sqlite3.Error as exc:
            self._log("ERROR", f"Update device failed for {(host or '').strip()}: {exc}", "SYSTEM", "db")
            print(f"[db] updateDevice failed: {exc}", file=sys.stderr)
            return False

    @pyqtSlot(str, result="QVariant")
    def getDeviceByHost(self, host: str) -> dict[str, Any]:
        try:
            with self._connect() as conn:
                row = conn.execute(
                    """
                    SELECT host, device_name, method, portnumber, username, password, os, role, device_type, admin
                    FROM t01_devices
                    WHERE host = ?;
                    """,
                    ((host or "").strip(),),
                ).fetchone()
            if row is None:
                return {}
            return {
                "ip": row["host"],
                "name": row["device_name"] or "",
                "protocol": row["method"] or "SSH",
                "port": "" if row["portnumber"] is None else str(row["portnumber"]),
                "user": row["username"] or "",
                "pass": row["password"] or "",
                "os": row["os"] or "cisco_ios",
                "role": row["role"] or "",
                "type": row["device_type"] or "unknown",
                "admin": row["admin"] if row["admin"] is not None else 0,
            }
        except sqlite3.Error as exc:
            print(f"[db] getDeviceByHost failed: {exc}", file=sys.stderr)
            return {}

    @pyqtSlot(result="QVariant")
    def getDevices(self) -> list[dict[str, Any]]:
        try:
            with self._connect() as conn:
                rows = conn.execute(
                    """
                    SELECT host, device_name, success, device_type
                    FROM t01_devices
                    ORDER BY host COLLATE NOCASE;
                    """
                ).fetchall()
            out: list[dict[str, Any]] = []
            for row in rows:
                success = int(row["success"] if row["success"] is not None else 0)
                if success == 3:
                    continue
                status = {1: "connected", 0: "waiting", -1: "disconnected"}.get(success)
                if status is None:
                    continue
                name = (row["device_name"] or "").strip() or row["host"]
                out.append({"name": name, "ip": row["host"], "status": status, "type": (row["device_type"] or "unknown").strip() or "unknown"})
            return _variant_list(out)
        except sqlite3.Error as exc:
            print(f"[db] getDevices failed: {exc}", file=sys.stderr)
            return []

    @pyqtSlot(result=bool)
    def createFoldersFromDevices(self) -> bool:
        try:
            with self._connect() as conn:
                rows = conn.execute("SELECT host FROM t01_devices WHERE COALESCE(success, 0) != 3;").fetchall()
            backup_dir = self.app_dir / "backup"
            backup_dir.mkdir(exist_ok=True)
            for row in rows:
                host = (row["host"] or "").strip()
                if host:
                    (backup_dir / host).mkdir(exist_ok=True)
            return True
        except Exception as exc:
            print(f"[db] createFoldersFromDevices failed: {exc}", file=sys.stderr)
            return False

    @pyqtSlot(str, result="QVariant")
    def getRunningConfigBackup(self, host: str) -> dict[str, Any]:
        host = (host or "").strip()
        if not host:
            return {"ok": False, "message": "Host is empty.", "path": "", "content": ""}

        backup_file = self.app_dir / "backup" / host / f"{host}_running-config.txt"
        if not backup_file.exists():
            return {
                "ok": False,
                "message": f"No running-config backup found for {host}.",
                "path": str(backup_file),
                "content": "",
            }

        for encoding in ("utf-8-sig", "utf-8", "cp1258", "cp1252"):
            try:
                return {
                    "ok": True,
                    "message": "Loaded running-config backup.",
                    "path": str(backup_file),
                    "content": backup_file.read_text(encoding=encoding),
                }
            except UnicodeDecodeError:
                continue
            except OSError as exc:
                return {"ok": False, "message": str(exc), "path": str(backup_file), "content": ""}

        return {
            "ok": True,
            "message": "Loaded running-config backup with replacement characters.",
            "path": str(backup_file),
            "content": backup_file.read_text(encoding="utf-8", errors="replace"),
        }

    @pyqtSlot(str, str, str, int, result=bool)
    def addYangcfg(self, host: str, username: str, password: str, success: int) -> bool:
        try:
            with self._connect() as conn:
                conn.execute(
                    "INSERT INTO t01_yangcfg (host, username, password, success) VALUES (?, ?, ?, ?);",
                    ((host or "").strip(), username or None, password or None, success),
                )
                conn.execute("UPDATE t01_devices SET t01_yangcfg = 1 WHERE host = ?;", ((host or "").strip(),))
                conn.commit()
            return True
        except sqlite3.Error as exc:
            print(f"[db] addYangcfg failed: {exc}", file=sys.stderr)
            return False

    @pyqtSlot(str, result="QVariant")
    def getRoutingInfo(self, host: str) -> dict[str, Any]:
        host = (host or "").strip()
        if not host:
            return {"ok": False, "message": "Host is empty", "routes": []}
        try:
            with self._connect() as conn:
                rows = conn.execute(
                    """
                    SELECT id, host, vrf_name, protocol_code, protocol_name,
                           destination, prefix_length, administrative_distance,
                           metric, next_hop, route_age, exit_interface,
                           is_best, collected_at, raw_line
                    FROM t08_info_routing_table
                    WHERE host = ?
                    ORDER BY
                        is_best DESC,
                        vrf_name COLLATE NOCASE,
                        protocol_code COLLATE NOCASE,
                        destination COLLATE NOCASE,
                        prefix_length DESC,
                        id ASC;
                    """,
                    (host,),
                ).fetchall()
            routes: list[dict[str, Any]] = []
            for row in rows:
                routes.append(
                    {
                        "id": row["id"],
                        "host": row["host"] or "",
                        "vrf_name": row["vrf_name"] or "default",
                        "protocol_code": row["protocol_code"] or "",
                        "protocol_name": row["protocol_name"] or "",
                        "destination": row["destination"] or "",
                        "prefix_length": row["prefix_length"] if row["prefix_length"] is not None else "",
                        "administrative_distance": row["administrative_distance"] if row["administrative_distance"] is not None else "",
                        "metric": row["metric"] if row["metric"] is not None else "",
                        "next_hop": row["next_hop"] or "",
                        "route_age": row["route_age"] or "",
                        "exit_interface": row["exit_interface"] or "",
                        "is_best": row["is_best"] if row["is_best"] is not None else 0,
                        "collected_at": row["collected_at"] or "",
                        "raw_line": row["raw_line"] or "",
                    }
                )
            return {"ok": True, "message": "Loaded routing table info", "routes": _variant_list(routes)}
        except sqlite3.Error as exc:
            print(f"[db] getRoutingInfo failed: {exc}", file=sys.stderr)
            return {"ok": False, "message": str(exc), "routes": []}

    @pyqtSlot(str, result="QVariant")
    def getStaticRouting(self, host: str) -> dict[str, Any]:
        return get_static_routing(self, host)

    @pyqtSlot(str, str, "QVariant", result=bool)
    def saveStaticRouting(self, host: str, default_value: str, routes: Any) -> bool:
        self._set_last_routing_error("")
        ok = save_static_routing(self, host, default_value, routes)
        self._log("SUCCESS" if ok else "ERROR", f"Static routing configuration {'saved' if ok else 'failed'} for {(host or '').strip()}.", "CONFIGURATION", "routing")
        return ok

    @pyqtSlot(str, result="QVariant")
    def getOspfRouting(self, host: str) -> dict[str, Any]:
        return get_ospf_routing(self, host)

    @pyqtSlot(str, "QVariant", result=bool)
    def saveOspfRouting(self, host: str, payload: Any) -> bool:
        self._set_last_routing_error("")
        ok = save_ospf_routing(self, host, payload)
        self._log("SUCCESS" if ok else "ERROR", f"OSPF configuration {'saved' if ok else 'failed'} for {(host or '').strip()}.", "CONFIGURATION", "routing")
        return ok

    @pyqtSlot(str, result="QVariant")
    def getEigrpRouting(self, host: str) -> dict[str, Any]:
        return get_eigrp_routing(self, host)

    @pyqtSlot(str, "QVariant", result=bool)
    def saveEigrpRouting(self, host: str, payload: Any) -> bool:
        self._set_last_routing_error("")
        ok = save_eigrp_routing(self, host, payload)
        self._log("SUCCESS" if ok else "ERROR", f"EIGRP configuration {'saved' if ok else 'failed'} for {(host or '').strip()}.", "CONFIGURATION", "routing")
        return ok
