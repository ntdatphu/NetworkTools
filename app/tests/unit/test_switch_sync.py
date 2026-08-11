import sqlite3
import tempfile
import unittest
from pathlib import Path

from features.switching.sync import (
    parse_etherchannels,
    parse_interface_status,
    parse_vlan_brief,
    parse_vtp_status,
    sync_switch_state,
)
from scripts.build_databases import build_database
from infrastructure.database.paths import DEVICE_NETWORK_SCHEMA_DIR


VLAN_OUTPUT = """VLAN Name                             Status    Ports
1    default                          active    Gi0/1
20   USERS                            active    Gi0/2
1002 fddi-default                     act/unsup
"""

INTERFACE_OUTPUT = """Port      Name               Status       Vlan       Duplex  Speed Type
Gi0/1     uplink             connected    trunk      a-full  a-1000 10/100/1000BaseTX
Gi0/2     office             notconnect   20         auto    auto   10/100/1000BaseTX
"""

VTP_OUTPUT = """VTP Version capable             : 1 to 3
VTP version running             : 2
VTP Domain Name                 : LAB
VTP Operating Mode              : Server
VTP Pruning Mode                : Enabled
"""


class SwitchSyncParserTests(unittest.TestCase):
    def test_parses_backend_show_command_contract(self):
        self.assertEqual([row["vlan_id"] for row in parse_vlan_brief(VLAN_OUTPUT)], [1, 20])
        interfaces = parse_interface_status(INTERFACE_OUTPUT)
        self.assertEqual(interfaces[0]["if_name"], "GigabitEthernet0/1")
        self.assertEqual(interfaces[0]["mode"], "trunk")
        self.assertEqual(interfaces[1]["access_vlan"], 20)
        self.assertEqual(parse_vtp_status(VTP_OUTPUT)["domain_name"], "LAB")
        channels = parse_etherchannels("1 Po1(SU) LACP Gi0/1(P) Gi0/2(P)")
        self.assertEqual(channels[0]["member_ports"], "GigabitEthernet0/1,GigabitEthernet0/2")


class SwitchSyncPersistenceTests(unittest.TestCase):
    def setUp(self):
        self.tempdir = tempfile.TemporaryDirectory()
        self.db_path = Path(self.tempdir.name) / "device.db"
        build_database(DEVICE_NETWORK_SCHEMA_DIR, self.db_path)
        with sqlite3.connect(self.db_path) as conn:
            conn.execute(
                "INSERT INTO t01_devices(host, device_name, role, device_type) VALUES (?, ?, ?, ?)",
                ("192.0.2.20", "sw1", "sw2", "switch_layer2"),
            )

    def tearDown(self):
        self.tempdir.cleanup()

    def test_initial_safe_sync_imports_vlan_interface_and_vtp_without_password(self):
        result = sync_switch_state(
            self.db_path,
            "192.0.2.20",
            {
                "vlan_brief": VLAN_OUTPUT,
                "interfaces_status": INTERFACE_OUTPUT,
                "interfaces_trunk": "Gi0/1 on 802.1q trunking 1",
                "etherchannel_summary": "",
                "vtp_status": VTP_OUTPUT,
            },
        )

        self.assertEqual(result["vlans"], 2)
        self.assertEqual(result["interfaces"], 2)
        self.assertEqual(result["vtp"], 1)
        with sqlite3.connect(self.db_path) as conn:
            domain = conn.execute(
                "SELECT domain_name, password_type, password_value FROM t09_vtp_domains"
            ).fetchone()
        self.assertEqual(domain, ("LAB", "none", None))
        preview = sync_switch_state(
            self.db_path,
            "192.0.2.20",
            {
                "vlan_brief": VLAN_OUTPUT,
                "interfaces_status": INTERFACE_OUTPUT,
                "interfaces_trunk": "Gi0/1 on 802.1q trunking 1",
                "etherchannel_summary": "",
                "vtp_status": VTP_OUTPUT,
            },
            mode="preview",
        )
        self.assertEqual(preview["conflicts"], [])

    def test_preview_preserves_existing_unpushed_vlan(self):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute(
                "INSERT INTO t06_vlan_db(host, vlan_id, vlan_name) VALUES (?, ?, ?)",
                ("192.0.2.20", 30, "LOCAL-DRAFT"),
            )
        result = sync_switch_state(
            self.db_path,
            "192.0.2.20",
            {"vlan_brief": VLAN_OUTPUT},
            mode="preview",
        )
        self.assertEqual(result["conflicts"], ["vlan"])


if __name__ == "__main__":
    unittest.main()
