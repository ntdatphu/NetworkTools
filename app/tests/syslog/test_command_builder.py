import unittest

from syslog_server.command_builder import build_cancel_commands, build_enable_commands


class SyslogCommandBuilderTests(unittest.TestCase):
    def test_enable_udp_5514(self) -> None:
        commands = build_enable_commands(
            "192.168.1.100", "udp", 5514, "GigabitEthernet0/0"
        )
        self.assertEqual(
            commands[0],
            "logging host 192.168.1.100 transport udp port 5514",
        )
        self.assertIn("logging trap warnings", commands)
        self.assertEqual(
            commands[-1], "logging source-interface GigabitEthernet0/0"
        )

    def test_cancel_only_removes_managed_destination(self) -> None:
        self.assertEqual(
            build_cancel_commands("192.168.1.100", "tcp", 514),
            ["no logging host 192.168.1.100 transport tcp port 514"],
        )

    def test_invalid_protocol(self) -> None:
        with self.assertRaises(ValueError):
            build_enable_commands("192.168.1.100", "tls", 6514, "Gi0/0")

    def test_manual_interface_rejects_command_injection(self) -> None:
        with self.assertRaisesRegex(ValueError, "unsupported characters"):
            build_enable_commands("192.168.1.100", "udp", 5514, "Gi0/0\nend")


if __name__ == "__main__":
    unittest.main()
