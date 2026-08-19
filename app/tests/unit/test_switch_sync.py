import sqlite3
import tempfile
import unittest
from pathlib import Path

from features.switching.sync import (
    parse_etherchannels,
    parse_interface_status,
    parse_trunks,
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

    def test_parses_full_port_channel_name_as_a_trunk(self):
        status = (
            "Port-channel1 bundle connected 1 a-full a-1000 EtherChannel\n"
        )
        interfaces = parse_interface_status(status)
        trunks = parse_trunks("Port-channel1 on 802.1q trunking 1")

        self.assertEqual(interfaces[0]["if_name"], "Port-channel1")
        self.assertEqual(interfaces[0]["mode"], "access")
        self.assertIn("Port-channel1", trunks)

    def test_parses_configured_allowed_vlans_from_trunk_section(self):
        output = """Port        Mode Encapsulation Status Native vlan
Po1         on   802.1q        trunking 1

Port        Vlans allowed on trunk
Po1         10,20,30-35

Port        Vlans allowed and active in management domain
Po1         10,20,30
"""

        trunks = parse_trunks(output)

        self.assertEqual(trunks["Port-channel1"]["allowed_vlans"], "10,20,30-35")


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

    def test_trunk_output_overrides_stale_port_channel_access_status(self):
        with sqlite3.connect(self.db_path) as conn:
            iface_id = conn.execute(
                """
                INSERT INTO t06_interface_l2(host, if_name, mode, success)
                VALUES (?, 'Port-channel1', 'access', 'synchronized')
                """,
                ("192.0.2.20",),
            ).lastrowid
            conn.execute(
                "INSERT INTO t06_iface_access(iface_id, access_vlan) VALUES (?, 1)",
                (iface_id,),
            )

        result = sync_switch_state(
            self.db_path,
            "192.0.2.20",
            {
                "interfaces_status": (
                    "Port-channel1 bundle connected 1 a-full a-1000 EtherChannel"
                ),
                "interfaces_trunk": """Port-channel1 on 802.1q trunking 1

Port Vlans allowed on trunk
Port-channel1 10,20
""",
            },
            mode="force_device_state",
        )

        self.assertEqual(result["interfaces"], 1)
        with sqlite3.connect(self.db_path) as conn:
            row = conn.execute(
                """
                SELECT i.mode, a.iface_id, t.native_vlan, t.encapsulation,
                       t.allowed_vlans
                FROM t06_interface_l2 AS i
                LEFT JOIN t06_iface_access AS a ON a.iface_id = i.id
                LEFT JOIN t06_iface_trunk AS t ON t.iface_id = i.id
                WHERE i.host = ? AND i.if_name = 'Port-channel1'
                """,
                ("192.0.2.20",),
            ).fetchone()
        self.assertEqual(row, ("trunk", None, 1, "dot1q", "10,20"))


if __name__ == "__main__":
    unittest.main()
