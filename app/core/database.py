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

from PyQt6.QtCore import QObject, QThread, pyqtSignal, pyqtSlot

from .background_task import BackgroundTask
from .runtime import APP_DIR, DB_PATH, SQL_PATH
from .database_paths import require_database
from .view_push import ViewPushControllerFactory

from features.routing import (
    get_eigrp_routing,
    get_ospf_routing,
    get_static_routing,
    save_eigrp_routing,
    save_ospf_routing,
    save_static_routing,
)

from .dhcp_slots import DhcpSlotsMixin
from .acl_slots import AclSlotsMixin
from .nat_slots import NatSlotsMixin
from .switch_slots import SwitchSlotsMixin
from .database_stubs import StubSlotsMixin


def _variant_list(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return rows


def _clean_display_text(value: Any) -> str:
    return "".join(ch for ch in str(value or "") if ch.isprintable()).strip().strip("\"'`#> ")


class DatabaseManager(
    DhcpSlotsMixin,
    AclSlotsMixin,
    NatSlotsMixin,
    SwitchSlotsMixin,
    StubSlotsMixin,
    QObject,
):
    taskStarted = pyqtSignal(str)
    taskProgress = pyqtSignal(str)
    taskFinished = pyqtSignal(bool, str)
    viewPushPreviewFinished = pyqtSignal(str, str, str, bool, str, str)
    viewPushFinished = pyqtSignal(str, str, str, bool, str)

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self.app_dir = APP_DIR
        self.db_path = DB_PATH
        self.sql_path = SQL_PATH
        self._last_routing_error = ""
        self._background_tasks: dict[str, dict[str, Any]] = {}
        self.initializeDatabase()
        self._view_push = ViewPushControllerFactory(self)

    def _start_background_task(
        self,
        task_key: str,
        controller_name: str,
        host: str,
        module_name: str,
        start_message: str,
        callback: Any,
        operation: str = "push",
    ) -> bool:
        if task_key in self._background_tasks:
            message = f"A push task is already running for {host}."
            self.taskFinished.emit(False, message)
            return False

        thread = QThread(self)
        worker = BackgroundTask(task_key, start_message, callback)
        worker.moveToThread(thread)
        self._background_tasks[task_key] = {
            "thread": thread,
            "worker": worker,
            "controller": controller_name,
            "host": host,
            "module": module_name,
            "operation": operation,
        }

        thread.started.connect(worker.run)
        worker.taskStarted.connect(self._relay_task_started)
        worker.taskProgress.connect(self._relay_task_progress)
        worker.taskFinished.connect(self._handle_background_task_finished)
        worker.taskFinished.connect(lambda *_args, t=thread: t.quit())
        worker.taskFinished.connect(lambda *_args, w=worker: w.deleteLater())
        thread.finished.connect(thread.deleteLater)
        thread.start()
        return True

    @pyqtSlot(str)
    def _relay_task_started(self, message: str) -> None:
        self.taskStarted.emit(message)

    @pyqtSlot(str)
    def _relay_task_progress(self, message: str) -> None:
        self.taskProgress.emit(message)

    @pyqtSlot(str, bool, str, object)
    def _handle_background_task_finished(self, task_key: str, ok: bool, message: str, result: object) -> None:
        entry = self._background_tasks.pop(task_key, {})
        controller = str(entry.get("controller") or "")
        host = str(entry.get("host") or "")
        module = str(entry.get("module") or "")
        operation = str(entry.get("operation") or "push")
        if operation == "preview":
            commands = str(result.get("commands") or "") if isinstance(result, dict) else ""
            self.viewPushPreviewFinished.emit(controller, host, module, ok, message, commands)
        else:
            self.viewPushFinished.emit(controller, host, module, ok, message)
        self.taskFinished.emit(ok, message)

    def _connect(self) -> sqlite3.Connection:
        """Mở kết nối SQLite chính và bật foreign key cho các thao tác DB."""
        conn = sqlite3.connect(require_database(self.db_path), timeout=10.0)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA foreign_keys = ON;")
        conn.execute("PRAGMA busy_timeout = 10000;")
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
        return [{k: ("" if v is None else v) for k, v in dict(row).items()} for row in rows]

    def _set_last_routing_error(self, message: str) -> None:
        self._last_routing_error = (message or "").strip()

    def _sync_worker_paths(self) -> None:
        """Synchronize the compatibility worker config with this manager."""
        from infrastructure.network import config

        config.DB_PATH = str(self.db_path.resolve())
        config.MAIN_SQL = str(self.sql_path.resolve())

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
        """Chuẩn hóa một dòng import thiết bị trước khi ghi vào DB."""
        row = {self._normalize_import_key(key): value for key, value in raw.items()}
        method = str(row.get("method") or "SSH").strip().upper()
        default_port = 23 if method == "TELNET" else 830 if method == "NETCONF" else 443 if method == "RESTCONF" else 22
        role = str(row.get("role") or "").strip()
        device_type = str(row.get("type") or row.get("device_type") or role or "unknown").strip() or "unknown"
        return {
            "lineNumber": line_number,
            "host": str(row.get("host") or "").strip(),
            "name": _clean_display_text(row.get("name")),
            "method": method,
            "port": self._int_or_none(row.get("portnumber")) or default_port,
            "username": str(row.get("username") or "").strip(),
            "password": str(row.get("password") or "").strip(),
            "os": str(row.get("os") or "cisco_ios").strip() or "cisco_ios",
            "role": role,
            "type": device_type,
        }

    def _read_json_import_rows(self, path: Path) -> list[dict[str, Any]]:
        """Đọc danh sách thiết bị từ file JSON import."""
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
        """Đọc danh sách thiết bị từ file Excel import."""
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
        """Import thiết bị từ file và ghi các bản ghi mới vào t01_devices."""
        if not path.exists():
            return {"ok": False, "message": f"File not found: {path}", "added": 0, "skipped": 0}

        suffix = path.suffix.lower()
        if suffix == ".json":
            rows = self._read_json_import_rows(path)
        elif suffix == ".xlsx":
            rows = self._read_xlsx_import_rows(path)
        else:
            return {"ok": False, "message": "Only .xlsx and .json imports are supported.", "added": 0, "skipped": 0}

        if not rows:
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
                        (host, device_name, method, portnumber, username, password, os, role, success, dev, device_type)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, 0, ?);
                    """,
                    (
                        row["host"],
                        _clean_display_text(row["name"]) or None,
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

        folders_ok = self.createFoldersFromDevices()
        message = f"Imported {added}/{len(rows)} devices. Skipped: {skipped}."
        if added > 0 and not folders_ok:
            message += " Backup folder creation failed."
        return {"ok": added > 0, "message": message, "added": added, "skipped": skipped, "foldersOk": folders_ok}

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
        """Render thử cấu hình routing từ DB mà không push xuống thiết bị."""
        host = (host or "").strip()
        if not host:
            return {"ok": False, "message": "Host is empty.", "commands": "", "tasks": []}

        try:
            self._sync_worker_paths()
            from features.routing.dispatcher import routing_dispatcher
            from features.routing.worker import render_routing_config

            module = self._routing_module(module_name)
            tasks = routing_dispatcher(target_ip=host, target_module=module, dry_run=True) or []
            if not tasks:
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

            return {
                "ok": True,
                "message": f"Prepared {len(tasks)} routing task(s).",
                "commands": "\n".join(rendered).strip(),
                "tasks": _variant_list(tasks),
            }
        except Exception as exc:
            message = f"Preview routing failed: {exc}"
            self._set_last_routing_error(message)
            print(f"[db] {message}", file=sys.stderr)
            return {"ok": False, "message": message, "commands": "", "tasks": []}

    @pyqtSlot(str, str, result="QVariant")
    def pushRoutingConfig(self, host: str, module_name: str) -> dict[str, Any]:
        """Push cấu hình routing pending xuống thiết bị hoặc luồng dev tương ứng."""
        host = (host or "").strip()
        if not host:
            return {"ok": False, "message": "Host is empty.", "report": []}

    @pyqtSlot(str, str, str, result=bool)
    def hasPendingViewPush(self, controller_name: str, host: str, module_name: str) -> bool:
        try:
            return self._view_push.get(controller_name).has_pending(host, module_name)
        except Exception as exc:
            print(f"[db] hasPendingViewPush failed: {exc}", file=sys.stderr)
            return False

    @pyqtSlot(str, str, str, result="QVariant")
    def previewViewPush(self, controller_name: str, host: str, module_name: str) -> dict[str, Any]:
        try:
            return self._view_push.get(controller_name).preview(host, module_name)
        except Exception as exc:
            message = f"Preview {controller_name} failed: {exc}"
            if (controller_name or "").strip().lower() == "routing":
                self._set_last_routing_error(message)
            print(f"[db] {message}", file=sys.stderr)
            return {"ok": False, "message": message, "commands": "", "tasks": []}

    @pyqtSlot(str, str, str, result=bool)
    def previewViewPushAsync(self, controller_name: str, host: str, module_name: str) -> bool:
        controller = (controller_name or "").strip().lower()
        target_host = (host or "").strip()
        module = (module_name or "all").strip().lower() or "all"
        if not controller or not target_host:
            message = "Preview failed: controller or host is empty."
            self.viewPushPreviewFinished.emit(controller, target_host, module, False, message, "")
            self.taskFinished.emit(False, message)
            return False

        task_key = f"view-preview:{controller}:{target_host}:{module}"
        start_message = f"Preparing {controller.upper()} configuration preview for {target_host}..."

        def run_preview(progress: Any) -> dict[str, Any]:
            progress(f"Rendering {controller.upper()} template for {target_host}...")
            result = self.previewViewPush(controller, target_host, module)
            progress(f"Finished {controller.upper()} preview for {target_host}.")
            return result

        return self._start_background_task(
            task_key,
            controller,
            target_host,
            module,
            start_message,
            run_preview,
            "preview",
        )

    @pyqtSlot(str, str, str, result="QVariant")
    def pushViewPush(self, controller_name: str, host: str, module_name: str) -> dict[str, Any]:
        try:
            return self._view_push.get(controller_name).push(host, module_name)
        except Exception as exc:
            message = f"Push {controller_name} failed: {exc}"
            if (controller_name or "").strip().lower() == "routing":
                self._set_last_routing_error(message)
            print(f"[db] {message}", file=sys.stderr)
            return {"ok": False, "message": message, "report": []}

    @pyqtSlot(str, str, str, result=bool)
    def pushViewPushAsync(self, controller_name: str, host: str, module_name: str) -> bool:
        controller = (controller_name or "").strip().lower()
        target_host = (host or "").strip()
        module = (module_name or "all").strip().lower() or "all"
        if not controller or not target_host:
            message = "Push failed: controller or host is empty."
            self.viewPushFinished.emit(controller, target_host, module, False, message)
            self.taskFinished.emit(False, message)
            return False

        task_key = f"view-push:{controller}:{target_host}:{module}"
        start_message = f"Pushing {controller.upper()} configuration to {target_host}..."

        def run_push(progress: Any) -> dict[str, Any]:
            progress(f"Rendering {controller.upper()} configuration for {target_host}...")
            result = self.pushViewPush(controller, target_host, module)
            progress(f"Finished {controller.upper()} push for {target_host}.")
            return result

        return self._start_background_task(
            task_key,
            controller,
            target_host,
            module,
            start_message,
            run_push,
        )

    @pyqtSlot(str, result="QVariant")
    def previewDhcpConfig(self, host: str) -> dict[str, Any]:
        return self.previewViewPush("dhcp", host, "all")

    @pyqtSlot(str, result="QVariant")
    def pushDhcpConfig(self, host: str) -> dict[str, Any]:
        return self.pushViewPush("dhcp", host, "all")

    @pyqtSlot(result=bool)
    def initializeDatabase(self) -> bool:
        """Kiểm tra database chính thức; schema chỉ do database builder tạo."""
        try:
            require_database(self.db_path)
            with self._connect() as conn:
                required = {"t01_devices", "t02_interface_name", "t04_ospf_processes", "t04_eigrp_processes"}
                present = {
                    row["name"]
                    for row in conn.execute("SELECT name FROM sqlite_master WHERE type = 'table';")
                }
                missing = sorted(required - present)
                if missing:
                    raise RuntimeError(f"Database schema is incomplete; missing tables: {', '.join(missing)}")
            self._sync_worker_paths()
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
        """Thêm một thiết bị mới từ UI vào bảng t01_devices."""
        host = (host or "").strip()
        if not host:
            return False
        try:
            port = int(port_text) if str(port_text).strip() else None
        except ValueError:
            return False
        if port is not None and not 1 <= port <= 65535:
            return False
        try:
            with self._connect() as conn:
                conn.execute(
                    """
                    INSERT INTO t01_devices
                        (host, device_name, method, portnumber, username, password, os, role, success, dev, device_type)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, 0, ?);
                    """,
                    (
                        host,
                        _clean_display_text(device_name) or None,
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
            return True
        except sqlite3.IntegrityError:
            return False
        except sqlite3.Error as exc:
            print(f"[db] addDevice failed: {exc}", file=sys.stderr)
            return False

    @pyqtSlot(str, result="QVariant")
    def importDevicesFromFile(self, file_url: str) -> dict[str, Any]:
        """Nhận file từ QML và import danh sách thiết bị vào DB."""
        try:
            return self._import_devices_from_path(self._file_url_to_path(file_url))
        except Exception as exc:
            print(f"[db] importDevicesFromFile failed: {exc}", file=sys.stderr)
            return {"ok": False, "message": str(exc), "added": 0, "skipped": 0}

    @pyqtSlot(str, result="QVariant")
    def saveDeviceImportSample(self, file_url: str) -> dict[str, Any]:
        try:
            source = self.app_dir / "template" / "EXdevices.xlsx"
            if not source.exists():
                return {"ok": False, "message": f"Sample file not found: {source}"}

            target = self._file_url_to_path(file_url)
            if target.suffix.lower() != ".xlsx":
                target = target.with_suffix(".xlsx")
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
            return {"ok": True, "message": f"Saved sample Excel file:\n{target}"}
        except Exception as exc:
            print(f"[db] saveDeviceImportSample failed: {exc}", file=sys.stderr)
            return {"ok": False, "message": str(exc)}

    @pyqtSlot(str, result="QVariant")
    def deleteDevice(self, host: str) -> dict[str, Any]:
        target_host = (host or "").strip()
        if not target_host:
            return {"ok": False, "severity": "warning", "message": "Delete device failed: host is empty."}
        try:
            with self._connect() as conn:
                cursor = conn.execute("DELETE FROM t01_devices WHERE host = ?;", (target_host,))
                conn.commit()
            if cursor.rowcount <= 0:
                message = f"Delete device failed for {target_host}: no database row was deleted."
                return {"ok": False, "severity": "error", "message": message}

            message = f"Device {target_host} deleted."
            return {"ok": True, "severity": "success", "message": message}
        except sqlite3.Error as exc:
            message = f"Delete device failed for {target_host}: {exc}"
            print(f"[db] deleteDevice failed: {exc}", file=sys.stderr)
            return {"ok": False, "severity": "error", "message": message}

    @pyqtSlot(str, int, result=bool)
    def updateDeviceSuccess(self, host: str, success: int) -> bool:
        """Cập nhật cờ success của thiết bị trong DB."""
        target_host = (host or "").strip()
        if not target_host:
            return False
        try:
            with self._connect() as conn:
                cursor = conn.execute("UPDATE t01_devices SET success = ? WHERE host = ?;", (success, target_host))
                conn.commit()
            if cursor.rowcount <= 0:
                return False
            return True
        except sqlite3.Error as exc:
            print(f"[db] updateDeviceSuccess failed: {exc}", file=sys.stderr)
            return False

    @pyqtSlot(str, result="QVariant")
    def resetDeviceToWaiting(self, host: str) -> dict[str, Any]:
        """Reset thiết bị disconnected về waiting để cho phép kết nối lại."""
        target_host = (host or "").strip()
        if not target_host:
            return {"ok": False, "message": "Host is empty.", "severity": "warning"}
        try:
            with self._connect() as conn:
                cursor = conn.execute(
                    "UPDATE t01_devices SET success = 0, dev = 0 WHERE host = ?;",
                    (target_host,)
                )
                conn.commit()
                if cursor.rowcount == 0:
                    return {"ok": False, "message": f"Device {target_host} not found.", "severity": "error"}
                return {"ok": True, "message": f"Device {target_host} reset to Waiting.", "severity": "success"}
        except Exception as e:
            return {"ok": False, "message": str(e), "severity": "error"}

    @pyqtSlot(str, int, result=bool)
    def updateDeviceDev(self, host: str, dev: int) -> bool:
        """Cập nhật cờ dev để đưa thiết bị vào hoặc ra khỏi luồng xử lý dev."""
        target_host = (host or "").strip()
        if not target_host:
            return False
        try:
            with self._connect() as conn:
                cursor = conn.execute("UPDATE t01_devices SET dev = ? WHERE host = ?;", (1 if dev else 0, target_host))
                conn.commit()
            if cursor.rowcount <= 0:
                return False
            return True
        except sqlite3.Error as exc:
            print(f"[db] updateDeviceDev failed: {exc}", file=sys.stderr)
            return False

    @pyqtSlot(str, int, int, result="QVariant")
    def setDeviceDevState(self, host: str, dev: int, success: int) -> dict[str, Any]:
        target_host = (host or "").strip()
        dev_value = 1 if dev else 0
        success_value = 1 if success else 0
        action_name = "Up (Dev)" if dev_value else "Down (Dev)"
        if not target_host:
            return {"ok": False, "severity": "warning", "message": f"{action_name} failed: host is empty."}

        try:
            with self._connect() as conn:
                cursor = conn.execute(
                    "UPDATE t01_devices SET dev = ?, success = ? WHERE host = ?;",
                    (dev_value, success_value, target_host),
                )
                conn.commit()
            if cursor.rowcount <= 0:
                return {
                    "ok": False,
                    "severity": "error",
                    "message": f"{action_name} failed for {target_host}: device was not found.",
                }
            return {
                "ok": True,
                "severity": "success",
                "message": f"{action_name} applied for {target_host}.",
            }
        except sqlite3.Error as exc:
            print(f"[db] setDeviceDevState failed: {exc}", file=sys.stderr)
            return {"ok": False, "severity": "error", "message": f"{action_name} failed for {target_host}: {exc}"}

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
        """Cập nhật thông tin kết nối và phân loại thiết bị trong DB."""
        target_host = (host or "").strip()
        if not target_host:
            return False
        try:
            port = int(port_text) if str(port_text).strip() else None
        except ValueError:
            return False
        if port is not None and not 1 <= port <= 65535:
            return False
        try:
            with self._connect() as conn:
                row = conn.execute(
                    "SELECT host FROM t01_devices WHERE host = ?;",
                    (target_host,),
                ).fetchone()
                if row is None:
                    return False

                cursor = conn.execute(
                    """
                    UPDATE t01_devices
                    SET device_name = ?, method = ?, portnumber = ?, username = ?, password = ?,
                        os = ?, role = ?, device_type = ?
                    WHERE host = ?;
                    """,
                    (
                        _clean_display_text(device_name) or None,
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
            if cursor.rowcount <= 0:
                return False
            return True
        except sqlite3.Error as exc:
            print(f"[db] updateDevice failed: {exc}", file=sys.stderr)
            return False

    @pyqtSlot(str, result="QVariant")
    def getDeviceByHost(self, host: str) -> dict[str, Any]:
        """Đọc chi tiết một thiết bị từ DB để trả về cho QML."""
        try:
            with self._connect() as conn:
                row = conn.execute(
                    """
                    SELECT host, device_name, method, portnumber, username, password, os, role, device_type, dev
                    FROM t01_devices
                    WHERE host = ?;
                    """,
                    ((host or "").strip(),),
                ).fetchone()
            if row is None:
                return {}
            return {
                "ip": row["host"],
                "name": _clean_display_text(row["device_name"]),
                "protocol": row["method"] or "SSH",
                "port": "" if row["portnumber"] is None else str(row["portnumber"]),
                "user": row["username"] or "",
                "pass": row["password"] or "",
                "os": row["os"] or "cisco_ios",
                "role": row["role"] or "",
                "type": row["device_type"] or "unknown",
                "dev": row["dev"] if row["dev"] is not None else 0,
            }
        except sqlite3.Error as exc:
            print(f"[db] getDeviceByHost failed: {exc}", file=sys.stderr)
            return {}

    @pyqtSlot(result="QVariant")
    def getDevices(self) -> list[dict[str, Any]]:
        """Đọc danh sách thiết bị để hiển thị trên panel QML."""
        try:
            with self._connect() as conn:
                rows = conn.execute(
                    """
                    SELECT host, device_name, success, role, device_type
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
                name = _clean_display_text(row["device_name"]) or row["host"]
                role = (row["role"] or "").strip().lower()
                device_type = (
                    role
                    if role in {"sw2", "sw3"}
                    else (row["device_type"] or "unknown").strip() or "unknown"
                )
                out.append(
                    {
                        "name": name,
                        "ip": row["host"],
                        "status": status,
                        "role": role,
                        "type": device_type,
                    }
                )
            return _variant_list(out)
        except sqlite3.Error as exc:
            print(f"[db] getDevices failed: {exc}", file=sys.stderr)
            return []

    @pyqtSlot(result=bool)
    def createFoldersFromDevices(self) -> bool:
        """Tạo thư mục backup tương ứng với các thiết bị đang hoạt động."""
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
        """Đọc file running-config backup của thiết bị để trả về UI."""
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
        """Ghi thông tin YANG config và bật cờ t01_yangcfg cho thiết bị."""
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
        """Đọc bảng routing đã thu thập từ DB cho một thiết bị."""
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
        return ok

    @pyqtSlot(str, result="QVariant")
    def getOspfRouting(self, host: str) -> dict[str, Any]:
        return get_ospf_routing(self, host)

    @pyqtSlot(str, "QVariant", result=bool)
    def saveOspfRouting(self, host: str, payload: Any) -> bool:
        self._set_last_routing_error("")
        ok = save_ospf_routing(self, host, payload)
        return ok

    @pyqtSlot(str, result="QVariant")
    def getEigrpRouting(self, host: str) -> dict[str, Any]:
        return get_eigrp_routing(self, host)

    @pyqtSlot(str, "QVariant", result=bool)
    def saveEigrpRouting(self, host: str, payload: Any) -> bool:
        self._set_last_routing_error("")
        ok = save_eigrp_routing(self, host, payload)
        return ok
