from __future__ import annotations

import sqlite3
import sys
import tempfile
import unittest
from contextlib import closing
from pathlib import Path


APP_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(APP_DIR))

from features.switching.push_state_repository import is_payload_pending  # noqa: E402
from features.switching.view_push import SwitchingViewPushController  # noqa: E402
from scripts.build_databases import combine_sql  # noqa: E402


class FakeConnection:
    def __init__(self) -> None:
        self.commands: list[str] = []

    def send_config_set(self, commands, **_kwargs):
        self.commands.extend(commands)
        return "configuration accepted"


class FakeConnector:
    def __init__(self) -> None:
        self.connection = FakeConnection()


class DatabaseAdapter:
    def __init__(self, path: Path) -> None:
        self.path = path

    def _connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(self.path)
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA foreign_keys = ON")
        return connection

    def _routing_device_context(self, _host: str) -> dict[str, str]:
        return {
            "platform": "cisco_ios",
            "template_folder": "cisco_ios",
            "method": "SSH",
        }


class TestController(SwitchingViewPushController):
    __test__ = False

    def __init__(self, db, connector):
        super().__init__(db)
        self.connector = connector

    def _session_provider_for_host(self, _host):
        return lambda _target: self.connector


class SwitchingViewPushTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.db_path = Path(self.temp.name) / "device_network.db"
        schema = combine_sql(
            APP_DIR / "infrastructure" / "database" / "schemas" / "device_network"
        )
        with closing(sqlite3.connect(self.db_path)) as conn:
            conn.executescript(schema)
            conn.execute(
                """
                INSERT INTO t01_devices(host, role, os, method, device_type)
                VALUES ('sw2.local', 'sw2', 'cisco_ios', 'SSH', 'switch');
                """
            )
            conn.executemany(
                """
                INSERT INTO t06_vlan_db(host, vlan_id, vlan_name, state)
                VALUES ('sw2.local', ?, ?, 'active');
                """,
                ((1, "default"), (10, "users")),
            )
            iface_id = conn.execute(
                """
                INSERT INTO t06_interface_l2(host, if_name, mode)
                VALUES ('sw2.local', 'GigabitEthernet0/1', 'access');
                """
            ).lastrowid
            conn.execute(
                "INSERT INTO t06_iface_access(iface_id, access_vlan) VALUES (?, 10);",
                (iface_id,),
            )
            conn.execute(
                """
                INSERT INTO t06_iface_stp(iface_id, portfast, bpduguard)
                VALUES (?, 'enabled', 'enabled');
                """,
                (iface_id,),
            )
            conn.execute(
                """
                INSERT INTO t06_iface_port_security(iface_id, max_mac, sticky)
                VALUES (?, 2, 1);
                """,
                (iface_id,),
            )
            conn.execute(
                """
                INSERT INTO t06_etherchannel(
                    host, po_number, protocol, mode, member_ports, description
                ) VALUES (
                    'sw2.local', 1, 'lacp', 'active',
                    'GigabitEthernet0/1', 'Uplink'
                );
                """
            )
            domain_id = conn.execute(
                """
                INSERT INTO t09_vtp_domains(domain_name, version)
                VALUES ('LAB', 2);
                """
            ).lastrowid
            switch_id = conn.execute(
                """
                INSERT INTO t09_vtp_switches(vtp_domain_id, host, pruning)
                VALUES (?, 'sw2.local', 1);
                """,
                (domain_id,),
            ).lastrowid
            conn.execute(
                """
                INSERT INTO t09_vtp_database_modes(vtp_switch_id, database_type, mode)
                VALUES (?, 'vlan', 'server');
                """,
                (switch_id,),
            )
            conn.commit()
        self.db = DatabaseAdapter(self.db_path)
        self.connector = FakeConnector()
        self.controller = TestController(self.db, self.connector)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def test_preview_combines_layer2_modules_without_opening_a_session(self) -> None:
        preview = self.controller.preview("sw2.local", "all")
        self.assertTrue(preview["ok"], preview)
        self.assertIn("vlan 10", preview["commands"])
        self.assertIn("switchport access vlan 10", preview["commands"])
        self.assertIn("channel-group 1 mode active", preview["commands"])
        self.assertIn("spanning-tree portfast", preview["commands"])
        self.assertIn("vtp domain LAB", preview["commands"])
        self.assertIn("switchport port-security maximum 2", preview["commands"])
        self.assertEqual(self.connector.connection.commands, [])

    def test_successful_push_marks_hash_and_a_change_becomes_pending(self) -> None:
        result = self.controller.push("sw2.local", "all")
        self.assertTrue(result["ok"], result)
        self.assertIn("vlan 10", self.connector.connection.commands)
        self.assertFalse(self.controller.has_pending("sw2.local", "all"))

        with closing(self.db._connect()) as conn:
            conn.execute(
                """
                UPDATE t06_vlan_db SET vlan_name = 'staff'
                WHERE host = 'sw2.local' AND vlan_id = 10;
                """
            )
            conn.commit()

        self.assertTrue(self.controller.has_pending("sw2.local", "vlan"))

    def test_failed_device_output_does_not_mark_payload(self) -> None:
        self.connector.connection.send_config_set = (
            lambda _commands, **_kwargs: "% Invalid input detected"
        )
        task = self.controller.collect_pending_tasks("sw2.local", "vlan")[0]
        result = self.controller.push_tasks("sw2.local", "vlan", [task])
        self.assertFalse(result["ok"])
        self.assertTrue(
            is_payload_pending(self.db, "sw2.local", "vlan", task["config"])
        )


if __name__ == "__main__":
    unittest.main()
