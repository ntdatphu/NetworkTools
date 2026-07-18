import socket
import threading

from syslog_server.models import ListenerConfig
from syslog_server.receiver import SyslogReceiver


def test_udp_receiver_delivers_datagram() -> None:
    received: list[tuple[bytes, str, str]] = []
    ready = threading.Event()
    receiver = SyslogReceiver(
        ListenerConfig("127.0.0.1", "127.0.0.1", 0, "udp"),
        lambda data, source, protocol: (received.append((data, source, protocol)), ready.set()),
        lambda message: None,
    )
    receiver.start()
    try:
        assert receiver._server is not None
        port = int(receiver._server.getsockname()[1])
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as client:
            client.sendto(b"<189>%SYS-5-CONFIG_I: receiver test", ("127.0.0.1", port))
        assert ready.wait(2.0)
        assert received[0][0].endswith(b"receiver test")
        assert received[0][2] == "udp"
    finally:
        receiver.stop()
