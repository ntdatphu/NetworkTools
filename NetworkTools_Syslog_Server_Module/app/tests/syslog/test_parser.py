from backend.syslog_server.parser import parse_message


def test_cisco_message() -> None:
    row = parse_message(b"<189>%SYS-5-CONFIG_I: Configured from console", "192.168.1.1", "udp")
    assert row.facility == "SYS"
    assert row.severity == 5
    assert row.mnemonic == "CONFIG_I"
    assert row.message == "Configured from console"
    assert row.parse_status == "parsed"


def test_malformed_message_is_retained() -> None:
    row = parse_message(b"not a formatted syslog message", "192.168.1.2", "tcp")
    assert row.message == "not a formatted syslog message"
    assert row.raw_message == row.message
    assert row.parse_status == "raw"

