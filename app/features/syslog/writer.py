"""Single bounded-queue writer that batches SQLite work."""

from __future__ import annotations

import queue
import threading
import time
from collections.abc import Callable
from typing import Any

from .parser import parse_message
from .repository import SyslogRepository
from .source_resolver import DeviceHostResolver


class SyslogWriter:
    def __init__(
        self,
        repository: SyslogRepository,
        on_inserted: Callable[[list[dict[str, Any]]], None],
        on_error: Callable[[str], None],
        max_queue: int = 10_000,
    ) -> None:
        self.repository = repository
        self.on_inserted = on_inserted
        self.on_error = on_error
        self.queue: queue.Queue[tuple[bytes, str, str]] = queue.Queue(maxsize=max_queue)
        self._dropped = 0
        self._metrics_lock = threading.Lock()
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None
        self._resolver = DeviceHostResolver(repository)

    @property
    def dropped(self) -> int:
        with self._metrics_lock:
            return self._dropped

    def _add_dropped(self, count: int = 1) -> None:
        with self._metrics_lock:
            self._dropped += max(0, int(count))

    def set_repository(self, repository: SyslogRepository) -> None:
        """Switch workspace databases after the pipeline has been stopped."""
        if self._thread and self._thread.is_alive():
            raise RuntimeError("Stop the Syslog writer before changing its repository")
        self.repository = repository
        self._resolver.set_repository(repository)

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
            self._add_dropped()

    def stop(self, timeout: float = 5.0) -> None:
        self._stop.set()
        if self._thread and self._thread is not threading.current_thread():
            self._thread.join(timeout)

    def _run(self) -> None:
        batch = []
        deadline = time.monotonic() + 0.1
        while not self._stop.is_set() or not self.queue.empty() or batch:
            # With no pending batch there is no flush deadline. Keep a bounded
            # blocking read instead of spinning at 100% CPU after an idle 100ms.
            timeout = (
                max(0.0, deadline - time.monotonic()) if batch else 0.1
            )
            try:
                data, source_ip, protocol = self.queue.get(
                    timeout=min(timeout, 0.1)
                )
            except queue.Empty:
                data = None
            if data is not None:
                try:
                    message = parse_message(data, source_ip, protocol)
                    # Unknown sources keep their socket IP so they remain searchable.
                    message.device_host = self._resolver.resolve(source_ip)
                    batch.append(message)
                except Exception as exc:
                    self._add_dropped()
                    self.on_error(f"Could not process a syslog message: {exc}")
            if len(batch) >= 100 or (batch and time.monotonic() >= deadline):
                try:
                    inserted = self.repository.insert_messages(batch)
                except Exception as exc:
                    self._add_dropped(len(batch))
                    self.on_error(f"Could not store syslog messages: {exc}")
                else:
                    try:
                        self.on_inserted(inserted)
                    except Exception as exc:
                        # Rows are already committed; a UI callback failure must
                        # not misreport them as dropped network messages.
                        self.on_error(f"Could not publish stored syslog messages: {exc}")
                batch = []
                deadline = time.monotonic() + 0.1
