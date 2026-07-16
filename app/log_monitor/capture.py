from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import threading
import time
from collections import deque
from datetime import datetime, timezone
from pathlib import Path

from PyQt6.QtCore import QObject, QRunnable, QThread, pyqtSignal

from .types import PacketSummary

try:
    import psutil
except ImportError:  # Optional: interface names from TShark remain sufficient.
    psutil = None


FIELDS = (
    "frame.number",
    "frame.time_epoch",
    "frame.len",
    "eth.src",
    "eth.dst",
    "ip.src",
    "ip.dst",
    "ipv6.src",
    "ipv6.dst",
    "tcp.srcport",
    "tcp.dstport",
    "udp.srcport",
    "udp.dstport",
    "_ws.col.Protocol",
    "_ws.col.Info",
)


class PacketLineParser:
    def __init__(self) -> None:
        self._first_timestamp: float | None = None

    def parse(self, line: str) -> PacketSummary | None:
        parts = line.rstrip("\r\n").split("\t")
        if len(parts) < len(FIELDS):
            parts.extend([""] * (len(FIELDS) - len(parts)))
        try:
            frame = int(parts[0])
            timestamp = float(parts[1])
            length = int(parts[2])
        except (IndexError, ValueError):
            return None
        if self._first_timestamp is None:
            self._first_timestamp = timestamp

        src_ip = parts[5] or parts[7]
        dst_ip = parts[6] or parts[8]
        src_port = self._port(parts[9] or parts[11])
        dst_port = self._port(parts[10] or parts[12])
        transport = (
            "TCP"
            if parts[9] or parts[10]
            else ("UDP" if parts[11] or parts[12] else "")
        )
        return PacketSummary(
            packet_no=frame,
            frame_number=frame,
            captured_at=datetime.fromtimestamp(
                timestamp,
                timezone.utc,
            ).isoformat(),
            time_offset=timestamp - self._first_timestamp,
            source=src_ip or parts[3],
            destination=dst_ip or parts[4],
            protocol=(parts[13] or "Ethernet").upper(),
            length=length,
            info=parts[14],
            transport_protocol=transport,
            src_mac=parts[3],
            dst_mac=parts[4],
            src_ip=src_ip,
            dst_ip=dst_ip,
            src_port=src_port,
            dst_port=dst_port,
        )

    @staticmethod
    def _port(value: str) -> int | None:
        try:
            return int(value)
        except (TypeError, ValueError):
            return None


def find_tshark() -> str:
    discovered = shutil.which("tshark") or shutil.which("tshark.exe")
    if discovered:
        return discovered
    if os.name == "nt":
        for variable in ("ProgramFiles", "ProgramFiles(x86)"):
            root = os.environ.get(variable)
            if not root:
                continue
            candidate = Path(root) / "Wireshark" / "tshark.exe"
            if candidate.is_file():
                return str(candidate)
    return ""


