from __future__ import annotations

import posixpath
import threading
import uuid
from pathlib import Path

from PyQt6.QtCore import (
    QObject,
    QThreadPool,
    QUrl,
    pyqtProperty,
    pyqtSignal,
    pyqtSlot,
)

from .file_model import FileListModel
from .local_service import LocalFileService
from .sftp_service import ConnectionOptions, SftpService
from .transfer_model import TransferItem, TransferModel
from .workers import OperationWorker


class TransferCancelled(RuntimeError):
    pass


def valid_entry_name(value: str) -> bool:
    name = str(value or "").strip()
    return bool(name) and name not in {".", ".."} and "/" not in name and "\\" not in name


class SftpController(QObject):
    """Single QML-facing API; all blocking filesystem/network I/O is off-thread."""

    connectedChanged = pyqtSignal()
    busyChanged = pyqtSignal()
    localPathChanged = pyqtSignal()
    remotePathChanged = pyqtSignal()
    statusMessageChanged = pyqtSignal()
    errorOccurred = pyqtSignal(str)
    logMessage = pyqtSignal(str, str)
    hostKeyConfirmationRequired = pyqtSignal(str, str, str)
    _transferProgress = pyqtSignal(str, int, int)

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._local_service = LocalFileService()
        self._sftp_service = SftpService()
        self._local_model = FileListModel(self)
        self._remote_model = FileListModel(self)
        self._transfer_model = TransferModel(self)
        self._pool = QThreadPool(self)
        # Paramiko SFTPClient is not thread-safe, so remote I/O is serialized.
        self._pool.setMaxThreadCount(1)
        self._pending = 0
        self._connected = False
        self._local_path = self._local_service.home_path()
        self._remote_path = "/"
        self._status_message = "SFTP disconnected"
        self._cancel_events: dict[str, threading.Event] = {}
        self._pending_connection: ConnectionOptions | None = None
        self._shutting_down = False
        self._transferProgress.connect(self._on_transfer_progress)
        self.refreshLocal()

    @pyqtProperty(QObject, constant=True)
    def localModel(self) -> QObject:
        return self._local_model

    @pyqtProperty(QObject, constant=True)
    def remoteModel(self) -> QObject:
        return self._remote_model

    @pyqtProperty(QObject, constant=True)
    def transferModel(self) -> QObject:
        return self._transfer_model

    @pyqtProperty(bool, notify=connectedChanged)
    def connected(self) -> bool:
        return self._connected

    @pyqtProperty(bool, notify=busyChanged)
    def busy(self) -> bool:
        return self._pending > 0

    @pyqtProperty(str, notify=localPathChanged)
    def localPath(self) -> str:
        return self._local_path

    @pyqtProperty(str, notify=remotePathChanged)
    def remotePath(self) -> str:
        return self._remote_path

    @pyqtProperty(str, notify=statusMessageChanged)
    def statusMessage(self) -> str:
        return self._status_message

    def _set_connected(self, value: bool) -> None:
        if self._connected != value:
            self._connected = value
            self.connectedChanged.emit()

    def _set_local_path(self, value: str) -> None:
        if self._local_path != value:
            self._local_path = value
            self.localPathChanged.emit()

    def _set_remote_path(self, value: str) -> None:
        if self._remote_path != value:
            self._remote_path = value
            self.remotePathChanged.emit()

    def _set_status(self, value: str) -> None:
        if self._status_message != value:
            self._status_message = value
            self.statusMessageChanged.emit()

    def _start(self, operation: str, function) -> None:
        if self._shutting_down:
            return
        worker = OperationWorker(operation, function)
        worker.signals.completed.connect(self._operation_completed)
        worker.signals.failed.connect(self._operation_failed)
        was_busy = self.busy
        self._pending += 1
        if not was_busy:
            self.busyChanged.emit()
        self._pool.start(worker)

    def _finish_pending(self) -> None:
        was_busy = self.busy
        self._pending = max(0, self._pending - 1)
        if was_busy != self.busy:
            self.busyChanged.emit()

    @pyqtSlot(str, int, str, str, str)
    def connectServer(
        self,
        host: str,
        port: int,
        username: str,
        password: str,
        key_url: str,
    ) -> None:
        host, username = host.strip(), username.strip()
        if not host or not username or not 1 <= port <= 65535:
            self._report_error("Host, username, and a valid port are required")
            return
        key_path = self._url_to_path(key_url) if key_url else ""
        options = ConnectionOptions(host, port, username, password, key_path)
        self._pending_connection = options
        self._set_status(f"Connecting to {host}:{port}...")
        self.logMessage.emit(self._status_message, "info")
        self._start(
            "connect",
            lambda: (self._sftp_service.connect(options), host, port),
        )

    @pyqtSlot(bool)
    def confirmHostKey(self, accepted: bool) -> None:
        info = self._sftp_service.pending_host_key
        options = self._pending_connection
        if not accepted or not info or options is None:
            self._pending_connection = None
            self._set_status("Connection to the untrusted server was cancelled")
            self.logMessage.emit(self._status_message, "warning")
            return
        fingerprint = info["fingerprint"]
        self._set_status(f"Verifying the host key for {options.host}...")
        self._start(
            "connect",
            lambda: (
                self._sftp_service.connect(options, fingerprint),
                options.host,
                options.port,
            ),
        )

    @pyqtSlot()
    def disconnectServer(self) -> None:
        if not self._connected:
            return
        self._set_status("Disconnecting...")
        self._start("disconnect", self._sftp_service.disconnect)

    @pyqtSlot()
    def refreshLocal(self) -> None:
        path = self._local_path
        self._start("local:list", lambda: (path, self._local_service.list_directory(path)))

    @pyqtSlot(str)
    def openLocalDirectory(self, path: str) -> None:
        try:
            normalized = self._local_service.normalize(self._url_to_path(path))
        except Exception as exc:
            self._report_error(str(exc))
            return
        self._set_local_path(normalized)
        self.refreshLocal()

    @pyqtSlot()
    def localGoUp(self) -> None:
        self.openLocalDirectory(self._local_service.parent(self._local_path))

    @pyqtSlot()
    def refreshRemote(self) -> None:
        if not self._connected:
            return
        path = self._remote_path
        self._start("remote:list", lambda: (path, self._sftp_service.list_directory(path)))

    @pyqtSlot(str)
    def openRemoteDirectory(self, path: str) -> None:
        if self._connected:
            self._start("remote:open", lambda: self._sftp_service.normalize(path))

    @pyqtSlot()
    def remoteGoUp(self) -> None:
        parent = posixpath.dirname(self._remote_path.rstrip("/")) or "/"
        self.openRemoteDirectory(parent)

    @pyqtSlot(int)
    def uploadFile(self, row: int) -> None:
        item = self._local_model.get(row)
        if self._connected and item:
            self._queue_transfer("upload", item["path"], self._remote_path, item["name"])

    @pyqtSlot(int)
    def downloadFile(self, row: int) -> None:
        item = self._remote_model.get(row)
        if self._connected and item:
            self._queue_transfer(
                "download", item["path"], self._local_path, item["name"]
            )

    @pyqtSlot("QVariant")
    def uploadEntries(self, rows) -> None:
        for row in self._normalize_rows(rows):
            self.uploadFile(row)

    @pyqtSlot("QVariant")
    def downloadEntries(self, rows) -> None:
        for row in self._normalize_rows(rows):
            self.downloadFile(row)

    @staticmethod
    def _normalize_rows(rows) -> list[int]:
        if hasattr(rows, "toVariant"):
            rows = rows.toVariant()
        if not isinstance(rows, (list, tuple)):
            return []
        normalized: list[int] = []
        for value in rows:
            try:
                row = int(value)
            except (TypeError, ValueError):
                continue
            if row >= 0 and row not in normalized:
                normalized.append(row)
        return normalized

    def _queue_transfer(
        self, direction: str, source: str, destination: str, name: str
    ) -> None:
        task_id = uuid.uuid4().hex
        cancel_event = threading.Event()
        self._cancel_events[task_id] = cancel_event
        self._transfer_model.add(TransferItem(task_id, name, direction))

        def progress(current: int, total: int) -> None:
            if cancel_event.is_set():
                raise TransferCancelled("Transfer cancelled")
            self._transferProgress.emit(task_id, current, total)

        def transfer() -> str:
            if cancel_event.is_set():
                raise TransferCancelled("Transfer cancelled")
            if direction == "upload":
                self._sftp_service.upload(source, destination, progress)
            else:
                self._sftp_service.download(source, destination, progress)
            return task_id

        self.logMessage.emit(f"Queued {direction}: {name}", "info")
        self._start(f"transfer:{task_id}:{direction}", transfer)

    @pyqtSlot(str)
    def cancelTransfer(self, task_id: str) -> None:
        event = self._cancel_events.get(task_id)
        if event is not None:
            event.set()
            self._transfer_model.update(task_id, status="Cancelling")

    @pyqtSlot(bool, str)
    def createDirectory(self, remote: bool, name: str) -> None:
        if not valid_entry_name(name):
            self._report_error("Invalid folder name")
            return
        clean_name = name.strip()
        if remote:
            if self._connected:
                self._start(
                    "remote:mutate",
                    lambda: self._sftp_service.create_directory(
                        self._remote_path, clean_name
                    ),
                )
        else:
            self._start(
                "local:mutate",
                lambda: self._local_service.create_directory(
                    self._local_path, clean_name
                ),
            )

    @pyqtSlot(bool, int, str)
    def renameEntry(self, remote: bool, row: int, new_name: str) -> None:
        model = self._remote_model if remote else self._local_model
        item = model.get(row)
        if not item:
            return
        if not valid_entry_name(new_name):
            self._report_error("Invalid entry name")
            return
        clean_name = new_name.strip()
        if remote:
            self._start(
                "remote:mutate",
                lambda: self._sftp_service.rename(item["path"], clean_name),
            )
        else:
            self._start(
                "local:mutate",
                lambda: self._local_service.rename(item["path"], clean_name),
            )

    @pyqtSlot(bool, int)
    def deleteEntry(self, remote: bool, row: int) -> None:
        model = self._remote_model if remote else self._local_model
        item = model.get(row)
        if not item:
            return
        if remote:
            self._start(
                "remote:mutate",
                lambda: self._sftp_service.delete(
                    item["path"], item["isDirectory"]
                ),
            )
        else:
            self._start(
                "local:mutate",
                lambda: self._local_service.delete(item["path"]),
            )

    @pyqtSlot(str, object)
    def _operation_completed(self, operation: str, result) -> None:
        self._finish_pending()
        if self._shutting_down:
            return
        if operation == "connect":
            path, host, port = result
            self._pending_connection = None
            self._set_connected(True)
            self._set_remote_path(path)
            self._set_status(f"Connected to {host}:{port}")
            self.logMessage.emit(self._status_message, "success")
            self.refreshRemote()
        elif operation == "disconnect":
            self._set_connected(False)
            self._remote_model.clear()
            self._set_status("SFTP disconnected")
            self.logMessage.emit(self._status_message, "info")
        elif operation == "local:list":
            if result[0] == self._local_path:
                self._local_model.set_items(result[1])
        elif operation == "remote:list":
            if result[0] == self._remote_path:
                self._remote_model.set_items(result[1])
        elif operation == "remote:open":
            self._set_remote_path(result)
            self.refreshRemote()
        elif operation.startswith("transfer:"):
            task_id = result
            self._cancel_events.pop(task_id, None)
            self._transfer_model.update(task_id, status="Completed")
            self.logMessage.emit("File transfer completed", "success")
            self.refreshLocal()
            self.refreshRemote()
        elif operation == "local:mutate":
            self.refreshLocal()
        elif operation == "remote:mutate":
            self.refreshRemote()

    @pyqtSlot(str, str)
    def _operation_failed(self, operation: str, message: str) -> None:
        self._finish_pending()
        if self._shutting_down:
            return
        if operation == "connect":
            self._set_connected(False)
            self._remote_model.clear()
            host_key = self._sftp_service.pending_host_key
            if host_key and self._pending_connection is not None:
                self._set_status("Waiting for SSH host key confirmation")
                self.logMessage.emit(self._status_message, "warning")
                self.hostKeyConfirmationRequired.emit(
                    host_key["host"],
                    host_key["keyType"],
                    host_key["fingerprint"],
                )
                return
            self._pending_connection = None
            self._set_status("SFTP connection failed")
        if operation.startswith("transfer:"):
            task_id = operation.split(":")[1]
            self._cancel_events.pop(task_id, None)
            status = "Cancelled" if "cancel" in message.lower() else "Error"
            self._transfer_model.update(task_id, status=status)
        self._report_error(message)

    @pyqtSlot(str, int, int)
    def _on_transfer_progress(self, task_id: str, current: int, total: int) -> None:
        self._transfer_model.update(
            task_id,
            current=current,
            total=total,
            status="Transferring",
        )

    def _report_error(self, message: str) -> None:
        self.errorOccurred.emit(message)
        self.logMessage.emit(message, "error")

    @staticmethod
    def _url_to_path(value: str) -> str:
        if value.startswith("file:"):
            return QUrl(value).toLocalFile()
        return str(Path(value).expanduser())

    @pyqtSlot()
    def shutdown(self) -> None:
        if self._shutting_down:
            return
        self._shutting_down = True
        for event in self._cancel_events.values():
            event.set()
        self._pool.clear()
        # Abort blocking SSH/SFTP calls first; only then allow a short worker grace period.
        self._sftp_service.disconnect()
        self._pool.waitForDone(1000)
        self._set_connected(False)
