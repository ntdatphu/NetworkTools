"""Regression tests for the app-native router-interface push pipeline."""

from __future__ import annotations

import sqlite3
import tempfile
import unittest
from contextlib import closing
from pathlib import Path

from features.interfaces.view_push import InterfaceViewPushController


APP_DIR = Path(__file__).resolve().parents[1]


class _Connection:
    def __init__(self) -> None:
        self.commands: list[str] = []
        self.output = "configuration accepted"

    def send_config_set(self, commands, **_kwargs):
        self.commands.extend(commands)
        return self.output


class _Connector:
    def __init__(self) -> None:
        self.connection = _Connection()


class _Database:
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


class _Controller(InterfaceViewPushController):
    def __init__(self, db: _Database, connector: _Connector) -> None:
        super().__init__(db)
        self.connector = connector

    def _session_provider_for_host(self, _host: str):
        return lambda _target: self.connector


class InterfaceViewPushTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.db_path = Path(self.temp.name) / "device_network.db"
        schemas = (
            APP_DIR
            / "infrastructure"
            / "database"
            / "schemas"
            / "device_network"
        )
        with closing(sqlite3.connect(self.db_path)) as connection:
            connection.execute("PRAGMA foreign_keys = ON")
            for name in ("01_core_devices.sql", "02_interface_router_l3.sql"):
                connection.executescript(
                    (schemas / name).read_text(encoding="utf-8")
                )
            connection.execute(
                """
                INSERT INTO t01_devices(host, os, method, device_type)
                VALUES ('10.0.0.1', 'cisco', 'SSH', 'router');
                """
            )
            iface_id = connection.execute(
                """
                INSERT INTO t02_interface_name(
                    host, interface_name, ip_address, subnet_mask,
                    description, shutdown, sync_status
                ) VALUES (
                    '10.0.0.1', 'GigabitEthernet0/0',
                    '192.0.2.1', '255.255.255.0', 'WAN uplink', 0, 'pending_apply'
                );
                """
            ).lastrowid
            connection.execute(
                """
                INSERT INTO t02_router_iface_l3(
                    iface_id, secondary_ip, secondary_mask, mtu, bandwidth,
                    speed, duplex, negotiation, proxy_arp, unreachables,
                    directed_broadcast, sync_status, action_Cfg
                ) VALUES (
                    ?, '198.51.100.1', '255.255.255.0', 1600, 100000,
                    '1000', 'full', 0, 0, 1, 1, 'pending_apply', '11111'
                );
                """,
                (iface_id,),
            )
            connection.commit()
        self.db = _Database(self.db_path)
        self.connector = _Connector()
        self.controller = _Controller(self.db, self.connector)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def _states(self) -> tuple[str, str]:
        with closing(self.db._connect()) as connection:
            base = str(connection.execute(
                "SELECT sync_status FROM t02_interface_name;"
            ).fetchone()[0])
            profile = str(connection.execute(
                "SELECT sync_status FROM t02_router_iface_l3;"
            ).fetchone()[0])
        return base, profile

    def test_preview_renders_full_l3_profile_without_transport(self) -> None:
        preview = self.controller.preview("10.0.0.1", "all")
        self.assertTrue(preview["ok"], preview)
        self.assertIn("interface GigabitEthernet0/0", preview["commands"])
        self.assertIn("ip address 192.0.2.1 255.255.255.0", preview["commands"])
        self.assertIn(
            "ip address 198.51.100.1 255.255.255.0 secondary",
            preview["commands"],
        )
        self.assertIn("mtu 1600", preview["commands"])
        self.assertIn("speed 1000", preview["commands"])
        self.assertIn("no negotiation auto", preview["commands"])
        self.assertEqual(self.connector.connection.commands, [])

    def test_successful_push_marks_base_and_profile_applied(self) -> None:
        result = self.controller.push("10.0.0.1", "all")
        self.assertTrue(result["ok"], result)
        self.assertEqual(self._states(), ("synchronized", "synchronized"))
        self.assertFalse(self.controller.has_pending("10.0.0.1", "all"))

    def test_device_error_keeps_database_pending(self) -> None:
        self.connector.connection.output = "% Invalid input detected"
        result = self.controller.push("10.0.0.1", "all")
        self.assertFalse(result["ok"])
        self.assertEqual(self._states(), ("pending_apply", "pending_apply"))

    def test_removed_interface_is_deleted_only_after_success(self) -> None:
        with closing(self.db._connect()) as connection:
            connection.execute("UPDATE t02_interface_name SET sync_status = 'pending_delete';")
            connection.execute("UPDATE t02_router_iface_l3 SET sync_status = 'pending_delete';")
            connection.commit()

        preview = self.controller.preview("10.0.0.1", "all")
        self.assertIn("no ip address", preview["commands"])
        self.assertIn("shutdown", preview["commands"])
        result = self.controller.push("10.0.0.1", "all")
        self.assertTrue(result["ok"], result)
        with closing(self.db._connect()) as connection:
            count = connection.execute(
                "SELECT COUNT(*) FROM t02_interface_name;"
            ).fetchone()[0]
        self.assertEqual(count, 0)

    def test_wan_password_is_redacted_from_preview_tasks_and_device_log(self) -> None:
        with closing(self.db._connect()) as connection:
            iface_id = int(
                connection.execute(
                    "SELECT iface_id FROM t02_interface_name;"
                ).fetchone()[0]
            )
            connection.execute(
                "DELETE FROM t02_router_iface_l3 WHERE iface_id = ?;",
                (iface_id,),
            )
            connection.execute(
                """
                INSERT INTO t02_router_iface_wan(
                    iface_id, encap_type, ppp_auth, ppp_username,
                    ppp_password, sync_status, action_Cfg
                ) VALUES (?, 'ppp', 'chap', 'lab-user', 'lab-secret', 'pending_apply', '11');
                """,
                (iface_id,),
            )
            connection.commit()

        preview = self.controller.preview("10.0.0.1", "all")
        self.assertNotIn("lab-secret", str(preview))
        self.assertIn("ppp chap password <redacted>", preview["commands"])
        self.connector.connection.output = "ppp chap password 0 lab-secret"
        result = self.controller.push("10.0.0.1", "all")
        self.assertTrue(result["ok"], result)
        self.assertNotIn("lab-secret", str(result))


if __name__ == "__main__":
    unittest.main()