def list_capture_interfaces(
    tshark_path: str,
    cancelled=None,
) -> list[dict]:
    startup = None
    if os.name == "nt":
        startup = subprocess.STARTUPINFO()
        startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    process = subprocess.Popen(
        [tshark_path, "-D"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
        startupinfo=startup,
    )
    deadline = time.monotonic() + 10
    while process.poll() is None:
        if cancelled is not None and cancelled():
            process.terminate()
            try:
                process.wait(timeout=1)
            except subprocess.TimeoutExpired:
                process.kill()
            return []
        if time.monotonic() >= deadline:
            process.kill()
            process.wait(timeout=1)
            raise TimeoutError("TShark interface discovery timed out.")
        time.sleep(0.05)
    stdout, stderr = process.communicate()
    if process.returncode != 0:
        raise RuntimeError(
            stderr.strip() or "Unable to list capture interfaces."
        )

    addresses = psutil.net_if_addrs() if psutil is not None else {}
    interfaces: list[dict] = []
    for line in stdout.splitlines():
        match = re.match(r"^\s*\d+\.\s+(.+?)\s*$", line)
        if not match:
            continue
        raw = match.group(1)
        interface_id, display_name = _split_interface_name(raw)
        ipv4 = _find_ipv4(interface_id, display_name, addresses)
        interfaces.append(
            {
                "id": interface_id,
                "name": display_name,
                "ipv4": ipv4,
                "label": (
                    f"{display_name} — {ipv4}" if ipv4 else display_name
                ),
            }
        )
    return interfaces


def _split_interface_name(raw: str) -> tuple[str, str]:
    match = re.match(r"^(.*)\s+\(([^()]*)\)$", raw)
    if match:
        identifier = match.group(1).strip()
        return identifier, match.group(2).strip() or identifier
    text = raw.strip()
    return text, text


def _find_ipv4(interface_id: str, display_name: str, addresses: dict) -> str:
    for name, rows in addresses.items():
        if name != interface_id and name.casefold() not in display_name.casefold():
            continue
        for row in rows:
            if getattr(row.family, "name", "") == "AF_INET":
                return str(row.address)
    return ""


class InterfaceProbeWorker(QThread):
    resultReady = pyqtSignal(object, str, str)

    def run(self) -> None:
        tshark_path = find_tshark()
        if not tshark_path:
            self.resultReady.emit(
                [],
                "",
                "TShark was not found. Install Wireshark to start new captures; "
                "saved sessions remain available.",
            )
            return
        try:
            interfaces = list_capture_interfaces(
                tshark_path,
                self.isInterruptionRequested,
            )
            if self.isInterruptionRequested():
                return
            message = (
                f"Ready — {len(interfaces)} capture interface(s) detected."
                if interfaces
                else "TShark is available, but no capture interface was returned."
            )
            self.resultReady.emit(interfaces, tshark_path, message)
        except Exception as exc:
            self.resultReady.emit(
                [],
                tshark_path,
                f"TShark is installed, but interface discovery failed: {exc}",
            )


class CaptureWorker(QThread):
    batchCaptured = pyqtSignal(object)
    captureError = pyqtSignal(str)

    BATCH_SIZE = 64
    BATCH_INTERVAL_SECONDS = 0.1
    MAX_DURATION_SECONDS = 3_600
    MAX_CAPTURE_SIZE_KIB = 262_144
    MAX_CAPTURE_PACKETS = 250_000

    def __init__(
        self,
        tshark_path: str,
        interface_id: str,
        capture_file: Path,
        capture_filter: str,
    ) -> None:
        super().__init__()
        self._tshark_path = tshark_path
        self._interface_id = interface_id
        self._capture_file = capture_file
        self._capture_filter = str(capture_filter or "").strip()
        self._process: subprocess.Popen | None = None
        self._stop_requested = threading.Event()
        self._stderr_tail: deque[str] = deque(maxlen=20)

    def run(self) -> None:
        parser = PacketLineParser()
        command = [
            self._tshark_path,
            "-l",
            "-n",
            "-i",
            self._interface_id,
            "-w",
            str(self._capture_file),
            "-P",
            "-T",
            "fields",
            "-E",
            "separator=\t",
            "-E",
            "occurrence=f",
            "-a",
            f"duration:{self.MAX_DURATION_SECONDS}",
            "-a",
            f"filesize:{self.MAX_CAPTURE_SIZE_KIB}",
            "-a",
            f"packets:{self.MAX_CAPTURE_PACKETS}",
        ]
        for field in FIELDS:
            command.extend(("-e", field))
        if self._capture_filter:
            command.extend(("-f", self._capture_filter))

        startup = None
        if os.name == "nt":
            startup = subprocess.STARTUPINFO()
            startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW

        batch: list[PacketSummary] = []
        last_emit = time.monotonic()
        try:
            self._process = subprocess.Popen(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                encoding="utf-8",
                errors="replace",
                bufsize=1,
                startupinfo=startup,
            )
            assert self._process.stdout is not None
            assert self._process.stderr is not None
            stderr_thread = threading.Thread(
                target=self._drain_stderr,
                args=(self._process.stderr,),
                name="networktools-tshark-stderr",
                daemon=True,
            )
            stderr_thread.start()

            for line in self._process.stdout:
                if self._stop_requested.is_set():
                    break
                packet = parser.parse(line)
                if packet is None:
                    continue
                batch.append(packet)
                now = time.monotonic()
                if (
                    len(batch) >= self.BATCH_SIZE
                    or now - last_emit >= self.BATCH_INTERVAL_SECONDS
                ):
                    self.batchCaptured.emit(batch)
                    batch = []
                    last_emit = now

            if batch:
                self.batchCaptured.emit(batch)
            return_code = self._process.wait()
            stderr_thread.join(timeout=0.5)
            if return_code and not self._stop_requested.is_set():
                message = "\n".join(self._stderr_tail).strip()
                self.captureError.emit(
                    message or f"TShark exited with code {return_code}."
                )
        except Exception as exc:
            if not self._stop_requested.is_set():
                self.captureError.emit(str(exc))
        finally:
            self._terminate_process()

    def stop(self) -> None:
        self._stop_requested.set()
        self._terminate_process()

    def _drain_stderr(self, stream) -> None:
        for line in stream:
            text = line.strip()
            if text:
                self._stderr_tail.append(text)

    def _terminate_process(self) -> None:
        process = self._process
        if process is None or process.poll() is not None:
            return
        try:
            process.terminate()
            process.wait(timeout=3)
        except (OSError, subprocess.TimeoutExpired):
            try:
                process.kill()
            except OSError:
                pass


def fallback_packet_details(packet: dict) -> list[dict]:
    fields = (
        ("Frame", ""),
        ("Frame number", packet.get("frame_number", "")),
        ("Frame length", f"{packet.get('length', 0)} bytes"),
        ("Protocol", packet.get("protocol", "")),
        (
            "Source",
            packet.get("src_ip") or packet.get("src_mac") or "",
        ),
        (
            "Destination",
            packet.get("dst_ip") or packet.get("dst_mac") or "",
        ),
        ("Information", packet.get("info", "")),
    )
    return [
        {
            "depth": 0 if index == 0 else 1,
            "name": name,
            "value": value,
            "expandable": index == 0,
        }
        for index, (name, value) in enumerate(fields)
    ]


class PacketDecodeSignals(QObject):
    completed = pyqtSignal(int, object, object, str)


class PacketDecodeTask(QRunnable):
    def __init__(
        self,
        request_id: int,
        tshark_path: str,
        capture_file: str,
        frame_number: int,
        fallback: dict,
    ) -> None:
        super().__init__()
        self.request_id = request_id
        self.tshark_path = tshark_path
        self.capture_file = capture_file
        self.frame_number = frame_number
        self.fallback = fallback
        self.signals = PacketDecodeSignals()

    def run(self) -> None:
        try:
            details = self._read_details()
            byte_rows = self._read_bytes()
            self.signals.completed.emit(
                self.request_id,
                details or fallback_packet_details(self.fallback),
                byte_rows,
                "",
            )
        except Exception as exc:
            self.signals.completed.emit(
                self.request_id,
                fallback_packet_details(self.fallback),
                [],
                str(exc),
            )

    def _run_tshark(self, args: list[str]) -> str:
        result = subprocess.run(
            [self.tshark_path, *args],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=12,
        )
        if result.returncode != 0:
            raise RuntimeError(
                result.stderr.strip() or "Unable to decode the selected packet."
            )
        return result.stdout

    def _read_details(self) -> list[dict]:
        path = Path(self.capture_file)
        if not self.tshark_path or not path.is_file():
            return fallback_packet_details(self.fallback)
        output = self._run_tshark(
            [
                "-r",
                str(path),
                "-Y",
                f"frame.number == {self.frame_number}",
                "-T",
                "json",
            ]
        )
        packets = json.loads(output or "[]")
        if not packets:
            return []
        layers = packets[0].get("_source", {}).get("layers", {})
        rows: list[dict] = []
        self._flatten(layers, rows, 0)
        return rows[:1_000]

    def _flatten(
        self,
        value,
        rows: list[dict],
        depth: int,
        name: str = "Packet",
    ) -> None:
        if isinstance(value, dict):
            if name != "Packet":
                rows.append(
                    {
                        "depth": depth,
                        "name": self._label(name),
                        "value": "",
                        "expandable": True,
                    }
                )
                depth += 1
            for key, child in value.items():
                self._flatten(child, rows, depth, key)
        elif isinstance(value, list):
            for child in value[:50]:
                self._flatten(child, rows, depth, name)
        else:
            rows.append(
                {
                    "depth": depth,
                    "name": self._label(name),
                    "value": str(value),
                    "expandable": False,
                }
            )

    def _read_bytes(self) -> list[dict]:
        path = Path(self.capture_file)
        if not self.tshark_path or not path.is_file():
            return []
        output = self._run_tshark(
            [
                "-r",
                str(path),
                "-Y",
                f"frame.number == {self.frame_number}",
                "-x",
            ]
        )
        rows: list[dict] = []
        pattern = re.compile(
            r"^([0-9a-fA-F]{4,8})\s+((?:[0-9a-fA-F]{2}\s+)+)\s{2,}(.*)$"
        )
        for line in output.splitlines():
            match = pattern.match(line)
            if match:
                rows.append(
                    {
                        "offset": match.group(1).upper(),
                        "hexBytes": " ".join(
                            match.group(2).upper().split()
                        ),
                        "asciiText": match.group(3),
                    }
                )
        return rows

    @staticmethod
    def _label(name: str) -> str:
        return name.replace("_", " ").replace(".", " › ")
