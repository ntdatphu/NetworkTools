import pytest

from backend.syslog_server.command_builder import build_cancel_commands, build_enable_commands


def test_enable_udp_5514() -> None:
    commands = build_enable_commands("192.168.1.100", "udp", 5514, "GigabitEthernet0/0")
    assert commands[0] == "logging host 192.168.1.100 transport udp port 5514"
    assert "logging trap warnings" in commands
    assert commands[-1] == "logging source-interface GigabitEthernet0/0"


def test_cancel_only_removes_managed_destination() -> None:
    assert build_cancel_commands("192.168.1.100", "tcp", 514) == [
        "no logging host 192.168.1.100 transport tcp port 514"
    ]


def test_invalid_protocol() -> None:
    with pytest.raises(ValueError):
        build_enable_commands("192.168.1.100", "tls", 6514, "Gi0/0")

