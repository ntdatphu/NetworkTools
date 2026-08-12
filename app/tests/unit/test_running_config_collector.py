from __future__ import annotations

import unittest
from unittest.mock import patch

from infrastructure.network.running_config_collector import RunningConfigCollector


class _ChunkedConnection:
    RETURN = "\n"

    def __init__(self) -> None:
        self.prompt = "Router#"
        self.writes: list[str] = []
        self.responses: list[list[str]] = []
        self.current: list[str] = []

    def find_prompt(self):
        return self.prompt

    def check_enable_mode(self):
        return True

    def check_config_mode(self):
        return "(config" in self.prompt

    def config_mode(self):
        self.prompt = "Router(config)#"

    def clear_buffer(self):
        pass

    def write_channel(self, value):
        self.writes.append(value)
        self.current = self.responses.pop(0)

    def read_channel(self):
        return self.current.pop(0) if self.current else ""

    def is_alive(self):
        return {"is_alive": True}


class RunningConfigCollectorTests(unittest.TestCase):
    def test_waits_for_prompt_across_partial_chunks_and_normalizes_output(self):
        connection = _ChunkedConnection()
        connection.responses = [
            ["do terminal length 0\r\n", "Router(config)#"],
            [
                "do show running-config\r\nBuilding configuration...\r\nversion 17\r\n",
                "interface Gi0/0\r\n ip address 192.0.2.1 255.255.255.0\r\n",
                "Router(config)",
                "#",
            ],
        ]

        result = RunningConfigCollector(connection).collect()

        self.assertEqual(
            connection.writes,
            ["do terminal length 0\n", "do show running-config\n"],
        )
        self.assertIn("interface Gi0/0\n ip address 192.0.2.1", result)
        self.assertNotIn("Router(config)#", result)
        self.assertTrue(result.endswith("\n"))

    def test_stops_waiting_when_device_never_returns_prompt(self):
        connection = _ChunkedConnection()
        connection.responses = [[""]]
        ticks = iter([0.0, 0.0, 0.2])

        with patch(
            "infrastructure.network.running_config_collector.time.monotonic",
            side_effect=lambda: next(ticks),
        ):
            with self.assertRaisesRegex(TimeoutError, "terminal length 0"):
                RunningConfigCollector(
                    connection,
                    read_timeout=0.1,
                    poll_interval=0,
                ).collect()
