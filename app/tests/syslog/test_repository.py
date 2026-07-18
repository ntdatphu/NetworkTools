import sqlite3

from syslog_server.repository import SyslogRepository


def test_schema_migration_preserves_existing_tables(tmp_path) -> None:
    info_db = tmp_path / "info.db"
    device_db = tmp_path / "devices.db"
    with sqlite3.connect(info_db) as conn:
        conn.execute("CREATE TABLE legacy_data (value TEXT)")
        conn.execute("INSERT INTO legacy_data VALUES ('kept')")
    with sqlite3.connect(device_db) as conn:
        conn.execute("CREATE TABLE t01_devices (host TEXT, device_name TEXT, device_type TEXT, os TEXT, success INTEGER)")

    SyslogRepository(info_db, device_db)

    with sqlite3.connect(info_db) as conn:
        assert conn.execute("SELECT value FROM legacy_data").fetchone()[0] == "kept"
        assert conn.execute(
            "SELECT 1 FROM sqlite_master WHERE type='table' AND name='t12_syslog_messages'"
        ).fetchone()
