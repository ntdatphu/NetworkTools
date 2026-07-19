from __future__ import annotations

import sqlite3
import tempfile
import unittest
import sys
from contextlib import closing
from pathlib import Path
from typing import Any

APP_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(APP_DIR / "features"))

from features.routing.eigrp import get_eigrp_routing, save_eigrp_routing
from features.routing.ospf import get_ospf_routing, save_ospf_routing


class _DatabaseAdapter:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.error = ""

    def _connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(self.path)
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA foreign_keys = ON")
        return connection

    @staticmethod
    def _as_list(value: Any) -> list[Any]:
        return list(value or [])

    @staticmethod
    def _as_dict(value: Any) -> dict[str, Any]:
        return dict(value or {})

    @staticmethod
    def _dict_rows(rows: list[sqlite3.Row]) -> list[dict[str, Any]]:
        return [dict(row) for row in rows]

    @staticmethod
    def _int_or_none(value: Any) -> int | None:
        return None if value in (None, "") else int(value)

    @staticmethod
    def _int_or_zero(value: Any) -> int:
        return 0 if value in (None, "") else int(value)

    @staticmethod
    def _bool_int(value: Any) -> int:
        return int(bool(value))

    @staticmethod
    def _str_or_none(value: Any) -> str | None:
        text = "" if value is None else str(value).strip()
        return text or None

    def _set_last_routing_error(self, value: str) -> None:
        self.error = value


class RoutingDatabaseContractTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.db_path = Path(self.temp.name) / "device_network.db"
        schema = (APP_DIR / "infrastructure" / "database" / "aggregates" / "device_network.sql").read_text(encoding="utf-8")
        with closing(sqlite3.connect(self.db_path)) as connection:
            connection.execute("PRAGMA foreign_keys = ON")
            connection.executescript(schema)
            connection.execute("INSERT INTO t01_devices (host) VALUES ('r1')")
            connection.execute(
                "INSERT INTO t02_interface_name (host, interface_name) VALUES ('r1', 'GigabitEthernet0/0')"
            )
            connection.commit()
        self.db = _DatabaseAdapter(self.db_path)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def test_ospf_save_load_and_repeat_do_not_duplicate_interface(self) -> None:
        payload = [{"process_id": 1, "router_id": "1.1.1.1", "interface_settings": [{
            "interface_name": "GigabitEthernet0/0", "area": 0, "cost": 10,
            "priority": 2, "hello_interval": 10, "dead_interval": 40,
            "bfd": True, "auth_key": "secret",
        }]}]
        self.assertTrue(save_ospf_routing(self.db, "r1", payload), self.db.error)
        loaded = get_ospf_routing(self.db, "r1")
        payload[0]["ospf_id"] = loaded["processes"][0]["ospf_id"]
        self.assertTrue(save_ospf_routing(self.db, "r1", payload), self.db.error)
        loaded = get_ospf_routing(self.db, "r1")
        interface = loaded["processes"][0]["interface_settings"][0]
        self.assertEqual(interface["interface_name"], "GigabitEthernet0/0")
        self.assertEqual(interface["priority"], 2)
        self.assertEqual(interface["auth_key"], "secret")
        with closing(self.db._connect()) as connection:
            self.assertEqual(connection.execute("SELECT COUNT(*) FROM t04_router_iface_ospf").fetchone()[0], 1)

    def test_eigrp_save_load_and_repeat_do_not_duplicate_interface(self) -> None:
        payload = [{"as_number": 100, "router_id": "2.2.2.2", "interface_settings": [{
            "interface_name": "GigabitEthernet0/0", "bandwidth": 100000,
            "split_horizon": True, "bfd": True,
        }]}]
        self.assertTrue(save_eigrp_routing(self.db, "r1", payload))
        loaded = get_eigrp_routing(self.db, "r1")
        payload[0]["eigrp_id"] = loaded["processes"][0]["eigrp_id"]
        self.assertTrue(save_eigrp_routing(self.db, "r1", payload))
        loaded = get_eigrp_routing(self.db, "r1")
        self.assertEqual(loaded["processes"][0]["interface_settings"][0]["interface_name"], "GigabitEthernet0/0")
        with closing(self.db._connect()) as connection:
            self.assertEqual(connection.execute("SELECT COUNT(*) FROM t04_router_iface_eigrp").fetchone()[0], 1)


if __name__ == "__main__":
    unittest.main()
