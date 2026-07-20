import sqlite3
import tempfile
import unittest
from contextlib import closing
from pathlib import Path

from features.syslog.repository import SyslogRepository


class SyslogRepositoryTests(unittest.TestCase):
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
                        "os TEXT, success INTEGER)"
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


if __name__ == "__main__":
    unittest.main()
