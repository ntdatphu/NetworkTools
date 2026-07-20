import unittest

from features.syslog.configurator import SyslogConfigurator


class _RepositoryStub:
    def __init__(self) -> None:
        self.saved_state = None

    def is_connected(self, host: str) -> bool:
        return True

    def device_os(self, host: str) -> str:
        return "cisco_ios"

    def source_interface(self, host: str):
        return None

    def save_device_state(self, *args) -> None:
        self.saved_state = args


class SyslogConfiguratorTests(unittest.TestCase):
    def test_missing_database_interface_requests_manual_input(self) -> None:
        configurator = SyslogConfigurator(_RepositoryStub())

        result = configurator.configure(
            "192.0.2.1", "192.0.2.100", "udp", 5514
        )

        self.assertFalse(result["ok"])
        self.assertEqual(result["code"], "source_interface_required")

    def test_manual_interface_is_used_for_push(self) -> None:
        repository = _RepositoryStub()
        configurator = SyslogConfigurator(repository)
        sent_commands: list[str] = []
        configurator._send = lambda host, commands: (
            sent_commands.extend(commands) or {"ok": True, "message": "pushed"}
        )

        result = configurator.configure(
            "192.0.2.1",
            "192.0.2.100",
            "udp",
            5514,
            "GigabitEthernet0/0",
        )

        self.assertTrue(result["ok"])
        self.assertIn("logging source-interface GigabitEthernet0/0", sent_commands)
        self.assertIsNotNone(repository.saved_state)


if __name__ == "__main__":
    unittest.main()
