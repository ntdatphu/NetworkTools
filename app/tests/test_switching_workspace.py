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
    VtpGroupService,
    add_l2_trust_port,
    ensure_switch_schema,
    get_etherchannels,
    get_ip_routing,
    get_l2_security,
    get_port_counters,
    get_svis,
    get_stp_configs,
    get_switch_interfaces,
    get_vlans,
    navigation_for_role,
    save_ip_routing,
    save_etherchannel,
    save_svi,
    save_l2_vlan_security,
    save_static_mac,
    save_stp_config,
    save_switch_interface,
    save_vlan,
)
from switching.commands import render_commands  # noqa: E402
from switching.desired_state import collect_desired_state  # noqa: E402
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

    @staticmethod
    def _as_dict(value):
        return value if isinstance(value, dict) else {}

    @staticmethod
    def _as_list(value):
        return value if isinstance(value, list) else []

    @staticmethod
    def _int_or_none(value):
        try:
            return int(value)
        except (TypeError, ValueError):
            return None


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
        self.assertEqual(
            next(item for item in sw2 if item["id"] == "switching")["subfeatures"],
            ["vlan", "etherChannel", "stp", "vtp"],
        )
        self.assertEqual(
            next(item for item in sw2 if item["id"] == "security")["subfeatures"],
            ["l2Security", "portSecurity"],
        )
        self.assertIn("services", [item["id"] for item in sw3])
        self.assertEqual(
            next(item for item in sw3 if item["id"] == "interfaces")["subfeatures"],
            ["switchPorts", "routedPorts", "svi"],
        )

    def test_etherchannel_crud_reuses_existing_schema_and_validates_pairs(self) -> None:
        created = save_etherchannel(
            self.db,
            "sw2.local",
            {
                "po_number": 12,
                "protocol": "lacp",
                "mode": "active",
                "member_ports": "GigabitEthernet0/1, GigabitEthernet0/2",
                "description": "Distribution uplink",
            },
        )
        self.assertTrue(created["ok"], created)
        rows = get_etherchannels(self.db, "sw2.local")
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["member_ports"], "GigabitEthernet0/1,GigabitEthernet0/2")

        conflict = save_etherchannel(
            self.db,
            "sw2.local",
            {
                "po_number": 13,
                "protocol": "lacp",
                "mode": "passive",
                "member_ports": "GigabitEthernet0/2",
            },
        )
        self.assertFalse(conflict["ok"])
        self.assertIn("already assigned", conflict["message"])

        duplicate_number = save_etherchannel(
            self.db,
            "sw2.local",
            {
                "po_number": 12,
                "protocol": "lacp",
                "mode": "passive",
                "member_ports": "GigabitEthernet0/4",
            },
        )
        self.assertFalse(duplicate_number["ok"])
        self.assertIn("Port-channel12 already exists", duplicate_number["message"])

        rejected = save_etherchannel(
            self.db,
            "sw2.local",
            {
                "id": created["id"],
                "po_number": 12,
                "protocol": "pagp",
                "mode": "active",
                "member_ports": "GigabitEthernet0/1",
            },
        )
        self.assertFalse(rejected["ok"])
        self.assertEqual(get_etherchannels(self.db, "sw2.local")[0]["protocol"], "lacp")

        updated = save_etherchannel(
            self.db,
            "sw2.local",
            {
                "id": created["id"],
                "po_number": 12,
                "protocol": "static",
                "mode": "on",
                "member_ports": "GigabitEthernet0/3",
                "description": "",
            },
        )
        self.assertTrue(updated["ok"], updated)
        self.assertEqual(get_etherchannels(self.db, "sw2.local")[0]["mode"], "on")
        commands = render_commands(
            "interfaces", collect_desired_state(self.db, "sw2.local", "interfaces")
        )
        self.assertIn("interface Port-channel12", commands)
        self.assertIn(" no description", commands)

    def test_port_counters_coalesce_missing_monitor_samples(self) -> None:
        saved = save_switch_interface(
            self.db,
            "sw2.local",
            {
                "if_name": "GigabitEthernet0/9",
                "mode": "access",
                "access_vlan": 10,
            },
        )
        self.assertTrue(saved["ok"], saved)
        row = get_port_counters(self.db, "sw2.local")[0]
        self.assertEqual(row["in_octets"], 0)
        self.assertEqual(row["out_octets"], 0)
        self.assertEqual(row["in_errors"], 0)
        self.assertEqual(row["out_discards"], 0)
        self.assertEqual(row["last_flap"], "never")
        self.assertEqual(row["polled_at"], "")

    def test_stp_policy_crud_renders_global_mode_and_per_vlan_policy(self) -> None:
        first = save_stp_config(
            self.db,
            "sw2.local",
            {
                "vlan_id": 10,
                "stp_mode": "rapid-pvst",
                "priority": 32768,
                "root_role": "primary",
            },
        )
        self.assertTrue(first["ok"], first)
        second = save_stp_config(
            self.db,
            "sw2.local",
            {
                "vlan_id": 1,
                "stp_mode": "mst",
                "priority": 4096,
                "root_role": "none",
            },
        )
        self.assertTrue(second["ok"], second)

        rows = get_stp_configs(self.db, "sw2.local")
        self.assertEqual([row["vlan_id"] for row in rows], [1, 10])
        self.assertTrue(all(row["stp_mode"] == "mst" for row in rows))
        commands = render_commands(
            "stp", collect_desired_state(self.db, "sw2.local", "stp")
        )
        self.assertIn("spanning-tree mode mst", commands)
        self.assertIn("spanning-tree vlan 10 root primary", commands)
        self.assertIn("spanning-tree vlan 1 priority 4096", commands)

    def test_l2_security_operations_reuse_existing_schema_and_render_commands(self) -> None:
        interface = save_switch_interface(
            self.db,
            "sw2.local",
            {
                "if_name": "GigabitEthernet0/9",
                "mode": "access",
                "access_vlan": 10,
            },
        )
        self.assertTrue(interface["ok"], interface)
        policy = save_l2_vlan_security(
            self.db,
            "sw2.local",
            {"vlan_id": 10, "dhcp_snooping": True, "dai_enabled": True},
        )
        self.assertTrue(policy["ok"], policy)
        trusted = add_l2_trust_port(
            self.db, "sw2.local", "GigabitEthernet0/9"
        )
        self.assertTrue(trusted["ok"], trusted)
        binding = save_static_mac(
            self.db,
            "sw2.local",
            {
                "mac_addr": "00:11:22:33:44:55",
                "vlan_id": 10,
                "if_name": "GigabitEthernet0/9",
            },
        )
        self.assertTrue(binding["ok"], binding)

        state = get_l2_security(self.db, "sw2.local")
        vlan10 = next(row for row in state["vlans"] if row["vlan_id"] == 10)
        self.assertEqual((vlan10["dhcp_snooping"], vlan10["dai_enabled"]), (1, 1))
        self.assertEqual(state["trust_ports"][0]["if_name"], "GigabitEthernet0/9")
        self.assertEqual(state["static_macs"][0]["mac_addr"], "0011.2233.4455")
        commands = render_commands(
            "security", collect_desired_state(self.db, "sw2.local", "security")
        )
        self.assertIn("ip dhcp snooping vlan 10", commands)
        self.assertIn("ip arp inspection vlan 10", commands)
        self.assertIn(" ip dhcp snooping trust", commands)
        self.assertIn(
            "mac address-table static 0011.2233.4455 vlan 10 interface GigabitEthernet0/9",
            commands,
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
                    sync_status TEXT NOT NULL DEFAULT 'pending_apply',
                    FOREIGN KEY (host) REFERENCES t01_devices(host),
                    FOREIGN KEY (host, vlan_id) REFERENCES t06_vlan_db(host, vlan_id)
                );
                CREATE TABLE t06_interface_l2 (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    host TEXT NOT NULL,
                    if_name TEXT NOT NULL,
                    FOREIGN KEY (host) REFERENCES t01_devices(host)
                );
                CREATE TABLE t06_iface_port_security (
                    iface_id INTEGER PRIMARY KEY,
                    max_mac INTEGER NOT NULL DEFAULT 1,
                    violation TEXT NOT NULL DEFAULT 'shutdown',
                    sticky INTEGER NOT NULL DEFAULT 0,
                    aging_type TEXT NOT NULL DEFAULT 'absolute',
                    aging_time INTEGER NOT NULL DEFAULT 0,
                    FOREIGN KEY (iface_id) REFERENCES t06_interface_l2(id)
                );
                INSERT INTO t01_devices(host, role) VALUES ('legacy-sw3', 'sw3');
                INSERT INTO t06_vlan_db(host, vlan_id) VALUES ('legacy-sw3', 10);
                INSERT INTO t06_svi_interface(host, vlan_id, ip_address)
                VALUES ('legacy-sw3', 10, '192.0.2.1');
                INSERT INTO t06_interface_l2(host, if_name)
                VALUES ('legacy-sw3', 'GigabitEthernet0/1');
                INSERT INTO t06_iface_port_security(iface_id, max_mac)
                VALUES (1, 2);
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
            port_security = connection.execute(
                "SELECT enabled, sync_status, success FROM t06_iface_port_security;"
            ).fetchone()
            vlan_success = connection.execute(
                "SELECT success FROM t06_vlan_db WHERE vlan_id = 10;"
            ).fetchone()[0]

        self.assertIsNotNone(l3_table)
        self.assertEqual(tuple(svi), ("legacy-sw3", 10, "192.0.2.1"))
        self.assertTrue(unique_indexes)
        self.assertEqual(tuple(port_security), (1, "pending_apply", "pending_apply"))
        self.assertEqual(vlan_success, "pending_apply")

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

    def test_vtp_group_stages_each_switch_and_renders_per_member_policy(self) -> None:
        with closing(self.db._connect()) as connection:
            connection.execute(
                "UPDATE t01_devices SET connection_status = 'connected';"
            )
            connection.commit()

        service = VtpGroupService(self.db)
        saved = service.save(
            {
                "domain_name": "CAMPUS",
                "version": 2,
                "description": "Distribution switches",
                "members": [
                    {"host": "sw2.local", "mode": "server", "pruning": True},
                    {"host": "sw3.local", "mode": "client", "pruning": False},
                ],
            }
        )

        self.assertTrue(saved["ok"], saved)
        self.assertEqual(saved["successful"], ["sw2.local", "sw3.local"])
        with closing(self.db._connect()) as connection:
            rows = connection.execute(
                """
                SELECT s.host, s.pruning, s.sync_status, m.mode
                FROM t09_vtp_switches AS s
                JOIN t09_vtp_database_modes AS m
                  ON m.vtp_switch_id = s.vtp_switch_id
                ORDER BY s.host;
                """
            ).fetchall()
        self.assertEqual(
            [tuple(row) for row in rows],
            [
                ("sw2.local", 1, "pending_apply", "server"),
                ("sw3.local", 0, "pending_apply", "client"),
            ],
        )
        sw2_commands = render_commands(
            "vtp", collect_desired_state(self.db, "sw2.local", "vtp")
        )
        sw3_commands = render_commands(
            "vtp", collect_desired_state(self.db, "sw3.local", "vtp")
        )
        self.assertIn("vtp domain CAMPUS", sw2_commands)
        self.assertIn("vtp mode server", sw2_commands)
        self.assertIn("vtp pruning", sw2_commands)
        self.assertIn("vtp mode client", sw3_commands)
        self.assertIn("no vtp pruning", sw3_commands)

        retried = service.save(
            {
                "domain_name": "CAMPUS",
                "version": 3,
                "members": [
                    {"host": "sw2.local", "mode": "server"},
                    {"host": "sw3.local", "mode": "transparent"},
                ],
            }
        )
        self.assertTrue(retried["ok"], retried)
        with closing(self.db._connect()) as connection:
            counts = connection.execute(
                """
                SELECT
                    (SELECT COUNT(*) FROM t09_vtp_domains),
                    (SELECT COUNT(*) FROM t09_vtp_switches),
                    (SELECT COUNT(*) FROM t09_vtp_database_modes);
                """
            ).fetchone()
        self.assertEqual(tuple(counts), (1, 2, 2))

    def test_vtp_group_reports_partial_member_failures_and_limits_batch_size(self) -> None:
        with closing(self.db._connect()) as connection:
            connection.execute(
                "UPDATE t01_devices SET connection_status = 'connected';"
            )
            connection.commit()
        service = VtpGroupService(self.db)

        partial = service.save(
            {
                "domain_name": "EDGE",
                "version": 2,
                "members": [
                    {"host": "sw2.local", "mode": "server"},
                    {"host": "missing.local", "mode": "client"},
                ],
            }
        )
        self.assertFalse(partial["ok"])
        self.assertTrue(partial["partial"], partial)
        self.assertEqual(partial["successful"], ["sw2.local"])
        self.assertEqual(partial["failed"][0]["host"], "missing.local")

        too_many = service.save(
            {
                "domain_name": "TOO-MANY",
                "version": 2,
                "members": [
                    {"host": f"sw{index}.local", "mode": "client"}
                    for index in range(6)
                ],
            }
        )
        self.assertFalse(too_many["ok"])
        self.assertIn("at most 5", too_many["message"])

        unsafe = service.save(
            {
                "domain_name": "SAFE\nreload",
                "version": 2,
                "members": [
                    {"host": "sw2.local", "mode": "server"},
                    {"host": "sw3.local", "mode": "client"},
                ],
            }
        )
        self.assertFalse(unsafe["ok"])
        self.assertIn("may only contain", unsafe["message"])

    def test_switch_modules_expose_shared_view_push_actions(self) -> None:
        vlan_source = (
            APP_DIR
            / "UI"
            / "qml"
            / "features"
            / "switching"
            / "switching"
            / "VlanPage.qml"
        ).read_text(encoding="utf-8")
        ports_source = (
            APP_DIR
            / "UI"
            / "qml"
            / "features"
            / "switching"
            / "interfaces"
            / "SwitchPortsPage.qml"
        ).read_text(encoding="utf-8")
        vtp_source = (
            APP_DIR
            / "UI"
            / "qml"
            / "features"
            / "switching"
            / "switching"
            / "VtpPage.qml"
        ).read_text(encoding="utf-8")
        etherchannel_source = (
            APP_DIR
            / "UI"
            / "qml"
            / "features"
            / "switching"
            / "switching"
            / "EtherChannelPage.qml"
        ).read_text(encoding="utf-8")
        stp_source = (
            APP_DIR
            / "UI"
            / "qml"
            / "features"
            / "switching"
            / "switching"
            / "StpPage.qml"
        ).read_text(encoding="utf-8")
        security_source = (
            APP_DIR
            / "UI"
            / "qml"
            / "features"
            / "switching"
            / "security"
            / "L2SecurityPage.qml"
        ).read_text(encoding="utf-8")
        for source in (
            vlan_source,
            ports_source,
            etherchannel_source,
            stp_source,
            security_source,
        ):
            self.assertIn("ViewPushButton", source)
            self.assertIn('controllerName: "switching"', source)
        self.assertIn('moduleName: "vlan"', vlan_source)
        self.assertIn(
            'moduleName: root.policyView ? "port_security" : "interfaces"',
            ports_source,
        )
        self.assertIn('moduleName: "etherchannel"', etherchannel_source)
        self.assertIn('moduleName: "stp"', stp_source)
        self.assertIn('moduleName: "l2_security"', security_source)
        self.assertIn("MultiHostViewPushDialog", vtp_source)
        self.assertIn('controllerName: "switching"', vtp_source)
        self.assertIn(
            'batchDialog.openPreview(result.successful || [], "vtp")',
            vtp_source,
        )

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
