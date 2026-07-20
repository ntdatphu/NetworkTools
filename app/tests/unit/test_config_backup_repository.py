from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from features.config_backup.repository import ConfigBackupRepository


class ConfigBackupRepositoryTests(unittest.TestCase):
    """Verify per-host Git history without requiring a network device."""

    def test_commits_changed_and_unchanged_snapshots(self) -> None:
        """Every collection creates a commit and preserves changed metadata."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repository = ConfigBackupRepository(Path(temp_dir) / "backup")
            first = repository.commit_snapshot("10.2.3.1", "hostname router", timestamp=1_700_000_000)
            second = repository.commit_snapshot("10.2.3.1", "hostname router", timestamp=1_700_000_001)

            self.assertTrue(first["commitCreated"])
            self.assertTrue(first["changed"])
            self.assertTrue(second["commitCreated"])
            self.assertFalse(second["changed"])
            history = repository.list_commits("10.2.3.1")
            self.assertEqual(len(history), 2)
            self.assertFalse(history[0]["changed"])
            latest_file = Path(second["path"])
            latest_file.write_text("uncommitted working tree\n", encoding="utf-8")
            self.assertEqual(repository.read_commit("10.2.3.1", first["commitId"])["content"], "hostname router\n")

    def test_hosts_are_isolated_and_invalid_hosts_are_rejected(self) -> None:
        """Separate hosts never share history and traversal input fails closed."""
        with tempfile.TemporaryDirectory() as temp_dir:
            repository = ConfigBackupRepository(Path(temp_dir) / "backup")
            repository.commit_snapshot("router-a", "hostname a")
            repository.commit_snapshot("router-b", "hostname b")
            self.assertEqual(repository.read_latest("router-a")["content"], "hostname a\n")
            self.assertEqual(repository.read_latest("router-b")["content"], "hostname b\n")
            with self.assertRaises(ValueError):
                repository.commit_snapshot("../escape", "invalid")


if __name__ == "__main__":
    unittest.main()
