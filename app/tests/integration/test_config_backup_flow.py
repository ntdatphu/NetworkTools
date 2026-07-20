from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import core.terminal as runtime
from core.terminal import TerminalHelper
from features.config_backup.service import ConfigBackupService


class ConfigBackupFlowTests(unittest.TestCase):
    """Exercise legacy migration and service payloads across the storage boundary."""

    def test_legacy_backup_is_imported_once_and_preserved(self) -> None:
        """Repeated reads keep one import commit and retain the migrated source."""
        with tempfile.TemporaryDirectory() as temp_dir:
            backup_root = Path(temp_dir) / "backup"
            legacy_dir = backup_root / "10.2.3.1"
            legacy_dir.mkdir(parents=True)
            legacy = legacy_dir / "10.2.3.1_running-config.txt"
            legacy.write_text("hostname legacy\n", encoding="utf-8")
            service = ConfigBackupService(backup_root)

            first = service.list_history("10.2.3.1")
            second = service.list_history("10.2.3.1")

            self.assertTrue(first["ok"])
            self.assertEqual(len(first["commits"]), 1)
            self.assertEqual(len(second["commits"]), 1)
            self.assertFalse(legacy.exists())
            self.assertTrue(legacy.with_name(f"{legacy.name}.migrated").exists())
            self.assertEqual(service.read_latest("10.2.3.1")["content"], "hostname legacy\n")

    def test_terminal_backup_collects_commits_then_synchronizes(self) -> None:
        """The application flow commits collected text before DB state synchronization."""
        class FakeConnector:
            last_sync_error = ""
            last_sync_summary = {"interfaces": 1, "ospf_processes": 0}

            def __init__(self) -> None:
                self.sync_calls: list[tuple[str, str]] = []

            def collect_running_config(self) -> dict[str, object]:
                return {
                    "ok": True,
                    "running_config": "hostname integrated\n",
                    "interface_brief": "GigabitEthernet0/0 up up\n",
                }

            def sync_collected_state(self, running_config: str, interface_brief: str) -> bool:
                self.sync_calls.append((running_config, interface_brief))
                return True

        with tempfile.TemporaryDirectory() as temp_dir:
            service = ConfigBackupService(Path(temp_dir) / "backup")
            helper = TerminalHelper(config_backup_service=service)
            connector = FakeConnector()
            device = {
                "host": "10.2.3.1",
                "method": "ssh",
                "port": 22,
                "username": "user",
                "password": "password",
                "device_type": "cisco_ios",
                "dev": 0,
            }
            with patch.object(runtime.device_login_service, "load", return_value=device), patch.object(
                runtime.device_session_registry,
                "get_connector",
                return_value=connector,
            ):
                result = helper.saveRunningConfigBackup("10.2.3.1")

            self.assertTrue(result["ok"])
            self.assertTrue(result["commitCreated"])
            self.assertEqual(len(connector.sync_calls), 1)
            self.assertEqual(service.read_latest("10.2.3.1")["content"], "hostname integrated\n")


if __name__ == "__main__":
    unittest.main()
