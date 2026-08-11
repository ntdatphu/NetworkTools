"""Domain, persistence and command regressions for Router Interface."""

from __future__ import annotations

import sqlite3
import tempfile
import unittest
from contextlib import closing
from pathlib import Path
from typing import Any

from features.interfaces.collector import collect_interface_tasks
from features.interfaces.commands import render_interface_commands
from features.interfaces.models import canonical_interface_name
from features.interfaces.push_state import mark_interface_task_applied
from features.interfaces.repository import delete_router_interface
from features.interfaces.service import InterfaceService


APP_DIR = Path(__file__).resolve().parents[1]


class _Database:
    def __init__(self, path: Path) -> None:
        self.path = path

    def _connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(self.path)
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA foreign_keys = ON")
        return connection

    @staticmethod
    def _as_dict(value: Any) -> dict[str, Any]:
        return dict(value) if isinstance(value, dict) else {}

    @staticmethod
    def _dict_rows(rows: list[sqlite3.Row]) -> list[dict[str, Any]]:
        return [dict(row) for row in rows]

    @staticmethod
    def _int_or_none(value: Any) -> int | None:
        if value is None or str(value).strip() == "":
            return None
        try:
            return int(str(value).strip())
        except ValueError:
            return None

    @staticmethod
    def _bool_int(value: Any) -> int:
        if isinstance(value, str):
            return int(value.strip().lower() in {"1", "true", "yes", "on"})
        return int(bool(value))


class RouterInterfaceServiceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name) / "device_network.db"
        schema_dir = (
            APP_DIR / "infrastructure" / "database" / "schemas" / "device_network"
        )
        with closing(sqlite3.connect(self.path)) as connection:
            connection.execute("PRAGMA foreign_keys = ON")
            for name in ("01_core_devices.sql", "02_interface_router_l3.sql"):
                connection.executescript(
                    (schema_dir / name).read_text(encoding="utf-8")
                )
            connection.execute(
                "INSERT INTO t01_devices(host, role, os) VALUES (?, 'rou', 'cisco')",
                ("10.0.0.1",),
            )
            connection.execute(
                "INSERT INTO t02_interface_name(host, interface_name, sync_status) "
                "VALUES (?, ?, 'synchronized')",
                ("10.0.0.1", "GigabitEthernet0/0"),
            )
            connection.commit()
        self.db = _Database(self.path)
        self.service = InterfaceService(self.db)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def test_name_normalization_and_backend_physical_policy(self) -> None:
        self.assertEqual(canonical_interface_name(" gi 0/0 "), "GigabitEthernet0/0")
        rejected = self.service.save(
            {"host": "10.0.0.1", "interface_name": "Gi0/1", "interface_kind": "L3"}
        )
        self.assertFalse(rejected["ok"])
        self.assertIn("discovery/profile", rejected["message"])

        existing = self.service.save(
            {
                "host": "10.0.0.1",
                "interface_name": "Gi0/0",
                "interface_kind": "L3",
                "ip_address": "192.0.2.1",
                "subnet_mask": "/24",
            }
        )
        self.assertTrue(existing["ok"], existing)
        self.assertEqual(existing["interface"]["subnet_mask"], "255.255.255.0")
        self.assertFalse(existing["interface"]["can_delete"])
        self.assertFalse(
            delete_router_interface(self.db, existing["interface"]["iface_id"])
        )

    def test_loopback_is_virtual_and_omits_physical_line_commands(self) -> None:
        result = self.service.save(
            {
                "host": "10.0.0.1",
                "interface_name": "Lo0",
                "interface_kind": "L3",
                "ip_address": "10.255.0.1",
                "subnet_mask": "/32",
            }
        )
        self.assertTrue(result["ok"], result)
        self.assertEqual(result["interface"]["interface_name"], "Loopback0")
        self.assertTrue(result["interface"]["can_delete"])

        task = next(
            task
            for task in collect_interface_tasks(self.db, "10.0.0.1")
            if task["interface"]["interface_name"] == "Loopback0"
        )
        commands = render_interface_commands(task)
        self.assertNotIn("speed auto", commands)
        self.assertNotIn("duplex auto", commands)
        self.assertIn("ip address 10.255.0.1 255.255.255.255", commands)

    def test_tunnel_and_subinterface_validate_and_render(self) -> None:
        invalid_tunnel = self.service.save(
            {
                "host": "10.0.0.1",
                "interface_name": "Tunnel7",
                "interface_kind": "Tunnel",
                "tunnel_src": "Gi0/0",
                "tunnel_dst": "not-an-ip",
            }
        )
        self.assertFalse(invalid_tunnel["ok"])

        tunnel = self.service.save(
            {
                "host": "10.0.0.1",
                "interface_name": "Tunnel7",
                "interface_kind": "Tunnel",
                "ip_address": "172.16.0.1",
                "subnet_mask": "/30",
                "tunnel_src": "Gi0/0",
                "tunnel_dst": "198.51.100.2",
            }
        )
        self.assertTrue(tunnel["ok"], tunnel)
        self.assertEqual(tunnel["interface"]["tunnel_src"], "GigabitEthernet0/0")

        subinterface = self.service.save(
            {
                "host": "10.0.0.1",
                "interface_name": "Gi0/0.100",
                "interface_kind": "Subinterface",
                "parent_interface": "Gi0/0",
                "vlan_id": 100,
                "native": True,
                "ip_address": "192.168.100.1",
                "subnet_mask": "/24",
            }
        )
        self.assertTrue(subinterface["ok"], subinterface)
        row = subinterface["interface"]
        self.assertEqual(row["parent_interface"], "GigabitEthernet0/0")
        self.assertEqual(row["interface_type"], "subinterface")

        task = next(
            task
            for task in collect_interface_tasks(self.db, "10.0.0.1")
            if task["interface"]["interface_name"] == "GigabitEthernet0/0.100"
        )
        self.assertIn("encapsulation dot1Q 100 native", render_interface_commands(task))

    def test_virtual_delete_uses_no_interface_and_cleans_subinterface_row(self) -> None:
        created = self.service.save(
            {
                "host": "10.0.0.1",
                "interface_name": "Gi0/0.200",
                "interface_kind": "Subinterface",
                "parent_interface": "Gi0/0",
                "vlan_id": 200,
            }
        )
        self.assertTrue(created["ok"], created)
        self.assertTrue(
            delete_router_interface(self.db, created["interface"]["iface_id"])
        )
        task = next(
            task
            for task in collect_interface_tasks(self.db, "10.0.0.1")
            if task["interface"]["interface_name"] == "GigabitEthernet0/0.200"
        )
        self.assertEqual(
            render_interface_commands(task),
            ["no interface GigabitEthernet0/0.200"],
        )
        mark_interface_task_applied(self.db, task)
        with closing(self.db._connect()) as connection:
            base_count = connection.execute(
                "SELECT COUNT(*) FROM t02_interface_name WHERE interface_name = ?",
                ("GigabitEthernet0/0.200",),
            ).fetchone()[0]
            profile_count = connection.execute(
                "SELECT COUNT(*) FROM t02_router_iface_subif WHERE subif_name = ?",
                ("GigabitEthernet0/0.200",),
            ).fetchone()[0]
        self.assertEqual((base_count, profile_count), (0, 0))

    def test_subinterface_parent_failure_rolls_back_base_row(self) -> None:
        result = self.service.save(
            {
                "host": "10.0.0.1",
                "interface_name": "Gi0/9.300",
                "interface_kind": "Subinterface",
                "parent_interface": "Gi0/9",
                "vlan_id": 300,
            }
        )
        self.assertFalse(result["ok"])
        with closing(self.db._connect()) as connection:
            count = connection.execute(
                "SELECT COUNT(*) FROM t02_interface_name WHERE interface_name = ?",
                ("GigabitEthernet0/9.300",),
            ).fetchone()[0]
        self.assertEqual(count, 0)


if __name__ == "__main__":
    unittest.main()
