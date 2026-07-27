from __future__ import annotations

import sqlite3
import tempfile
import unittest
from contextlib import closing
from pathlib import Path
from typing import Any

from features.acl import get_acls, save_acl
from features.acl.collector import collect_acl_tasks
from features.acl.dispatcher import apply_acl_results
from features.acl.worker import render_acl_payload


APP_DIR = Path(__file__).resolve().parents[1]


class _Database:
    def __init__(self, path: Path) -> None:
        self.path = path

    def _connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(self.path)
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA foreign_keys = ON")
        return connection


class AclViewPushTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.db_path = Path(self.temp.name) / "device_network.db"
        schemas = APP_DIR / "infrastructure" / "database" / "schemas" / "device_network"
        with closing(sqlite3.connect(self.db_path)) as connection:
            connection.execute("PRAGMA foreign_keys = ON")
            for name in ("01_core_devices.sql", "02_interface_router_l3.sql", "05_security_nat.sql"):
                connection.executescript((schemas / name).read_text(encoding="utf-8"))
            connection.execute(
                "INSERT INTO t01_devices(host, os, method, dev) VALUES ('10.0.0.1', 'cisco', 'SSH', 1)"
            )
            connection.execute(
                "INSERT INTO t02_interface_name(host, interface_name) VALUES ('10.0.0.1', 'GigabitEthernet0/0')"
            )
            connection.commit()
        self.db = _Database(self.db_path)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def _save(self, acl_id: int, sequence: int, source: str) -> None:
        with closing(self.db._connect()) as connection:
            iface_id = int(connection.execute("SELECT iface_id FROM t02_interface_name").fetchone()[0])
        self.assertTrue(save_acl(self.db, {
            "acl_id": acl_id,
            "host": "10.0.0.1",
            "acl_name": "EDGE_IN",
            "acl_type": "standard",
            "description": "edge filter",
            "rules": [{
                "sequence": sequence,
                "action": "permit",
                "source": source,
                "wildcard": "0.0.0.255",
            }],
            "bindings": [{"iface_id": iface_id, "direction": "in"}],
        }))

    def test_collect_render_and_apply_new_acl(self) -> None:
        self._save(0, 10, "192.168.1.0")
        tasks = collect_acl_tasks("10.0.0.1", str(self.db_path))
        self.assertEqual(len(tasks), 1)
        commands = render_acl_payload(tasks[0])
        self.assertIn("ip access-list standard EDGE_IN", commands)
        self.assertIn("10 permit 192.168.1.0 0.0.0.255", commands)
        self.assertIn("ip access-group EDGE_IN in", commands)

        report = apply_acl_results(
            tasks,
            [{"target": "10.0.0.1", "status": "success", "message": "simulated"}],
            str(self.db_path),
        )
        self.assertEqual(report[0]["status"], "SUCCESS")
        self.assertEqual(collect_acl_tasks("10.0.0.1", str(self.db_path)), [])

    def test_edit_renders_rule_replacement(self) -> None:
        self._save(0, 10, "192.168.1.0")
        first_tasks = collect_acl_tasks("10.0.0.1", str(self.db_path))
        apply_acl_results(
            first_tasks,
            [{"target": "10.0.0.1", "status": "success", "message": "simulated"}],
            str(self.db_path),
        )
        acl_id = int(get_acls(self.db, "10.0.0.1", "standard")[0]["Acl_id"])
        self._save(acl_id, 20, "198.51.100.0")

        tasks = collect_acl_tasks("10.0.0.1", str(self.db_path))
        commands = render_acl_payload(tasks[0])
        self.assertIn("no 10", commands)
        self.assertIn("20 permit 198.51.100.0 0.0.0.255", commands)
