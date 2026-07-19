from __future__ import annotations

import sqlite3
import sys
import tempfile
import unittest
from contextlib import closing
from pathlib import Path

APP_DIR = Path(__file__).resolve().parents[1]
BACKEND_DIR = APP_DIR / "features"
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from nat import (
    add_nat_acl,
    add_nat_dynamic_pool,
    add_nat_interface,
    add_nat_pat_rule,
    add_nat_route_map_entry,
    add_nat_static_entry,
    delete_nat_acl,
    delete_nat_dynamic_pool,
    delete_nat_interface,
    delete_nat_pat_rule,
    delete_nat_route_map_entry,
    delete_nat_static_entry,
    get_nat_acls,
    get_nat_acl_names,
    get_nat_dynamic_pools,
    get_nat_interfaces,
    get_nat_pat_rules,
    get_nat_route_map_entries,
    get_nat_static_entries,
)


class _Database:
    def __init__(self, path: Path) -> None:
        self.path = path

    def _connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(self.path)
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA foreign_keys = ON")
        return connection


class NatPersistenceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.db_path = Path(self.temp.name) / "device_network.db"
        schema = (APP_DIR / "infrastructure" / "database" / "aggregates" / "device_network.sql").read_text(encoding="utf-8-sig")
        with closing(sqlite3.connect(self.db_path)) as connection:
            connection.executescript(schema)
            connection.execute(
                """
                INSERT INTO t01_devices
                    (host, device_name, method, portnumber, username, password, os, role, success, dev)
                VALUES ('r1', 'Router 1', 'SSH', 22, 'user', 'pass', 'cisco_ios', 'router', 1, 1);
                """
            )
            connection.commit()
        self.db = _Database(self.db_path)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def _success(self, table: str, id_column: str, row_id: int) -> int:
        with closing(sqlite3.connect(self.db_path)) as connection:
            return int(connection.execute(
                f"SELECT success FROM {table} WHERE {id_column} = ?",
                (row_id,),
            ).fetchone()[0])

    def test_static_save_load_and_soft_delete(self) -> None:
        self.assertTrue(add_nat_static_entry(self.db, "r1", "10.0.0.10", "203.0.113.10", "TCP", "80", "8080"))
        rows = get_nat_static_entries(self.db, "r1")
        self.assertEqual((rows[0]["inside_local"], rows[0]["inside_global"]), ("10.0.0.10", "203.0.113.10"))
        row_id = rows[0]["nat_static_id"]
        self.assertEqual(self._success("t05_nat_static_mappings", "id", row_id), 0)
        self.assertTrue(delete_nat_static_entry(self.db, row_id))
        self.assertEqual(get_nat_static_entries(self.db, "r1"), [])
        self.assertEqual(self._success("t05_nat_static_mappings", "id", row_id), -1)

    def test_interface_save_load_delete_and_reactivate(self) -> None:
        self.assertTrue(add_nat_interface(self.db, "r1", "GigabitEthernet0/0", "inside"))
        row = get_nat_interfaces(self.db, "r1")[0]
        self.assertEqual((row["interface_name"], row["direction"]), ("GigabitEthernet0/0", "inside"))
        row_id = row["nat_intf_id"]
        self.assertTrue(delete_nat_interface(self.db, row_id))
        self.assertTrue(add_nat_interface(self.db, "r1", "GigabitEthernet0/0", "outside"))
        row = get_nat_interfaces(self.db, "r1")[0]
        self.assertEqual((row["nat_intf_id"], row["direction"], row["success"]), (row_id, "outside", 0))

    def test_dynamic_pool_persists_acl_relationship(self) -> None:
        self.assertTrue(add_nat_dynamic_pool(
            self.db, "r1", "PUBLIC", "203.0.113.1", "203.0.113.10", "255.255.255.0", "NAT_ACL"
        ))
        row = get_nat_dynamic_pools(self.db, "r1")[0]
        self.assertEqual(row["acl_name"], "NAT_ACL")
        row_id = row["nat_dynamic_id"]
        self.assertTrue(delete_nat_dynamic_pool(self.db, row_id))
        self.assertEqual(get_nat_dynamic_pools(self.db, "r1"), [])
        self.assertEqual(self._success("t05_nat_pools", "pool_id", row_id), -1)

    def test_pat_interface_and_pool_round_trip(self) -> None:
        self.assertTrue(add_nat_dynamic_pool(
            self.db, "r1", "PUBLIC", "203.0.113.1", "203.0.113.10", "255.255.255.0", ""
        ))
        self.assertTrue(add_nat_pat_rule(self.db, "r1", "NAT_ACL", "Interface", "GigabitEthernet0/1", True))
        self.assertTrue(add_nat_pat_rule(self.db, "r1", "NAT_ACL", "Pool", "PUBLIC", True))
        rows = get_nat_pat_rules(self.db, "r1")
        self.assertEqual({(row["source_type"], row["source_value"]) for row in rows}, {
            ("Interface", "GigabitEthernet0/1"), ("Pool", "PUBLIC")
        })
        for row in rows:
            self.assertTrue(delete_nat_pat_rule(self.db, row["nat_pat_id"]))
        self.assertEqual(get_nat_pat_rules(self.db, "r1"), [])

    def test_acl_load_is_flat_for_qml_and_rule_delete_is_soft(self) -> None:
        self.assertTrue(add_nat_acl(self.db, "r1", "NAT_ACL", "permit", "10.0.0.0", "0.0.0.255"))
        self.assertEqual(get_nat_acl_names(self.db, "r1"), ["NAT_ACL"])
        row = get_nat_acls(self.db, "r1")[0]
        self.assertEqual((row["action"], row["source_network"], row["wildcard"]), (
            "permit", "10.0.0.0", "0.0.0.255"
        ))
        rule_id = row["rule_id"]
        self.assertTrue(delete_nat_acl(self.db, rule_id))
        self.assertEqual(get_nat_acls(self.db, "r1"), [])
        self.assertEqual(self._success("t05_nat_standard_acl_rules", "id", rule_id), -1)

    def test_route_map_save_load_soft_delete_and_reactivate(self) -> None:
        self.assertTrue(add_nat_acl(self.db, "r1", "NAT_ACL", "permit", "10.0.0.0", "0.0.0.255"))
        self.assertTrue(add_nat_route_map_entry(self.db, "r1", "NAT_EXEMPT", "test", 10, "permit", "NAT_ACL"))
        row = get_nat_route_map_entries(self.db, "r1")[0]
        self.assertEqual((row["nat_acl_name"], row["description"]), ("NAT_ACL", "test"))
        row_id = row["route_map_entry_id"]
        self.assertTrue(delete_nat_route_map_entry(self.db, row_id))
        self.assertEqual(get_nat_route_map_entries(self.db, "r1"), [])
        self.assertEqual(self._success("t05_route_map_entries", "id", row_id), -1)
        self.assertTrue(add_nat_route_map_entry(self.db, "r1", "NAT_EXEMPT", "updated", 10, "deny", "NAT_ACL"))
        row = get_nat_route_map_entries(self.db, "r1")[0]
        self.assertEqual((row["route_map_entry_id"], row["action"], row["description"]), (row_id, "deny", "updated"))


if __name__ == "__main__":
    unittest.main()
