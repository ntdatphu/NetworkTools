from __future__ import annotations

import sqlite3
import tempfile
import unittest
from contextlib import closing, redirect_stdout
from io import StringIO
from pathlib import Path
from unittest.mock import patch

from scripts import build_databases


APP_DIR = Path(__file__).resolve().parents[1]
SCHEMA_DIR = APP_DIR / "infrastructure" / "database" / "schemas"


class DatabaseBootstrapTests(unittest.TestCase):
    def test_modular_sources_build_valid_sql_directly(self) -> None:
        for source_dir in (SCHEMA_DIR / "device_network", SCHEMA_DIR / "info_collected"):
            with self.subTest(source=source_dir.name):
                script = build_databases.combine_sql(source_dir)
                self.assertIn("CREATE TABLE", script.upper())
                with closing(sqlite3.connect(":memory:")) as connection:
                    connection.executescript(script)

    def test_startup_builds_only_the_missing_runtime_database(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            source_dir = root / "schema"
            source_dir.mkdir()
            (source_dir / "01_core.sql").write_text(
                "CREATE TABLE runtime_table (id INTEGER PRIMARY KEY);\n",
                encoding="utf-8",
            )
            db_path = root / "runtime.db"

            output = StringIO()
            with patch.object(
                build_databases,
                "TARGETS",
                ((source_dir, db_path),),
            ), redirect_stdout(output):
                built = build_databases.build_missing_databases()

            self.assertEqual(built, [db_path])
            self.assertEqual(output.getvalue(), "")
            with closing(sqlite3.connect(db_path)) as connection:
                table = connection.execute(
                    "SELECT name FROM sqlite_master WHERE type='table' AND name='runtime_table'"
                ).fetchone()
            self.assertEqual(table, ("runtime_table",))

    def test_startup_preserves_an_existing_database(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            source_dir = root / "schema"
            source_dir.mkdir()
            (source_dir / "01_core.sql").write_text(
                "CREATE TABLE replacement (id INTEGER PRIMARY KEY);\n",
                encoding="utf-8",
            )
            db_path = root / "runtime.db"
            with closing(sqlite3.connect(db_path)) as connection:
                connection.execute("CREATE TABLE user_data (value TEXT)")
                connection.execute("INSERT INTO user_data VALUES ('keep me')")
                connection.commit()

            with patch.object(
                build_databases,
                "TARGETS",
                ((source_dir, db_path),),
            ):
                built = build_databases.build_missing_databases()

            self.assertEqual(built, [])
            with closing(sqlite3.connect(db_path)) as connection:
                value = connection.execute("SELECT value FROM user_data").fetchone()
                replacement = connection.execute(
                    "SELECT name FROM sqlite_master WHERE type='table' AND name='replacement'"
                ).fetchone()
            self.assertEqual(value, ("keep me",))
            self.assertIsNone(replacement)


if __name__ == "__main__":
    unittest.main()
