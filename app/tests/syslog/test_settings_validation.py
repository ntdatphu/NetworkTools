import pytest

from syslog_server.settings import _local_ipv4_addresses, _validate_ip


def test_empty_advertised_ip_has_friendly_error() -> None:
    with pytest.raises(ValueError, match="Advertised/server IP is required"):
        _validate_ip("", "Advertised/server IP", allow_unspecified=False)


def test_unspecified_bind_ip_is_allowed_for_listener() -> None:
    _validate_ip("0.0.0.0", "Bind IP", allow_unspecified=True)


def test_detected_advertised_addresses_are_usable_ipv4() -> None:
    for value in _local_ipv4_addresses():
        assert ":" not in value
        assert value != "0.0.0.0"
        assert not value.startswith("127.")
