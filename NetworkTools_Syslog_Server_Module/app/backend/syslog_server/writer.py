from __future__ import annotations

import queue
import threading
import time
from collections.abc import Callable

from .parser import parse_message
from .repository import SyslogRepository


class SyslogWriter:
    def __init__(self, repository: SyslogRepository,
                 on_inserted: Callable[[list[dict]], None],
                 on_error: Callable[[str], None], max_queue: int = 10_000) -> None:
        self.repository = repository
        self.on_inserted = on_inserted
        self.on_error = on_error
        self.queue: queue.Queue[tuple[bytes, str, str]] = queue.Queue(maxsize=max_queue)
        self.dropped = 0
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None

    def start(self) -> None:
        if self._thread and self._thread.is_alive():
            return
        self._stop.clear()
        self._thread = threading.Thread(target=self._run, name="syslog-writer", daemon=True)
        self._thread.start()

    def submit(self, data: bytes, source_ip: str, protocol: str) -> None:
        try:
            self.queue.put_nowait((data, source_ip, protocol))
        except queue.Full:
            self.dropped += 1

    def stop(self, timeout: float = 5.0) -> None:
        self._stop.set()
        if self._thread and self._thread is not threading.current_thread():
            self._thread.join(timeout)

    def _run(self) -> None:
        batch = []
        deadline = time.monotonic() + 0.1
        while not self._stop.is_set() or not self.queue.empty() or batch:
            timeout = max(0.0, deadline - time.monotonic())
            try:
                data, source_ip, protocol = self.queue.get(timeout=min(timeout, 0.1))
                message = parse_message(data, source_ip, protocol)
                message.device_host = self.repository.resolve_device_host(source_ip) or source_ip
                batch.append(message)
            except queue.Empty:
                pass
            if len(batch) >= 100 or (batch and time.monotonic() >= deadline):
                try:
                    self.on_inserted(self.repository.insert_messages(batch))
                except Exception as exc:
                    self.dropped += len(batch)
                    self.on_error(f"Could not store syslog messages: {exc}")
                batch = []
                deadline = time.monotonic() + 0.1

