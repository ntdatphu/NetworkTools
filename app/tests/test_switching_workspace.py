from __future__ import annotations

import sqlite3
import sys
import tempfile
import unittest
from contextlib import closing
from pathlib import Path


APP_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(APP_DIR / "features"))

from switching import (  # noqa: E402
    ensure_switch_schema,
    get_ip_routing,
    get_svis,
    get_switch_interfaces,
    get_vlans,
    navigation_for_role,
    save_ip_routing,
    save_svi,
    save_switch_interface,
    save_vlan,
)
from scripts.build_databases import combine_sql

sys.path.remove(str(APP_DIR / "features"))


class DatabaseAdapter:
    def __init__(self, path: Path) -> None:
        self.path = path

    def _connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(self.path)
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA foreign_keys = ON")
        return connection


class SwitchingWorkspaceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.db_path = Path(self.temp.name) / "device_network.db"
        schema = combine_sql(APP_DIR / "infrastructure" / "database" / "schemas" / "device_network")
        with closing(sqlite3.connect(self.db_path)) as connection:
            connection.executescript(schema)
            connection.executemany(
                "INSERT INTO t01_devices(host, role, device_type) VALUES (?, ?, ?)",
                (("sw2.local", "sw2", "unknown"), ("sw3.local", "sw3", "unknown")),
            )
            connection.executemany(
                "INSERT INTO t06_vlan_db(host, vlan_id, vlan_name) VALUES (?, ?, ?)",
                (
                    ("sw2.local", 1, "default"),
                    ("sw2.local", 10, "users"),
                    ("sw3.local", 10, "users"),
                ),
            )
            connection.commit()
        self.db = DatabaseAdapter(self.db_path)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def test_navigation_only_exposes_working_role_aware_features(self) -> None:
        sw2 = navigation_for_role("sw2")
        sw3 = navigation_for_role("sw3")
        self.assertEqual(
            [item["id"] for item in sw2],
            ["interfaces", "switching", "security", "monitoring"],
        )
        self.assertNotIn(
            "stp",
            next(item for item in sw2 if item["id"] == "switching")["subfeatures"],
        )
        self.assertIn("services", [item["id"] for item in sw3])
        self.assertEqual(
            next(item for item in sw3 if item["id"] == "interfaces")["subfeatures"],
            ["switchPorts", "routedPorts", "svi"],
        )

    def test_pre_merge_switch_schema_is_upgraded_without_data_loss(self) -> None:
        legacy_path = Path(self.temp.name) / "legacy_switch.db"
        with closing(sqlite3.connect(legacy_path)) as connection:
            connection.executescript(
                """
                PRAGMA foreign_keys = ON;
                CREATE TABLE t01_devices (
                    host TEXT PRIMARY KEY,
                    role TEXT
                );
                CREATE TABLE t06_vlan_db (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    host TEXT NOT NULL,
                    vlan_id INTEGER NOT NULL,
                    UNIQUE(host, vlan_id),
                    FOREIGN KEY (host) REFERENCES t01_devices(host)
                );
                CREATE TABLE t06_svi_interface (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    host TEXT NOT NULL,
                    vlan_id INTEGER NOT NULL,
                    ip_address TEXT,
                    subnet_mask TEXT,
                    shutdown INTEGER DEFAULT 0,
                    success INTEGER DEFAULT 0,
                    FOREIGN KEY (host) REFERENCES t01_devices(host),
                    FOREIGN KEY (host, vlan_id) REFERENCES t06_vlan_db(host, vlan_id)
                );
                INSERT INTO t01_devices(host, role) VALUES ('legacy-sw3', 'sw3');
                INSERT INTO t06_vlan_db(host, vlan_id) VALUES ('legacy-sw3', 10);
                INSERT INTO t06_svi_interface(host, vlan_id, ip_address)
                VALUES ('legacy-sw3', 10, '192.0.2.1');
                """
            )
            connection.commit()

        legacy = DatabaseAdapter(legacy_path)
        ensure_switch_schema(legacy)
        with closing(legacy._connect()) as connection:
            l3_table = connection.execute(
                "SELECT name FROM sqlite_master "
                "WHERE type='table' AND name='t06_switch_l3_config'"
            ).fetchone()
            svi = connection.execute(
                "SELECT host, vlan_id, ip_address FROM t06_svi_interface"
            ).fetchone()
            unique_indexes = [
                row
                for row in connection.execute("PRAGMA index_list(t06_svi_interface)")
                if row[2]
            ]

        self.assertIsNotNone(l3_table)
        self.assertEqual(tuple(svi), ("legacy-sw3", 10, "192.0.2.1"))
        self.assertTrue(unique_indexes)

    def test_vlan_and_interface_mode_change_are_transactional(self) -> None:
        vlan_result = save_vlan(
            self.db,
            "sw2.local",
            {"vlan_id": 20, "vlan_name": "voice", "state": "active"},
        )
        self.assertTrue(vlan_result["ok"], vlan_result)
        self.assertEqual(
            [row["vlan_id"] for row in get_vlans(self.db, "sw2.local")],
            [1, 10, 20],
        )

        created = save_switch_interface(
            self.db,
            "sw2.local",
            {
                "if_name": "GigabitEthernet0/1",
                "mode": "access",
                "access_vlan": 10,
                "portfast": "enabled",
                "port_security_enabled": True,
                "max_mac": 2,
            },
        )
        self.assertTrue(created["ok"], created)

        rejected = save_switch_interface(
            self.db,
            "sw2.local",
            {
                "id": created["id"],
                "if_name": "GigabitEthernet0/1",
                "mode": "trunk",
                "native_vlan": 1,
                "allowed_vlans": "10,20",
                "port_security_enabled": True,
            },
        )
        self.assertFalse(rejected["ok"])
        self.assertEqual(get_switch_interfaces(self.db, "sw2.local")[0]["mode"], "access")

        updated = save_switch_interface(
            self.db,
            "sw2.local",
            {
                "id": created["id"],
                "if_name": "GigabitEthernet0/1",
                "mode": "trunk",
                "native_vlan": 1,
                "allowed_vlans": "10,20",
                "port_security_enabled": False,
            },
        )
        self.assertTrue(updated["ok"], updated)
        row = get_switch_interfaces(self.db, "sw2.local")[0]
        self.assertEqual(row["mode"], "trunk")
        self.assertEqual(row["allowed_vlans"], "10,20")
        self.assertEqual(row["port_security_enabled"], 0)

    def test_layer3_features_are_restricted_to_sw3(self) -> None:
        denied = save_svi(
            self.db,
            "sw2.local",
            {
                "vlan_id": 10,
                "ip_address": "192.0.2.1",
                "subnet_mask": "255.255.255.0",
            },
        )
        self.assertFalse(denied["ok"])

        routing = save_ip_routing(self.db, "sw3.local", True)
        self.assertTrue(routing["ok"], routing)
        self.assertEqual(get_ip_routing(self.db, "sw3.local")["ip_routing"], 1)

        saved = save_svi(
            self.db,
            "sw3.local",
            {
                "vlan_id": 10,
                "ip_address": "192.0.2.1",
                "subnet_mask": "255.255.255.0",
            },
        )
        self.assertTrue(saved["ok"], saved)
        self.assertEqual(get_svis(self.db, "sw3.local")[0]["vlan_id"], 10)
        duplicate = save_svi(
            self.db,
            "sw3.local",
            {
                "vlan_id": 10,
                "ip_address": "192.0.2.2",
                "subnet_mask": "255.255.255.0",
            },
        )
        self.assertFalse(duplicate["ok"])

    def test_routed_ports_are_restricted_to_sw3(self) -> None:
        denied = save_switch_interface(
            self.db,
            "sw2.local",
            {"if_name": "GigabitEthernet0/2", "mode": "routed"},
        )
        self.assertFalse(denied["ok"])
        saved = save_switch_interface(
            self.db,
            "sw3.local",
            {"if_name": "GigabitEthernet0/2", "mode": "routed"},
        )
        self.assertTrue(saved["ok"], saved)

    def test_new_switch_modules_do_not_expose_push_actions(self) -> None:
        roots = (
            APP_DIR / "features" / "switching",
            APP_DIR / "UI" / "qml" / "features" / "switching",
        )
        forbidden = (
            "pushViewPush",
            "ViewPushButton",
            "previewViewPush",
            "push_pending_config",
        )
        for root in roots:
            if not root.exists():
                continue
            for path in root.rglob("*"):
                if path.suffix not in {".py", ".qml"}:
                    continue
                source = path.read_text(encoding="utf-8")
                for token in forbidden:
                    with self.subTest(path=path.name, token=token):
                        self.assertNotIn(token, source)

        workspace_source = (
            APP_DIR / "UI" / "qml" / "features" / "switching" / "SwitchWorkspace.qml"
        ).read_text(encoding="utf-8")
        self.assertIn('objectName: "switchSubFeatureBar"', workspace_source)
        self.assertIn("SubBar {", workspace_source)
        self.assertNotIn("StandardButton {", workspace_source)
        self.assertNotIn(
            'type: root.subFeature === modelData ? "Secondary" : "Ghost"',
            workspace_source,
        )


if __name__ == "__main__":
    unittest.main()
