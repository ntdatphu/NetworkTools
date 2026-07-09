from __future__ import annotations

import json
import sys
from datetime import datetime
from pathlib import Path
from typing import Any
from urllib.parse import unquote, urlparse
from collections.abc import Sequence

from PyQt6.QtGui import QGuiApplication
from PyQt6.QtCore import QObject, pyqtProperty, pyqtSignal, pyqtSlot

from .runtime import APP_DIR


LOG_DIR = APP_DIR / "logs"
LOG_PATH = LOG_DIR / "app.log.jsonl"


class _AppLogStream:
    def __init__(self, logger: "AppLogger", status: str, source: str) -> None:
        self._logger = logger
        self._status = status
        self._source = source
        self._buffer = ""

    def write(self, text: str) -> int:
        self._buffer += text
        while "\n" in self._buffer:
            line, self._buffer = self._buffer.split("\n", 1)
            line = line.strip()
            if line:
                try:
                    self._logger.log(self._logger.status_for_message(line, self._status), line, self._source)
                except Exception:
                    pass
        return len(text)

    def flush(self) -> None:
        line = self._buffer.strip()
        if line:
            try:
                self._logger.log(self._logger.status_for_message(line, self._status), line, self._source)
            except Exception:
                pass
        self._buffer = ""


class AppLogger(QObject):
    logsChanged = pyqtSignal()

    STATUS_ORDER = {
        "DEBUG": 0,
        "INFO": 1,
        "SUCCESS": 2,
        "WARNING": 3,
        "ERROR": 4,
        "CRITICAL": 5,
    }
    CATEGORIES = {
        "ACTIVITY",
        "VALIDATION",
        "CONFIGURATION",
        "SYSTEM",
        "DEVELOPER",
    }

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._path = LOG_PATH
        self._session_started_at = datetime.now().astimezone().isoformat(timespec="seconds")
        self._logs: list[dict[str, Any]] = []
        self._is_logging = False
        self._load_existing_logs()

    def _load_existing_logs(self) -> None:
        if not self._path.exists():
            return

        logs: list[dict[str, Any]] = []
        try:
            for line in self._path.read_text(encoding="utf-8").splitlines():
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if isinstance(entry, dict):
                    logs.append(self._normalize_entry(entry))
        except OSError:
            return
        self._logs = logs

    def _normalize_entry(self, entry: dict[str, Any]) -> dict[str, Any]:
        status = str(entry.get("status") or "INFO").strip().upper()
        if status not in self.STATUS_ORDER:
            status = "INFO"
        source = str(entry.get("source") or "app")
        category = str(entry.get("category") or self.category_for_source(source)).strip().upper()
        if category not in self.CATEGORIES:
            category = "SYSTEM"
        return {
            "time": str(entry.get("time") or ""),
            "status": status,
            "category": category,
            "source": source,
            "message": str(entry.get("message") or ""),
        }

    def _entry_from_variant(self, value: Any) -> dict[str, Any] | None:
        if hasattr(value, "toVariant"):
            value = value.toVariant()
        if isinstance(value, dict):
            return self._normalize_entry(value)
        return None

    def _entries_from_variant(self, value: Any) -> list[dict[str, Any]]:
        if hasattr(value, "toVariant"):
            value = value.toVariant()
        if value is None:
            return []
        entry = self._entry_from_variant(value)
        if entry is not None:
            return [entry]
        if isinstance(value, Sequence) and not isinstance(value, (str, bytes, bytearray)):
            rows = []
            for item in value:
                entry = self._entry_from_variant(item)
                if entry is not None:
                    rows.append(entry)
            return rows
        return []

    def _file_url_to_path(self, value: str, suffix: str) -> Path:
        text = (value or "").strip()
        parsed = urlparse(text)
        if parsed.scheme == "file":
            path = unquote(parsed.path)
            if parsed.netloc:
                path = f"//{parsed.netloc}{path}"
            if sys.platform.startswith("win") and path.startswith("/") and len(path) > 2 and path[2] == ":":
                path = path[1:]
        else:
            path = text

        target = Path(path)
        if suffix and target.suffix.lower() != f".{suffix.lower()}":
            target = target.with_suffix(f".{suffix.lower()}")
        return target

    def _entry_key(self, entry: dict[str, Any]) -> tuple[str, str, str, str, str]:
        normalized = self._normalize_entry(entry)
        return (
            normalized["time"],
            normalized["status"],
            normalized["category"],
            normalized["source"],
            normalized["message"],
        )

    def _serialize_entries(self, entries: list[dict[str, Any]], output_format: str) -> str:
        if output_format.lower() == "json":
            return json.dumps(entries, ensure_ascii=False, indent=2)
        lines = []
        for entry in entries:
            item = self._normalize_entry(entry)
            lines.append(f"[{item['time']}] [{item['status']}] [{item['category']}] [{item['source']}] {item['message']}")
        return "\n".join(lines)

    def _append_entry(self, entry: dict[str, Any]) -> None:
        LOG_DIR.mkdir(parents=True, exist_ok=True)
        with self._path.open("a", encoding="utf-8") as file:
            file.write(json.dumps(entry, ensure_ascii=False) + "\n")

    @pyqtProperty("QVariantList", notify=logsChanged)
    def logs(self) -> list[dict[str, Any]]:
        return list(self._logs)

    @pyqtProperty(str, constant=True)
    def logPath(self) -> str:
        return str(self._path)

    @pyqtProperty(str, constant=True)
    def sessionStartedAt(self) -> str:
        return self._session_started_at

    @pyqtSlot(str, str)
    @pyqtSlot(str, str, str)
    @pyqtSlot(str, str, str, str)
    def log(self, status: str, message: str, source: str = "app", category: str = "") -> None:
        message = (message or "").strip()
        if not message:
            return
        if self._is_logging:
            return

        self._is_logging = True
        try:
            entry = self._normalize_entry(
                {
                    "time": datetime.now().astimezone().isoformat(timespec="seconds"),
                    "status": status,
                    "category": category or self.category_for_source(source),
                    "source": source,
                    "message": message,
                }
            )
            try:
                self._append_entry(entry)
            except OSError:
                return

            self._logs.append(entry)
            try:
                self.logsChanged.emit()
            except RuntimeError:
                pass
        finally:
            self._is_logging = False

    def category_for_source(self, source: str) -> str:
        normalized = (source or "").strip().lower()
        if normalized in {"qt", "qml", "python", "stderr"}:
            return "DEVELOPER"
        if normalized in {"validation", "device-validation"}:
            return "VALIDATION"
        if normalized in {"config", "configuration", "routing"}:
            return "CONFIGURATION"
        if normalized in {"devices", "device", "user"}:
            return "ACTIVITY"
        return "SYSTEM"

    def status_for_message(self, message: str, default_status: str) -> str:
        text = (message or "").strip().lower()
        if any(marker in text for marker in ("critical", "fatal")):
            return "CRITICAL"
        if any(marker in text for marker in ("[error]", " error", "failed", "failure", "exception", "timeout", "[fail]", "[x]")):
            return "ERROR"
        if any(marker in text for marker in ("warning", "[warn]")):
            return "WARNING"
        if any(marker in text for marker in ("success", "completed", "connected", "saved", "[ok]", "[success]")):
            return "SUCCESS"
        return default_status

    @pyqtSlot()
    def refresh(self) -> None:
        self._load_existing_logs()
        self.logsChanged.emit()

    @pyqtSlot("QVariant", result=bool)
    def copyEntries(self, entries: Any) -> bool:
        rows = self._entries_from_variant(entries)
        clipboard = QGuiApplication.clipboard()
        if clipboard is None:
            return False
        clipboard.setText(self._serialize_entries(rows, "txt"))
        return True

    @pyqtSlot(str, "QVariant", str, result="QVariant")
    def exportEntries(self, file_url: str, entries: Any, output_format: str) -> dict[str, Any]:
        rows = self._entries_from_variant(entries)
        file_format = "json" if str(output_format).lower() == "json" else "txt"
        target = self._file_url_to_path(file_url, file_format)
        try:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(self._serialize_entries(rows, file_format), encoding="utf-8")
        except OSError as exc:
            return {"ok": False, "message": str(exc), "path": str(target)}
        return {"ok": True, "message": f"Exported {len(rows)} item(s).", "path": str(target)}

    @pyqtSlot(str, result="QVariant")
    def clearSection(self, section: str) -> dict[str, Any]:
        mode = (section or "logs").strip().lower()
        if mode == "alerts":
            alert_statuses = {"WARNING", "ERROR", "CRITICAL"}
            kept = [entry for entry in self._logs if self._normalize_entry(entry)["status"] not in alert_statuses]
            removed = len(self._logs) - len(kept)
        else:
            kept = []
            removed = len(self._logs)

        try:
            LOG_DIR.mkdir(parents=True, exist_ok=True)
            with self._path.open("w", encoding="utf-8") as file:
                for entry in kept:
                    file.write(json.dumps(self._normalize_entry(entry), ensure_ascii=False) + "\n")
        except OSError as exc:
            return {"ok": False, "message": str(exc), "removed": 0}

        self._logs = kept
        self.logsChanged.emit()
        return {"ok": True, "message": f"Cleared {removed} item(s).", "removed": removed}

    @pyqtSlot("QVariant", result="QVariant")
    def clearEntries(self, entries: Any) -> dict[str, Any]:
        rows = self._entries_from_variant(entries)
        if not rows:
            return {"ok": True, "message": "No visible items to clear.", "removed": 0}

        targets = {self._entry_key(entry) for entry in rows}
        kept = [entry for entry in self._logs if self._entry_key(entry) not in targets]
        removed = len(self._logs) - len(kept)
        try:
            LOG_DIR.mkdir(parents=True, exist_ok=True)
            with self._path.open("w", encoding="utf-8") as file:
                for entry in kept:
                    file.write(json.dumps(self._normalize_entry(entry), ensure_ascii=False) + "\n")
        except OSError as exc:
            return {"ok": False, "message": str(exc), "removed": 0}

        self._logs = kept
        self.logsChanged.emit()
        return {"ok": True, "message": f"Cleared {removed} visible item(s).", "removed": removed}

    def install_stdio_redirect(self) -> None:
        sys.stdout = _AppLogStream(self, "INFO", "stdout")  # type: ignore[assignment]
        sys.stderr = _AppLogStream(self, "ERROR", "stderr")  # type: ignore[assignment]
