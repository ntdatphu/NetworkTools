"""Tests for concurrent multi-host connection task admission."""

from __future__ import annotations

import unittest

from core.terminal import TerminalHelper


class _TerminalAdmissionFake:
    def __init__(self) -> None:
        self.seen: list[str] = []

    def connectHostAndSyncAsync(self, host: str) -> bool:
        self.seen.append(host)
        return host != "r2"


class TerminalMultiHostTests(unittest.TestCase):
    def test_batch_deduplicates_hosts_and_reports_per_host_admission(self) -> None:
        helper = _TerminalAdmissionFake()
        result = TerminalHelper.connectHostsAndSyncAsync(
            helper, ["r1", "r2", "r1", "", "  "]
        )
        self.assertEqual(helper.seen, ["r1", "r2"])
        self.assertEqual(result["accepted"], ["r1"])
        self.assertEqual(result["rejected"], ["r2"])
        self.assertFalse(result["ok"])


if __name__ == "__main__":
    unittest.main()
