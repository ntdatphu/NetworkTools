import unittest

from features.syslog.settings import _local_ipv4_addresses, _validate_ip


class SyslogSettingsValidationTests(unittest.TestCase):
    def test_empty_advertised_ip_has_friendly_error(self) -> None:
        with self.assertRaisesRegex(ValueError, "Advertised/server IP is required"):
            _validate_ip("", "Advertised/server IP", allow_unspecified=False)

    def test_unspecified_bind_ip_is_allowed_for_listener(self) -> None:
        _validate_ip("0.0.0.0", "Bind IP", allow_unspecified=True)

    def test_detected_advertised_addresses_are_usable_ipv4(self) -> None:
        for value in _local_ipv4_addresses():
            self.assertNotIn(":", value)
            self.assertNotEqual(value, "0.0.0.0")
            self.assertFalse(value.startswith("127."))


if __name__ == "__main__":
    unittest.main()
