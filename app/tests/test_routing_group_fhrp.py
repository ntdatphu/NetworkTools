from __future__ import annotations

import sqlite3
import tempfile
import unittest
from pathlib import Path

from core.database.conversion import ConversionMixin
from features.fhrp.collector import collect_fhrp_tasks
from features.fhrp.commands import redact_fhrp_commands, render_fhrp_commands
from features.fhrp.service import FhrpService
from features.routing.group_service import RoutingGroupService
from infrastructure.database.paths import DEVICE_NETWORK_SCHEMA_DIR
from scripts.build_databases import build_database


class _ClosingConnection(sqlite3.Connection):
    """Match DatabaseManager's close-on-transaction-exit connection."""

    def __exit__(self, exc_type, exc, traceback):
        try:
            return bool(super().__exit__(exc_type, exc, traceback))
        finally:
            self.close()


class _Db(ConversionMixin):
    def __init__(self, path: Path) -> None:
        self.path = path

    def _connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(self.path, factory=_ClosingConnection)
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA foreign_keys = ON;")
        return connection


class RoutingGroupAndFhrpTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.db_path = Path(self.temp.name) / "device_network.db"
        build_database(DEVICE_NETWORK_SCHEMA_DIR, self.db_path)
        self.db = _Db(self.db_path)
        with self.db._connect() as connection:
            for index, host in enumerate(("10.0.0.1", "10.0.0.2"), start=1):
                connection.execute(
                    """
                    INSERT INTO t01_devices (
                        host, device_name, method, os, role,
                        device_type, connection_status
                    ) VALUES (?, ?, 'SSH', 'cisco', 'rou', 'router', 'connected');
                    """,
                    (host, f"R{index}"),
                )
                connection.execute(
                    """
                    INSERT INTO t02_interface_name (
                        host, interface_name, ip_address, subnet_mask, sync_status
                    ) VALUES (?, 'GigabitEthernet0/0', ?, '255.255.255.0', 'synchronized');
                    """,
                    (host, f"192.168.10.{index + 1}"),
                )
            connection.commit()

    def tearDown(self) -> None:
        self.temp.cleanup()

    def test_routing_group_filters_and_saves_host_owned_networks(self) -> None:
        service = RoutingGroupService(self.db)
        hosts = service.options()["hosts"]
        self.assertEqual([row["host"] for row in hosts], ["10.0.0.1", "10.0.0.2"])
        targets = []
        for index, host in enumerate(hosts, start=1):
            network = host["networks"][0]
            targets.append(
                {
                    "host": host["host"],
                    "process_id": index,
                    "router_id": f"1.1.1.{index}",
                    "networks": [
                        {
                            "network": network["network"],
                            "wildcard": network["wildcard"],
                            "area": 0,
                        }
                    ],
                }
            )

        result = service.save(
            "ospf",
            targets,
            {"reference_bandwidth": 1000, "authentication_cfg": True},
        )

        self.assertTrue(result["ok"], result)
        with self.db._connect() as connection:
            self.assertEqual(
                connection.execute("SELECT COUNT(*) FROM t04_ospf_processes").fetchone()[0],
                2,
            )
            self.assertEqual(
                connection.execute(
                    "SELECT COUNT(*) FROM t04_ospf_areas WHERE authentication = 'message-digest'"
                ).fetchone()[0],
                2,
            )

    def test_routing_group_rejects_more_than_five_hosts(self) -> None:
        result = RoutingGroupService(self.db).save(
            "ospf",
            [
                {"host": f"10.0.0.{index}", "process_id": index, "networks": []}
                for index in range(1, 7)
            ],
            {},
        )

        self.assertFalse(result["ok"])
        self.assertEqual(result["message"], "Routing Group supports at most 5 hosts")

    def test_routing_group_partial_result_names_each_failed_host_and_reason(self) -> None:
        with self.db._connect() as connection:
            connection.execute(
                """
                INSERT INTO t04_ospf_processes (
                    host, process_id, router_id, sync_status
                ) VALUES ('10.0.0.1', 1, '1.1.1.1', 'synchronized');
                """
            )
            connection.commit()

        result = RoutingGroupService(self.db).save(
            "ospf",
            [
                {
                    "host": "10.0.0.1",
                    "process_id": 1,
                    "networks": [
                        {
                            "network": "192.168.10.0",
                            "wildcard": "0.0.0.255",
                            "area": 0,
                        }
                    ],
                },
                {
                    "host": "10.0.0.2",
                    "process_id": 1,
                    "networks": [
                        {
                            "network": "192.168.10.0",
                            "wildcard": "0.0.0.255",
                            "area": 0,
                        }
                    ],
                },
            ],
            {},
        )

        self.assertTrue(result["partial"])
        self.assertEqual(result["successful"], ["10.0.0.2"])
        self.assertIn("10.0.0.1: process_id 1 already exists", result["message"])
        self.assertNotIn("closed database", result["message"])

    def test_routing_group_retry_reuses_a_locally_pending_ospf_process(self) -> None:
        with self.db._connect() as connection:
            connection.execute(
                """
                INSERT INTO t04_ospf_processes (
                    host, process_id, router_id, sync_status
                ) VALUES ('10.0.0.1', 1, '1.1.1.1', 'pending_apply');
                """
            )
            connection.commit()

        targets = [
            {
                "host": host,
                "process_id": 1,
                "router_id": router_id,
                "networks": [
                    {
                        "network": "192.168.10.0",
                        "wildcard": "0.0.0.255",
                        "area": 0,
                    }
                ],
            }
            for host, router_id in (
                ("10.0.0.1", "1.1.1.1"),
                ("10.0.0.2", "2.2.2.2"),
            )
        ]

        result = RoutingGroupService(self.db).save("ospf", targets, {})

        self.assertTrue(result["ok"], result)
        self.assertEqual(result["successful"], ["10.0.0.1", "10.0.0.2"])

    def test_fhrp_filters_interface_and_builds_multi_host_hsrp(self) -> None:
        service = FhrpService(self.db)
        candidates = service.matching_interfaces(
            ["10.0.0.1", "10.0.0.2"], "192.168.10.1"
        )
        self.assertTrue(candidates["ok"])
        self.assertEqual(len(candidates["interfaces"]), 2)
        members = [
            {
                "host": row["host"],
                "iface_id": row["iface_id"],
                "priority": 110 - index,
                "preempt": True,
                "auth_type": "md5-key",
                "auth_secret": "private-key",
            }
            for index, row in enumerate(candidates["interfaces"])
        ]

        result = service.save(
            {
                "protocol": "hsrp",
                "group_number": 10,
                "default_gateway": "192.168.10.1",
                "members": members,
            }
        )

        self.assertTrue(result["ok"], result)
        tasks = collect_fhrp_tasks(self.db, "10.0.0.1")
        self.assertEqual(len(tasks), 1)
        commands = render_fhrp_commands(tasks[0])
        self.assertIn("standby 10 ip 192.168.10.1", commands)
        preview = "\n".join(redact_fhrp_commands(commands))
        self.assertNotIn("private-key", preview)
        self.assertIn("<redacted>", preview)

        deleted = service.delete(result["fhrp_id"])
        self.assertTrue(deleted["ok"], deleted)
        self.assertEqual(collect_fhrp_tasks(self.db, "10.0.0.1"), [])
        self.assertEqual(collect_fhrp_tasks(self.db, "10.0.0.2"), [])
        with self.db._connect() as connection:
            self.assertEqual(
                connection.execute(
                    "SELECT COUNT(*) FROM t08_fhrp_groups WHERE fhrp_id = ?",
                    (result["fhrp_id"],),
                ).fetchone()[0],
                0,
            )

    def test_fhrp_delete_preserves_remove_push_for_synchronized_members(self) -> None:
        service = FhrpService(self.db)
        candidates = service.matching_interfaces(
            ["10.0.0.1", "10.0.0.2"], "192.168.10.1"
        )["interfaces"]
        result = service.save({
            "protocol": "vrrp",
            "group_number": 20,
            "default_gateway": "192.168.10.1",
            "members": [
                {
                    "host": row["host"],
                    "iface_id": row["iface_id"],
                    "priority": 100,
                    "preempt": True,
                }
                for row in candidates
            ],
        })
        self.assertTrue(result["ok"], result)
        with self.db._connect() as connection:
            connection.execute(
                "UPDATE t08_fhrp_members SET sync_status = 'synchronized' "
                "WHERE fhrp_id = ?",
                (result["fhrp_id"],),
            )
            connection.commit()

        deleted = service.delete(result["fhrp_id"])

        self.assertTrue(deleted["ok"], deleted)
        for host in ("10.0.0.1", "10.0.0.2"):
            tasks = collect_fhrp_tasks(self.db, host)
            self.assertEqual(len(tasks), 1)
            self.assertEqual(tasks[0]["action"], "remove")
            self.assertIn("no vrrp 20", render_fhrp_commands(tasks[0]))

    def test_fhrp_delete_handles_partially_pushed_multi_host_group(self) -> None:
        service = FhrpService(self.db)
        candidates = service.matching_interfaces(
            ["10.0.0.1", "10.0.0.2"], "192.168.10.1"
        )["interfaces"]
        result = service.save({
            "protocol": "glbp",
            "group_number": 30,
            "default_gateway": "192.168.10.1",
            "members": [
                {"host": row["host"], "iface_id": row["iface_id"]}
                for row in candidates
            ],
        })
        self.assertTrue(result["ok"], result)
        with self.db._connect() as connection:
            connection.execute(
                "UPDATE t08_fhrp_members SET sync_status = 'synchronized' "
                "WHERE fhrp_id = ? AND host = '10.0.0.1'",
                (result["fhrp_id"],),
            )
            connection.commit()

        self.assertTrue(service.delete(result["fhrp_id"])["ok"])

        pushed_tasks = collect_fhrp_tasks(self.db, "10.0.0.1")
        self.assertEqual(len(pushed_tasks), 1)
        self.assertEqual(pushed_tasks[0]["action"], "remove")
        self.assertEqual(collect_fhrp_tasks(self.db, "10.0.0.2"), [])

    def test_gateway_cannot_equal_a_member_interface_address(self) -> None:
        result = FhrpService(self.db).matching_interfaces(
            ["10.0.0.1"], "192.168.10.2"
        )
        self.assertTrue(result["ok"])
        self.assertEqual(result["interfaces"], [])


if __name__ == "__main__":
    unittest.main()
