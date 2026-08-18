"""Bounded UDP/TCP socket receiver running outside the Qt UI thread."""

from __future__ import annotations

import select
import socket
import threading
from collections.abc import Callable

from .models import ListenerConfig


MessageCallback = Callable[[bytes, str, str], None]
ErrorCallback = Callable[[str], None]


class SyslogReceiver:
    def __init__(self, config: ListenerConfig, on_message: MessageCallback, on_error: ErrorCallback) -> None:
        self.config = config
        self.on_message = on_message
        self.on_error = on_error
        self._stop = threading.Event()
        self._ready = threading.Event()
        self._start_error: OSError | None = None
        self._thread: threading.Thread | None = None
        self._server: socket.socket | None = None

    def start(self) -> None:
        if self._thread and self._thread.is_alive():
            return
        self._stop.clear()
        self._ready.clear()
        self._start_error = None
        self._thread = threading.Thread(target=self._run, name="syslog-receiver", daemon=True)
        self._thread.start()
        if not self._ready.wait(2.0):
            self.stop(timeout=0.5)
            raise TimeoutError("Timed out while starting the Syslog listener")
        if self._start_error is not None:
            self.stop(timeout=0.5)
            raise self._start_error

    @property
    def is_running(self) -> bool:
        return bool(self._thread and self._thread.is_alive() and not self._stop.is_set())

    def stop(self, timeout: float = 3.0) -> None:
        self._stop.set()
        if self._server:
            try:
                self._server.close()
            except OSError:
                pass
        if self._thread and self._thread is not threading.current_thread():
            self._thread.join(timeout)
        self._server = None

    def _run(self) -> None:
        try:
            if self.config.protocol == "udp":
                self._run_udp()
            else:
                self._run_tcp()
        except (OSError, ValueError) as exc:
            if isinstance(exc, OSError):
                self._start_error = exc
            self._ready.set()
            # Closing the server during a normal stop can wake select/recv with an error.
            if not self._stop.is_set():
                self.on_error(str(exc))

    def _new_socket(self, sock_type: int) -> socket.socket:
        family = socket.AF_INET6 if ":" in self.config.bind_ip else socket.AF_INET
        server = socket.socket(family, sock_type)
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.settimeout(0.5)
        server.bind((self.config.bind_ip, self.config.port))
        self._server = server
        return server

    def _run_udp(self) -> None:
        server = self._new_socket(socket.SOCK_DGRAM)
        self._ready.set()
        while not self._stop.is_set():
            try:
                data, address = server.recvfrom(self.config.max_message_bytes + 1)
            except (TimeoutError, socket.timeout):
                continue
            if data and len(data) <= self.config.max_message_bytes:
                self.on_message(data, str(address[0]), "udp")

    def _run_tcp(self) -> None:
        server = self._new_socket(socket.SOCK_STREAM)
        server.listen(self.config.max_tcp_clients)
        self._ready.set()
        clients: dict[socket.socket, tuple[str, bytearray]] = {}
        try:
            while not self._stop.is_set():
                readable, _, _ = select.select([server, *clients], [], [], 0.5)
                for current in readable:
                    if current is server:
                        client, address = server.accept()
                        if len(clients) >= self.config.max_tcp_clients:
                            client.close()
                            continue
                        client.setblocking(False)
                        clients[client] = (str(address[0]), bytearray())
                        continue
                    source_ip, buffer = clients[current]
                    try:
                        chunk = current.recv(4096)
                    except OSError:
                        chunk = b""
                    if not chunk:
                        if buffer.strip():
                            self.on_message(bytes(buffer), source_ip, "tcp")
                        self._close_client(current, clients)
                        continue
                    buffer.extend(chunk)
                    if len(buffer) > self.config.max_message_bytes:
                        self._close_client(current, clients)
                        continue
                    while b"\n" in buffer:
                        frame, _, remaining = buffer.partition(b"\n")
                        buffer[:] = remaining
                        if frame.strip():
                            self.on_message(bytes(frame), source_ip, "tcp")
        finally:
            for client in list(clients):
                self._close_client(client, clients)

    @staticmethod
    def _close_client(client: socket.socket, clients: dict[socket.socket, tuple[str, bytearray]]) -> None:
        clients.pop(client, None)
        try:
            client.close()
        except OSError:
            pass
