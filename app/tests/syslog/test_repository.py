import sqlite3
import tempfile
import unittest
from contextlib import closing
from pathlib import Path

from features.syslog.repository import SyslogRepository


class SyslogRepositoryTests(unittest.TestCase):
    @staticmethod
    def _create_databases(root: Path) -> tuple[Path, Path]:
        info_db = root / "info.db"
        device_db = root / "devices.db"
        sqlite3.connect(info_db).close()
        with closing(sqlite3.connect(device_db)) as conn:
            with conn:
                conn.execute(
                    "CREATE TABLE t01_devices "
                    "(host TEXT, device_name TEXT, device_type TEXT, "
                    "os TEXT, connection_status TEXT)"
                )
        return info_db, device_db

    def test_schema_migration_preserves_existing_tables(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            info_db = root / "info.db"
            device_db = root / "devices.db"
            with closing(sqlite3.connect(info_db)) as conn:
                with conn:
                    conn.execute("CREATE TABLE legacy_data (value TEXT)")
                    conn.execute("INSERT INTO legacy_data VALUES ('kept')")
            with closing(sqlite3.connect(device_db)) as conn:
                with conn:
                    conn.execute(
                        "CREATE TABLE t01_devices "
                        "(host TEXT, device_name TEXT, device_type TEXT, "
                        "os TEXT, connection_status TEXT)"
                    )

            SyslogRepository(info_db, device_db)

            with closing(sqlite3.connect(info_db)) as conn:
                self.assertEqual(
                    conn.execute("SELECT value FROM legacy_data").fetchone()[0],
                    "kept",
                )
                self.assertIsNotNone(
                    conn.execute(
                        "SELECT 1 FROM sqlite_master "
                        "WHERE type='table' AND name='t12_syslog_messages'"
                    ).fetchone()
                )

    def test_failed_cancel_attempt_preserves_existing_configured_flag(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            info_db, device_db = self._create_databases(Path(temp_dir))
            repository = SyslogRepository(info_db, device_db)
            repository.save_device_state(
                "192.0.2.1",
                "192.0.2.100",
                "udp",
                5514,
                "GigabitEthernet0/0",
                True,
                "configured",
            )

            repository.save_device_attempt(
                "192.0.2.1", "192.0.2.100", "udp", 5514, "removal not verified"
            )

            with closing(sqlite3.connect(info_db)) as conn:
                row = conn.execute(
                    "SELECT configured, last_result FROM t12_syslog_device_state"
                ).fetchone()
            self.assertEqual(row, (1, "removal not verified"))

    def test_first_failed_cancel_attempt_does_not_invent_configured_state(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            info_db, device_db = self._create_databases(Path(temp_dir))
            repository = SyslogRepository(info_db, device_db)

            repository.save_device_attempt(
                "192.0.2.1", "192.0.2.100", "udp", 5514, "removal failed"
            )

            with closing(sqlite3.connect(info_db)) as conn:
                row = conn.execute(
                    "SELECT configured, last_result FROM t12_syslog_device_state"
                ).fetchone()
            self.assertEqual(row, (0, "removal failed"))


if __name__ == "__main__":
    unittest.main()
