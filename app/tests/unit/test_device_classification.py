from __future__ import annotations

import sqlite3
import tempfile
import unittest
from contextlib import closing
from pathlib import Path

from features.devices import DeviceRepository, device_type_for_role, normalize_device_role
from scripts.build_databases import combine_sql


class DeviceClassificationTests(unittest.TestCase):
    def test_shutdown_reset_ignores_an_already_released_workspace(self):
        with tempfile.TemporaryDirectory() as temporary:
            missing = Path(temporary) / "closed-workspace" / "device_network.db"

            changed = DeviceRepository(missing).reset_connected_to_waiting()

            self.assertEqual(changed, 0)

    def test_role_is_the_single_classification_source(self):
        self.assertEqual(normalize_device_role("router"), "rou")
        self.assertEqual(normalize_device_role("", "switch_l3"), "sw3")
        self.assertEqual(device_type_for_role("rou"), "router")
        self.assertEqual(device_type_for_role("sw2"), "sw2")

    def test_existing_recognized_rows_are_synchronized(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "device.db"
            schema_dir = Path(__file__).resolve().parents[2] / "infrastructure/database/schemas/device_network"
            with closing(sqlite3.connect(path)) as connection:
                connection.executescript(combine_sql(schema_dir))
                connection.execute(
                    "INSERT INTO t01_devices(host, role, device_type) VALUES (?, ?, ?)",
                    ("r1", "router", "sw3"),
                )
                connection.execute(
                    "INSERT INTO t01_devices(host, role, device_type) VALUES (?, ?, ?)",
                    ("legacy", "custom", "custom"),
                )
                connection.commit()

            DeviceRepository(path).synchronize_classification()

            with closing(sqlite3.connect(path)) as connection:
                self.assertEqual(
                    connection.execute(
                        "SELECT role, device_type FROM t01_devices WHERE host='r1'"
                    ).fetchone(),
                    ("rou", "router"),
                )
                self.assertEqual(
                    connection.execute(
                        "SELECT role, device_type FROM t01_devices WHERE host='legacy'"
                    ).fetchone(),
                    ("custom", "custom"),
                )

    def test_shutdown_reset_changes_only_connected_device_statuses(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "device.db"
            schema_dir = Path(__file__).resolve().parents[2] / "infrastructure/database/schemas/device_network"
            with closing(sqlite3.connect(path)) as connection:
                connection.executescript(combine_sql(schema_dir))
                connection.executemany(
                    "INSERT INTO t01_devices(host, connection_status, dev) VALUES (?, ?, ?)",
                    [
                        ("connected", "connected", 1),
                        ("waiting", "waiting", 1),
                        ("disconnected", "disconnected", 0),
                    ],
                )
                connection.commit()

            changed = DeviceRepository(path).reset_connected_to_waiting()

            self.assertEqual(changed, 1)
            with closing(sqlite3.connect(path)) as connection:
                rows = connection.execute(
                    "SELECT host, connection_status, dev FROM t01_devices ORDER BY host"
                ).fetchall()
            self.assertEqual(
                rows,
                [
                    ("connected", "waiting", 1),
                    ("disconnected", "disconnected", 0),
                    ("waiting", "waiting", 1),
                ],
            )
