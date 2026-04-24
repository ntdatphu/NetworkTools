import sqlite3
from contextlib import contextmanager
from typing import Any, Dict, Iterable, List, Optional, Tuple

from models import Device


class DbClient:
    def __init__(self, db_path: str) -> None:
        self.db_path = db_path
        self.conn = sqlite3.connect(db_path)
        self.conn.row_factory = sqlite3.Row

    def close(self) -> None:
        self.conn.close()

    @contextmanager
    def transaction(self):
        try:
            self.conn.execute("BEGIN")
            yield
            self.conn.commit()
        except Exception:
            self.conn.rollback()
            raise

    def fetch_devices(self) -> List[Device]:
        query = """
        SELECT host, device_name, method, portnumber, username, password, os, role, success
        FROM devices
        WHERE success != 3
          AND host IS NOT NULL
          AND TRIM(host) != ''
        """
        rows = self.conn.execute(query).fetchall()
        return [Device.from_dict(dict(row)) for row in rows]

    def fetch_devices_for_hosts(self, hosts: List[str], success_equals: Optional[int] = None) -> List[Device]:
        cleaned_hosts = [h.strip() for h in hosts if h and h.strip()]
        if not cleaned_hosts:
            return []

        placeholders = ",".join(["?"] * len(cleaned_hosts))
        params: List[Any] = list(cleaned_hosts)

        query = f"""
        SELECT host, device_name, method, portnumber, username, password, os, role, success
        FROM devices
        WHERE host IN ({placeholders})
          AND success != 3
          AND host IS NOT NULL
          AND TRIM(host) != ''
        """

        if success_equals is not None:
            query += " AND success = ?"
            params.append(success_equals)

        rows = self.conn.execute(query, params).fetchall()
        return [Device.from_dict(dict(row)) for row in rows]

    def update_login_status(self, host: str, success: int, detected_os: Optional[str], detected_role: Optional[str]) -> None:
        self.conn.execute(
            """
            UPDATE devices
            SET success = ?,
                os = COALESCE(?, os),
                role = COALESCE(?, role)
            WHERE host = ?
            """,
            (success, detected_os, detected_role, host),
        )

    def clear_routing_for_host(self, host: str) -> None:
        self.conn.execute("DELETE FROM static_default_routes WHERE host = ?", (host,))
        self.conn.execute("DELETE FROM static_routes WHERE host = ?", (host,))

        ospf_ids = [
            row[0]
            for row in self.conn.execute("SELECT ospf_id FROM ospf_processes WHERE host = ?", (host,)).fetchall()
        ]
        for ospf_id in ospf_ids:
            self.conn.execute("DELETE FROM ospf_networks WHERE ospf_id = ?", (ospf_id,))
        self.conn.execute("DELETE FROM ospf_processes WHERE host = ?", (host,))

        eigrp_ids = [
            row[0]
            for row in self.conn.execute("SELECT eigrp_id FROM eigrp_processes WHERE host = ?", (host,)).fetchall()
        ]
        for eigrp_id in eigrp_ids:
            self.conn.execute("DELETE FROM eigrp_networks WHERE eigrp_id = ?", (eigrp_id,))
        self.conn.execute("DELETE FROM eigrp_processes WHERE host = ?", (host,))

    def insert_static_route(self, host: str, network: str, subnet_mask: str, next_hop: str, ad: Optional[int]) -> None:
        self.conn.execute(
            "INSERT INTO static_routes(host, network, subnet_mask, next_hop, ad) VALUES (?, ?, ?, ?, ?)",
            (host, network, subnet_mask, next_hop, ad if ad is not None else 1),
        )

    def insert_default_route(self, host: str, next_hop_ip: str) -> None:
        self.conn.execute(
            "INSERT INTO static_default_routes(host, next_hop_ip) VALUES (?, ?)",
            (host, next_hop_ip),
        )

    def insert_ospf_process(
        self,
        host: str,
        process_id: int,
        router_id: Optional[str],
        ad: Optional[int],
        default_info: int,
        auto_summary: int,
    ) -> int:
        cur = self.conn.execute(
            """
            INSERT INTO ospf_processes(host, process_id, router_id, ad, default_info, auto_summary)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (host, process_id, router_id, ad, default_info, auto_summary),
        )
        return int(cur.lastrowid)

    def insert_ospf_network(self, ospf_id: int, network: str, wildcard: str, area: str) -> None:
        self.conn.execute(
            "INSERT INTO ospf_networks(ospf_id, network, wildcard, area) VALUES (?, ?, ?, ?)",
            (ospf_id, network, wildcard, area),
        )

    def insert_eigrp_process(
        self,
        host: str,
        as_number: int,
        router_id: Optional[str],
        auto_summary: int,
        passive_default: int,
    ) -> int:
        cur = self.conn.execute(
            """
            INSERT INTO eigrp_processes(host, as_number, router_id, auto_summary, passive_default)
            VALUES (?, ?, ?, ?, ?)
            """,
            (host, as_number, router_id, auto_summary, passive_default),
        )
        return int(cur.lastrowid)

    def insert_eigrp_network(self, eigrp_id: int, network: str, wildcard: Optional[str], interface_name: Optional[str]) -> None:
        self.conn.execute(
            "INSERT INTO eigrp_networks(eigrp_id, network, wildcard, interface_name) VALUES (?, ?, ?, ?)",
            (eigrp_id, network, wildcard, interface_name),
        )

    def clear_acl_for_host(self, host: str) -> None:
        acl_ids = [r[0] for r in self.conn.execute("SELECT Acl_id FROM ACL_DB WHERE host = ?", (host,)).fetchall()]
        for acl_id in acl_ids:
            self.conn.execute("DELETE FROM standard_acl_rules WHERE acl_id = ?", (acl_id,))
            self.conn.execute("DELETE FROM extended_acl_rules WHERE acl_id = ?", (acl_id,))
            self.conn.execute("DELETE FROM dynamic_acl_rules WHERE acl_id = ?", (acl_id,))
            self.conn.execute("DELETE FROM reflexive_acl_rules WHERE acl_id = ?", (acl_id,))
            self.conn.execute("DELETE FROM mac_acl_rules WHERE acl_id = ?", (acl_id,))
            self.conn.execute("DELETE FROM ACL_DB WHERE Acl_id = ?", (acl_id,))

    def insert_acl_root(self, acl_name: str, acl_type: str, host: str, description: Optional[str]) -> int:
        cur = self.conn.execute(
            "INSERT INTO ACL_DB(acl_name, acl_type, host, description) VALUES (?, ?, ?, ?)",
            (acl_name, acl_type, host, description),
        )
        return int(cur.lastrowid)

    def insert_standard_rule(self, acl_id: int, sequence: Optional[int], action: str, source: str, wildcard: Optional[str]) -> None:
        self.conn.execute(
            "INSERT INTO standard_acl_rules(acl_id, sequence, action, source, wildcard) VALUES (?, ?, ?, ?, ?)",
            (acl_id, sequence, action, source, wildcard),
        )

    def insert_extended_rule(self, acl_id: int, rule: Dict[str, Any]) -> None:
        self.conn.execute(
            """
            INSERT INTO extended_acl_rules(
                acl_id, sequence, action, protocol, source, src_wildcard, src_port,
                destination, dst_wildcard, dst_port
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                acl_id,
                rule.get("sequence"),
                rule.get("action"),
                rule.get("protocol"),
                rule.get("source"),
                rule.get("src_wildcard"),
                rule.get("src_port"),
                rule.get("destination"),
                rule.get("dst_wildcard"),
                rule.get("dst_port"),
            ),
        )

    def insert_dynamic_rule(self, acl_id: int, rule: Dict[str, Any]) -> None:
        self.conn.execute(
            """
            INSERT INTO dynamic_acl_rules(
                acl_id, sequence, action, protocol, source, src_wildcard, src_port,
                destination, dst_wildcard, dst_port, dynamic_name, timeout_seconds
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                acl_id,
                rule.get("sequence"),
                rule.get("action"),
                rule.get("protocol"),
                rule.get("source"),
                rule.get("src_wildcard"),
                rule.get("src_port"),
                rule.get("destination"),
                rule.get("dst_wildcard"),
                rule.get("dst_port"),
                rule.get("dynamic_name"),
                rule.get("timeout_seconds", 300),
            ),
        )

    def insert_reflexive_rule(self, acl_id: int, rule: Dict[str, Any]) -> None:
        self.conn.execute(
            """
            INSERT INTO reflexive_acl_rules(
                acl_id, sequence, action, protocol, source, src_wildcard, src_port,
                destination, dst_wildcard, dst_port, reflect_name, timeout_seconds
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                acl_id,
                rule.get("sequence"),
                rule.get("action"),
                rule.get("protocol"),
                rule.get("source"),
                rule.get("src_wildcard"),
                rule.get("src_port"),
                rule.get("destination"),
                rule.get("dst_wildcard"),
                rule.get("dst_port"),
                rule.get("reflect_name"),
                rule.get("timeout_seconds", 300),
            ),
        )

    def insert_mac_rule(self, acl_id: int, rule: Dict[str, Any]) -> None:
        self.conn.execute(
            """
            INSERT INTO mac_acl_rules(
                acl_id, sequence, action, src_mac, src_mask, dst_mac, dst_mask, ethertype
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                acl_id,
                rule.get("sequence"),
                rule.get("action"),
                rule.get("src_mac"),
                rule.get("src_mask"),
                rule.get("dst_mac"),
                rule.get("dst_mask"),
                rule.get("ethertype"),
            ),
        )
