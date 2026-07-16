from __future__ import annotations

import ipaddress
import re
import sqlite3
from dataclasses import asdict
from datetime import datetime
from pathlib import Path
from typing import Any

from PyQt6.QtCore import (
    QObject,
    QThreadPool,
    QTimer,
    pyqtProperty,
    pyqtSignal,
    pyqtSlot,
)

from core.database_paths import DEVICE_NETWORK_DB

from .capture import (
    CaptureWorker,
    InterfaceProbeWorker,
    PacketDecodeTask,
    fallback_packet_details,
)
from .models import PacketBytesModel, PacketDetailModel, PacketTableModel
from .storage import (
    PacketDatabase,
    PacketRepository,
    PacketStoreTask,
)
from .types import CaptureState, PacketSummary


APP_DIR = Path(__file__).resolve().parents[1]
DEFAULT_RUNTIME_DIR = APP_DIR / "logs"


class LogController(QObject):
    stateChanged = pyqtSignal()
    dataChanged = pyqtSignal()
    statusMessageChanged = pyqtSignal()
    errorOccurred = pyqtSignal(str)

    MAX_SESSION_PACKETS = 250_000
    RETAINED_SESSION_LIMIT = 20

    def __init__(
        self,
        parent: QObject | None = None,
        *,
        database_path: str | Path | None = None,
        capture_dir: str | Path | None = None,
        device_db_path: str | Path | None = None,
        auto_probe: bool = True,
    ) -> None:
        super().__init__(parent)
        runtime_dir = (
            Path(database_path).parent
            if database_path is not None
            else DEFAULT_RUNTIME_DIR
        )
        self.database_path = (
            Path(database_path)
            if database_path is not None
            else runtime_dir / "packet_logs.db"
        )
        self.capture_dir = (
            Path(capture_dir)
            if capture_dir is not None
            else runtime_dir / "captures"
        )
        self.device_db_path = (
            Path(device_db_path)
            if device_db_path is not None
            else DEVICE_NETWORK_DB
        )
        self.auto_probe = auto_probe

        self._packet_model = PacketTableModel()
        self._detail_model = PacketDetailModel()
        self._bytes_model = PacketBytesModel()
        self._database = PacketDatabase(self.database_path)
        self._repository = PacketRepository(self._database)
        self._interfaces: list[dict] = []
        self._devices: list[dict] = []
        self._sessions: list[dict] = []
        self._selected_interface = ""
        self._tshark_path = ""
        self._state = CaptureState.IDLE
        self._status_message = "Open Device Logs to initialize capture support."
        self._initialized = False
        self._initializing = False
        self._probe_worker: InterfaceProbeWorker | None = None
        self._capture_worker: CaptureWorker | None = None
        self._session_id: int | None = None
        self._session_finalized = True
        self._capture_file = ""
        self._packet_count = 0
        self._pending: list[PacketSummary] = []
        self._live_packets: list[PacketSummary] = []
        self._view_paused = False
        self._capture_had_error = False
        self._stop_reason = "completed"
        self._storage_task_count = 0
        self._capture_finish_pending = False
        self._capture_finish_status = "completed"
        self._decode_request_id = 0
        self._decode_pool = QThreadPool(self)
        self._decode_pool.setMaxThreadCount(1)
        self._storage_pool = QThreadPool(self)
        self._storage_pool.setMaxThreadCount(1)

        self._flush_timer = QTimer(self)
        self._flush_timer.setInterval(500)
        self._flush_timer.timeout.connect(self._flush_pending)

    @pyqtProperty(QObject, constant=True)
    def packetModel(self):
        return self._packet_model

    @pyqtProperty(QObject, constant=True)
    def packetDetailModel(self):
        return self._detail_model

    @pyqtProperty(QObject, constant=True)
    def packetBytesModel(self):
        return self._bytes_model

    @pyqtProperty("QVariantList", notify=dataChanged)
    def interfaces(self) -> list[dict]:
        return self._interfaces

    @pyqtProperty("QVariantList", notify=dataChanged)
    def devices(self) -> list[dict]:
        return self._devices

    @pyqtProperty("QVariantList", notify=dataChanged)
    def sessions(self) -> list[dict]:
        return self._sessions

    @pyqtProperty(str, notify=stateChanged)
    def captureState(self) -> str:
        return self._state.value

    @pyqtProperty(bool, notify=stateChanged)
    def isCapturing(self) -> bool:
        return self._state in {
            CaptureState.STARTING,
            CaptureState.CAPTURING,
            CaptureState.STOPPING,
        }

    @pyqtProperty(bool, notify=stateChanged)
    def initializing(self) -> bool:
        return self._initializing

    @pyqtProperty(bool, notify=stateChanged)
    def viewPaused(self) -> bool:
        return self._view_paused

    @pyqtProperty(bool, notify=dataChanged)
    def captureAvailable(self) -> bool:
        return bool(self._tshark_path and self._interfaces)

    @pyqtProperty(str, notify=statusMessageChanged)
    def statusMessage(self) -> str:
        return self._status_message

    @pyqtProperty(int, notify=dataChanged)
    def packetCount(self) -> int:
        return self._packet_count

    @pyqtProperty(str, notify=dataChanged)
    def selectedInterfaceName(self) -> str:
        interface = self._selected_interface_data()
        return str(interface.get("name", "")) if interface else ""

    @pyqtSlot()
    def initialize(self) -> None:
        if self._initialized or self._initializing:
            return
        try:
            self.capture_dir.mkdir(parents=True, exist_ok=True)
            self._database.ensure()
            self._devices = self._load_devices()
            self._prune_old_sessions()
            self._refresh_sessions()
            self._initialized = True
        except Exception as exc:
            self._set_state(CaptureState.ERROR)
            self._set_status(f"Device Logs initialization failed: {exc}")
            self.errorOccurred.emit(self._status_message)
            return

        if not self.auto_probe:
            self._set_status(
                "Capture dependency probing is disabled in this runtime."
            )
            self.dataChanged.emit()
            return
        self.refreshDependencies()

    @pyqtSlot()
    def refreshDependencies(self) -> None:
        if self.isCapturing or self._initializing:
            return
        self._initializing = True
        self._set_state(CaptureState.INITIALIZING)
        self._set_status("Detecting TShark and capture interfaces…")
        worker = InterfaceProbeWorker(self)
        self._probe_worker = worker
        worker.resultReady.connect(self._on_probe_result)
        worker.finished.connect(
            lambda current=worker: self._clear_probe_worker(current)
        )
        worker.start()

    @pyqtSlot(str)
    def selectInterface(self, interface_id: str) -> None:
        if self.isCapturing:
            return
        if any(row["id"] == interface_id for row in self._interfaces):
            self._selected_interface = interface_id
            self.dataChanged.emit()

    @pyqtSlot(str, str, result=bool)
    def startCapture(
        self,
        capture_filter: str = "",
        device_host: str = "",
    ) -> bool:
        if self.isCapturing:
            return False
        interface = self._selected_interface_data()
        if not self._tshark_path:
            self._report_error(
                "TShark was not found. Install Wireshark, then scan again."
            )
            return False
        if not interface:
            self._report_error(
                "No capture interface is available. Check the TShark/Npcap installation."
            )
            return False

        scope_host = str(device_host or "").strip()
        if scope_host:
            try:
                ipaddress.ip_address(scope_host)
            except ValueError:
                self._report_error(
                    "The selected device does not have a valid IP address."
                )
                return False
        effective_filter = self._effective_capture_filter(
            str(capture_filter or "").strip(),
            scope_host,
        )

        try:
            self._set_state(CaptureState.STARTING)
            capture_path = self._new_capture_path(
                interface["name"],
                scope_host,
            )
            self._session_id = self._repository.create_session(
                interface,
                effective_filter,
                str(capture_path.resolve()),
                scope_host,
            )
            self._capture_file = str(capture_path)
            self._session_finalized = False
            self._capture_had_error = False
            self._stop_reason = "completed"
            self._packet_count = 0
            self._pending.clear()
            self._live_packets.clear()
            self._capture_finish_pending = False
            self._packet_model.clear()
            self._detail_model.replace([])
            self._bytes_model.replace([])

            worker = CaptureWorker(
                self._tshark_path,
                interface["id"],
                capture_path,
                effective_filter,
            )
            self._capture_worker = worker
            worker.batchCaptured.connect(self._on_packet_batch)
            worker.captureError.connect(self._on_capture_error)
            worker.finished.connect(self._on_capture_finished)
            worker.start()
            self._flush_timer.start()
            self._set_state(CaptureState.CAPTURING)
            scope_text = f" for {scope_host}" if scope_host else ""
            self._set_status(
                f"Capturing on {interface['name']}{scope_text}."
            )
            self.dataChanged.emit()
            return True
        except Exception as exc:
            self._report_error(f"Unable to start packet capture: {exc}")
            self._finalize_session("error")
            return False

    @pyqtSlot()
    def stopCapture(self) -> None:
        if not self.isCapturing:
            return
        self._stop_reason = "stopped"
        self._set_state(CaptureState.STOPPING)
        self._set_status("Stopping packet capture…")
        if self._capture_worker:
            self._capture_worker.stop()

    @pyqtSlot()
    def togglePauseView(self) -> None:
        self._view_paused = not self._view_paused
        if not self._view_paused and self._session_id is not None:
            self._flush_pending()
            self._packet_model.replace(
                self._live_packets
            )
        self.stateChanged.emit()

    @pyqtSlot()
    def clearView(self) -> None:
        self._packet_model.clear()
        self._detail_model.replace([])
        self._bytes_model.replace([])

    @pyqtSlot(str, result=bool)
    def applyDisplayFilter(self, expression: str) -> bool:
        try:
            self._packet_model.apply_filter(expression)
            self._set_status(
                "Display filter applied."
                if str(expression or "").strip()
                else "Display filter cleared."
            )
            return True
        except ValueError as exc:
            self._set_status(str(exc))
            return False

    @pyqtSlot(int)
    def selectPacket(self, packet_id: int) -> None:
        if packet_id < 0 and self._session_id is not None:
            summary = next(
                (
                    row
                    for row in reversed(self._live_packets)
                    if row.packet_no == -packet_id
                ),
                None,
            )
            packet = asdict(summary) if summary is not None else None
            if packet is not None:
                packet["capture_file"] = self._capture_file
        else:
            packet = self._repository.find_packet(packet_id)
        if not packet:
            return

        self._detail_model.replace(fallback_packet_details(packet))
        self._bytes_model.replace([])
        capture_file = str(packet.get("capture_file") or "")
        if not self._tshark_path or not Path(capture_file).is_file():
            return

        self._decode_request_id += 1
        request_id = self._decode_request_id
        self._decode_pool.clear()
        task = PacketDecodeTask(
            request_id,
            self._tshark_path,
            capture_file,
            int(packet["frame_number"]),
            packet,
        )
        task.signals.completed.connect(self._on_packet_decoded)
        self._decode_pool.start(task)

    @pyqtSlot(int)
    def openSession(self, session_id: int) -> None:
        if self.isCapturing or session_id <= 0:
            return
        try:
            packets = self._repository.load_session(
                session_id,
                self._packet_model.MAX_LIVE_PACKETS,
            )
            self._packet_model.replace(packets)
            self._live_packets = list(packets)
            self._detail_model.replace([])
            self._bytes_model.replace([])
            self._packet_count = len(packets)
            self._session_id = session_id
            self.dataChanged.emit()
            self._set_status(
                f"Loaded capture session {session_id} "
                f"({len(packets)} packet summaries)."
            )
        except Exception as exc:
            self._report_error(f"Unable to load capture session: {exc}")

    @pyqtSlot()
    def shutdown(self) -> None:
        if self._capture_worker and self._capture_worker.isRunning():
            self._stop_reason = "stopped"
            self._capture_worker.stop()
            self._capture_worker.wait(4_000)
        if self._probe_worker and self._probe_worker.isRunning():
            self._probe_worker.requestInterruption()
            self._probe_worker.wait(1_000)
        self._flush_timer.stop()
        self._flush_pending()
        self._storage_pool.waitForDone(4_000)
        self._finalize_session(self._stop_reason)
        self._storage_pool.clear()
        self._decode_pool.clear()
        self._decode_pool.waitForDone(2_000)

    def _on_probe_result(
        self,
        interfaces: list[dict],
        tshark_path: str,
        message: str,
    ) -> None:
        self._interfaces = list(interfaces or [])
        self._tshark_path = str(tshark_path or "")
        if self._interfaces and not any(
            row["id"] == self._selected_interface
            for row in self._interfaces
        ):
            self._selected_interface = self._interfaces[0]["id"]
        elif not self._interfaces:
            self._selected_interface = ""
        self._initializing = False
        self._set_state(CaptureState.IDLE)
        self._set_status(message)
        self.dataChanged.emit()

    def _clear_probe_worker(self, worker: InterfaceProbeWorker) -> None:
        if self._probe_worker is worker:
            self._probe_worker = None

    def _on_packet_batch(self, value: Any) -> None:
        packets = [
            packet
            for packet in (value or [])
            if isinstance(packet, PacketSummary)
        ]
        if not packets or self._session_id is None:
            return
        remaining = self.MAX_SESSION_PACKETS - self._packet_count
        if remaining <= 0:
            return
        packets = packets[:remaining]
        for packet in packets:
            packet.session_id = self._session_id
        self._packet_count += len(packets)
        self._pending.extend(packets)
        self._live_packets.extend(packets)
        if len(self._live_packets) > self._packet_model.MAX_LIVE_PACKETS:
            self._live_packets = self._live_packets[
                -self._packet_model.MAX_LIVE_PACKETS :
            ]
        if not self._view_paused:
            self._packet_model.append_many(packets)
        if len(self._pending) >= 128:
            self._flush_pending()
        self.dataChanged.emit()

        if self._packet_count >= self.MAX_SESSION_PACKETS:
            self._stop_reason = "limit"
            self._set_status(
                "Capture reached the 250,000-packet safety limit and is stopping."
            )
            if self._capture_worker:
                self._capture_worker.stop()

    def _flush_pending(self) -> None:
        if not self._pending or self._session_id is None:
            return
        packets, self._pending = self._pending, []
        task = PacketStoreTask(
            self._repository,
            self._session_id,
            packets,
        )
        self._storage_task_count += 1
        task.signals.completed.connect(self._on_packets_stored)
        self._storage_pool.start(task)

    def _on_packets_stored(
        self,
        packets: list[PacketSummary],
        packet_ids: list[int],
        error: str,
    ) -> None:
        self._storage_task_count = max(0, self._storage_task_count - 1)
        if error:
            self._capture_finish_status = "error"
            self._on_capture_error(
                f"Unable to store captured packet summaries: {error}"
            )
        else:
            for packet, packet_id in zip(packets, packet_ids):
                packet.packet_id = packet_id or None
        if self._capture_finish_pending and self._storage_task_count == 0:
            status = (
                "error"
                if self._capture_had_error
                else self._capture_finish_status
            )
            self._capture_finish_pending = False
            self._complete_capture_finished(status)

    def _on_capture_error(self, message: str) -> None:
        self._capture_had_error = True
        self._stop_reason = "error"
        self._set_state(CaptureState.ERROR)
        self._set_status(message)
        self.errorOccurred.emit(message)
        if self._capture_worker and self._capture_worker.isRunning():
            self._capture_worker.stop()

    def _on_capture_finished(self) -> None:
        self._flush_timer.stop()
        self._flush_pending()
        status = "error" if self._capture_had_error else self._stop_reason
        self._capture_worker = None
        if self._storage_task_count:
            self._capture_finish_pending = True
            self._capture_finish_status = status
            if not self._capture_had_error:
                self._set_state(CaptureState.STOPPING)
                self._set_status("Finalizing captured packet summaries…")
            return
        self._complete_capture_finished(status)

    def _complete_capture_finished(self, status: str) -> None:
        self._finalize_session(status)
        if not self._capture_had_error:
            self._set_state(CaptureState.IDLE)
            suffix = (
                " Safety limit reached."
                if status == "limit"
                else ""
            )
            self._set_status(
                f"Capture stopped — {self._packet_count} packets recorded."
                f"{suffix}"
            )
        self._prune_old_sessions()
        self._refresh_sessions()

    def _on_packet_decoded(
        self,
        request_id: int,
        details: list[dict],
        byte_rows: list[dict],
        error: str,
    ) -> None:
        if request_id != self._decode_request_id:
            return
        self._detail_model.replace(details)
        self._bytes_model.replace(byte_rows)
        if error:
            self._set_status(
                f"Packet summary loaded; raw decode is unavailable: {error}"
            )

    def _finalize_session(self, status: str) -> None:
        if self._session_id is None or self._session_finalized:
            return
        self._repository.finish_session(
            self._session_id,
            self._packet_count,
            status,
        )
        self._session_finalized = True

    def _load_devices(self) -> list[dict]:
        if not self.device_db_path.is_file():
            return []
        try:
            with sqlite3.connect(self.device_db_path) as connection:
                rows = connection.execute(
                    """
                    SELECT host, COALESCE(device_name, host)
                    FROM t01_devices
                    ORDER BY 2, 1
                    """
                ).fetchall()
        except sqlite3.Error:
            return []
        return [
            {
                "host": str(row[0]),
                "label": f"{row[1]} — {row[0]}",
            }
            for row in rows
        ]

    def _refresh_sessions(self) -> None:
        sessions = self._repository.list_sessions()
        self._sessions = []
        for row in sessions:
            device = (
                f" · {row['device_host']}"
                if row.get("device_host")
                else ""
            )
            started = str(row.get("started_at") or "")[:19]
            self._sessions.append(
                {
                    **row,
                    "label": (
                        f"#{row['session_id']} · {row['interface_name']}"
                        f"{device} · {started}"
                    ),
                }
            )
        self.dataChanged.emit()

    def _prune_old_sessions(self) -> None:
        for capture_file in self._repository.prune_sessions(
            self.RETAINED_SESSION_LIMIT
        ):
            self._delete_capture_file(capture_file)

    def _delete_capture_file(self, value: str) -> None:
        if not value:
            return
        try:
            root = self.capture_dir.resolve()
            path = Path(value).resolve()
            if root not in path.parents or not path.is_file():
                return
            path.unlink()
        except OSError:
            pass

    def _selected_interface_data(self) -> dict | None:
        return next(
            (
                row
                for row in self._interfaces
                if row["id"] == self._selected_interface
            ),
            None,
        )

    def _new_capture_path(
        self,
        interface_name: str,
        device_host: str,
    ) -> Path:
        safe_interface = re.sub(
            r"[^A-Za-z0-9_.-]+",
            "_",
            interface_name,
        ).strip("_.") or "interface"
        safe_host = re.sub(
            r"[^A-Za-z0-9_.-]+",
            "_",
            device_host,
        ).strip("_.")
        suffix = f"_{safe_host}" if safe_host else ""
        timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
        return self.capture_dir / (
            f"{timestamp}_{safe_interface}{suffix}.pcapng"
        )

    @staticmethod
    def _effective_capture_filter(
        capture_filter: str,
        device_host: str,
    ) -> str:
        if capture_filter and device_host:
            return f"({capture_filter}) and host {device_host}"
        if device_host:
            return f"host {device_host}"
        return capture_filter

    def _set_state(self, state: CaptureState) -> None:
        self._state = state
        self.stateChanged.emit()

    def _set_status(self, message: str) -> None:
        self._status_message = str(message or "")
        self.statusMessageChanged.emit()

    def _report_error(self, message: str) -> None:
        self._set_state(CaptureState.ERROR)
        self._set_status(message)
        self.errorOccurred.emit(message)
