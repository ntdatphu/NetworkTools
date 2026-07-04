from __future__ import annotations

import os
import sqlite3
import subprocess
import sys
from pathlib import Path
from typing import Any

from PyQt6.QtCore import QObject, QTimer, QUrl, pyqtProperty, pyqtSignal, pyqtSlot


APP_DIR = Path(__file__).resolve().parent
QML_MODULE_DIR = APP_DIR / "NetworkTools"
DB_PATH = APP_DIR / "device_network.db"
SQL_PATH = QML_MODULE_DIR / "main.sql"


def _variant_list(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return rows


class AppPaths(QObject):
    @pyqtSlot(str, result=QUrl)
    def resource(self, relative_path: str) -> QUrl:
        return QUrl.fromLocalFile(str((QML_MODULE_DIR / relative_path).resolve()))


class DatabaseManager(QObject):
    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self.db_path = DB_PATH
        self.sql_path = SQL_PATH
        self.initializeDatabase()

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA foreign_keys = ON;")
        return conn

    def _ensure_column(self, conn: sqlite3.Connection, table: str, column: str, ddl: str) -> None:
        columns = {row["name"] for row in conn.execute(f"PRAGMA table_info({table});")}
        if column not in columns:
            conn.execute(ddl)

    def _as_list(self, value: Any) -> list[Any]:
        if value is None:
            return []
        if isinstance(value, list):
            return value
        if isinstance(value, tuple):
            return list(value)
        return []

    def _as_dict(self, value: Any) -> dict[str, Any]:
        return value if isinstance(value, dict) else {}

    def _int_or_none(self, value: Any) -> int | None:
        if value is None or value == "":
            return None
        if isinstance(value, bool):
            return int(value)
        try:
            return int(str(value).strip())
        except (TypeError, ValueError):
            return None

    def _int_or_zero(self, value: Any) -> int:
        return self._int_or_none(value) or 0

    def _bool_int(self, value: Any) -> int:
        if isinstance(value, str):
            return 1 if value.strip().lower() in {"1", "true", "yes", "on"} else 0
        return 1 if bool(value) else 0

    def _str_or_none(self, value: Any) -> str | None:
        if value is None:
            return None
        text = str(value).strip()
        return text or None

    def _dict_rows(self, rows: list[sqlite3.Row]) -> list[dict[str, Any]]:
        return [dict(row) for row in rows]

    @pyqtSlot(result=bool)
    def initializeDatabase(self) -> bool:
        try:
            APP_DIR.mkdir(parents=True, exist_ok=True)
            is_new = not self.db_path.exists()
            with self._connect() as conn:
                if is_new:
                    script = self.sql_path.read_text(encoding="utf-8")
                    conn.executescript(script)

                self._ensure_column(
                    conn,
                    "devices",
                    "device_type",
                    "ALTER TABLE devices ADD COLUMN device_type TEXT DEFAULT 'unknown';",
                )
                self._ensure_column(
                    conn,
                    "devices",
                    "yangcfg",
                    "ALTER TABLE devices ADD COLUMN yangcfg INTEGER DEFAULT 0;",
                )
                conn.execute(
                    """
                    CREATE TABLE IF NOT EXISTS yangcfg (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        host TEXT NOT NULL,
                        username TEXT,
                        password TEXT,
                        success INTEGER DEFAULT 0,
                        FOREIGN KEY (host) REFERENCES devices(host)
                            ON UPDATE CASCADE ON DELETE CASCADE
                    );
                    """
                )
                conn.commit()
            return True
        except Exception as exc:
            print(f"[db] initialize failed: {exc}", file=sys.stderr)
            return False

    @pyqtSlot(str, str, str, str, str, str, result=bool)
    def addDevice(
        self,
        host: str,
        device_name: str,
        method: str,
        port_text: str,
        username: str,
        password: str,
    ) -> bool:
        host = (host or "").strip()
        if not host:
            return False

        try:
            port = int(port_text) if str(port_text).strip() else None
        except ValueError:
            port = None

        try:
            with self._connect() as conn:
                conn.execute(
                    """
                    INSERT INTO devices
                        (host, device_name, method, portnumber, username, password, success, device_type)
                    VALUES (?, ?, ?, ?, ?, ?, 0, 'unknown');
                    """,
                    (
                        host,
                        device_name or None,
                        method or None,
                        port,
                        username or None,
                        password or None,
                    ),
                )
                conn.commit()
            return True
        except sqlite3.IntegrityError:
            return False
        except sqlite3.Error as exc:
            print(f"[db] addDevice failed: {exc}", file=sys.stderr)
            return False

    @pyqtSlot(str, result=bool)
    def deleteDevice(self, host: str) -> bool:
        try:
            with self._connect() as conn:
                conn.execute("DELETE FROM devices WHERE host = ?;", ((host or "").strip(),))
                conn.commit()
            return True
        except sqlite3.Error as exc:
            print(f"[db] deleteDevice failed: {exc}", file=sys.stderr)
            return False

    @pyqtSlot(str, int, result=bool)
    def updateDeviceSuccess(self, host: str, success: int) -> bool:
        try:
            with self._connect() as conn:
                conn.execute("UPDATE devices SET success = ? WHERE host = ?;", (success, (host or "").strip()))
                conn.commit()
            return True
        except sqlite3.Error as exc:
            print(f"[db] updateDeviceSuccess failed: {exc}", file=sys.stderr)
            return False

    @pyqtSlot(str, str, str, str, str, str, result=bool)
    def updateDevice(
        self,
        host: str,
        device_name: str,
        method: str,
        port_text: str,
        username: str,
        password: str,
    ) -> bool:
        try:
            port = int(port_text) if str(port_text).strip() else None
        except ValueError:
            port = None

        try:
            with self._connect() as conn:
                conn.execute(
                    """
                    UPDATE devices
                    SET device_name = ?, method = ?, portnumber = ?, username = ?, password = ?
                    WHERE host = ?;
                    """,
                    (device_name or None, method or None, port, username or None, password or None, (host or "").strip()),
                )
                conn.commit()
            return True
        except sqlite3.Error as exc:
            print(f"[db] updateDevice failed: {exc}", file=sys.stderr)
            return False

    @pyqtSlot(str, result="QVariant")
    def getDeviceByHost(self, host: str) -> dict[str, Any]:
        try:
            with self._connect() as conn:
                row = conn.execute(
                    """
                    SELECT host, device_name, method, portnumber, username, password
                    FROM devices
                    WHERE host = ?;
                    """,
                    ((host or "").strip(),),
                ).fetchone()
            if row is None:
                return {}
            return {
                "ip": row["host"],
                "name": row["device_name"] or "",
                "protocol": row["method"] or "SSH",
                "port": "" if row["portnumber"] is None else str(row["portnumber"]),
                "user": row["username"] or "",
                "pass": row["password"] or "",
            }
        except sqlite3.Error as exc:
            print(f"[db] getDeviceByHost failed: {exc}", file=sys.stderr)
            return {}

    @pyqtSlot(result="QVariant")
    def getDevices(self) -> list[dict[str, Any]]:
        try:
            with self._connect() as conn:
                rows = conn.execute(
                    """
                    SELECT host, device_name, success, device_type
                    FROM devices
                    ORDER BY host COLLATE NOCASE;
                    """
                ).fetchall()
            out: list[dict[str, Any]] = []
            for row in rows:
                success = int(row["success"] if row["success"] is not None else 0)
                if success == 3:
                    continue
                status = {1: "connected", 0: "waiting", -1: "disconnected"}.get(success)
                if status is None:
                    continue
                name = (row["device_name"] or "").strip() or row["host"]
                out.append(
                    {
                        "name": name,
                        "ip": row["host"],
                        "status": status,
                        "type": (row["device_type"] or "unknown").strip() or "unknown",
                    }
                )
            return _variant_list(out)
        except sqlite3.Error as exc:
            print(f"[db] getDevices failed: {exc}", file=sys.stderr)
            return []

    @pyqtSlot(result=bool)
    def createFoldersFromDevices(self) -> bool:
        try:
            with self._connect() as conn:
                rows = conn.execute("SELECT host FROM devices WHERE COALESCE(success, 0) != 3;").fetchall()
            backup_dir = APP_DIR / "backup"
            backup_dir.mkdir(exist_ok=True)
            for row in rows:
                host = (row["host"] or "").strip()
                if host:
                    (backup_dir / host).mkdir(exist_ok=True)
            return True
        except Exception as exc:
            print(f"[db] createFoldersFromDevices failed: {exc}", file=sys.stderr)
            return False

    @pyqtSlot(str, str, str, int, result=bool)
    def addYangcfg(self, host: str, username: str, password: str, success: int) -> bool:
        try:
            with self._connect() as conn:
                conn.execute(
                    "INSERT INTO yangcfg (host, username, password, success) VALUES (?, ?, ?, ?);",
                    ((host or "").strip(), username or None, password or None, success),
                )
                conn.execute("UPDATE devices SET yangcfg = 1 WHERE host = ?;", ((host or "").strip(),))
                conn.commit()
            return True
        except sqlite3.Error as exc:
            print(f"[db] addYangcfg failed: {exc}", file=sys.stderr)
            return False

    @pyqtSlot(str, result="QVariant")
    def getRouterInterfaces(self, host: str) -> list[dict[str, Any]]:
        return []

    @pyqtSlot(str, str, result="QVariant")
    def getRouterInterfaceByName(self, host: str, name: str) -> dict[str, Any]:
        return {}

    @pyqtSlot("QVariant", result=bool)
    def saveRouterInterface(self, payload: Any) -> bool:
        return True

    @pyqtSlot(int, result=bool)
    def deleteRouterInterface(self, iface_id: int) -> bool:
        return True

    @pyqtSlot(str, result="QVariant")
    def getDhcpPools(self, host: str) -> list[dict[str, Any]]:
        return []

    @pyqtSlot(str, str, str, str, str, str, str, result=bool)
    def addDhcpPool(self, host: str, pool: str, network: str, subnetmask: str, default: str, dns: str, lease: str) -> bool:
        return True

    @pyqtSlot(int, str, str, str, str, str, str, result=bool)
    def updateDhcpPool(self, dhcp_id: int, pool: str, network: str, subnetmask: str, default: str, dns: str, lease: str) -> bool:
        return True

    @pyqtSlot(int, result=bool)
    def deleteDhcpPool(self, dhcp_id: int) -> bool:
        return True

    @pyqtSlot(str, result="QVariant")
    def getExcludedAddresses(self, host: str) -> list[dict[str, Any]]:
        return []

    @pyqtSlot(str, str, str, result=bool)
    def addExcludedAddress(self, host: str, start_ip: str, end_ip: str) -> bool:
        return True

    @pyqtSlot(int, result=bool)
    def deleteExcludedAddress(self, ex_id: int) -> bool:
        return True

    @pyqtSlot(str, result="QVariant")
    def getDhcpHelperAddresses(self, host: str) -> list[dict[str, Any]]:
        return []

    @pyqtSlot(int, str, result=bool)
    def addDhcpHelperAddress(self, iface_id: int, helper_ip: str) -> bool:
        return True

    @pyqtSlot(int, result=bool)
    def deleteDhcpHelperAddress(self, helper_id: int) -> bool:
        return True

    @pyqtSlot(str, result="QVariant")
    def getStaticRouting(self, host: str) -> dict[str, Any]:
        host = (host or "").strip()
        if not host:
            return {"ok": False, "message": "Host is empty", "default_route": "", "routes": []}

        try:
            with self._connect() as conn:
                default_row = conn.execute(
                    """
                    SELECT id, next_hop_ip, success
                    FROM static_default_routes
                    WHERE host = ? AND success != -1
                    ORDER BY id DESC
                    LIMIT 1;
                    """,
                    (host,),
                ).fetchone()
                route_rows = conn.execute(
                    """
                    SELECT id, network, subnet_mask, next_hop, ad, success
                    FROM static_routes
                    WHERE host = ? AND success != -1
                    ORDER BY id ASC;
                    """,
                    (host,),
                ).fetchall()

            routes = [
                {
                    "id": row["id"],
                    "network": row["network"],
                    "mask": row["subnet_mask"],
                    "nexthop": row["next_hop"],
                    "ad": row["ad"],
                    "success": row["success"],
                }
                for row in route_rows
            ]
            return {
                "ok": True,
                "message": "Loaded static/default routes",
                "default_route_id": default_row["id"] if default_row else 0,
                "default_route": default_row["next_hop_ip"] if default_row else "",
                "default_route_success": default_row["success"] if default_row else 0,
                "routes": routes,
            }
        except sqlite3.Error as exc:
            print(f"[db] getStaticRouting failed: {exc}", file=sys.stderr)
            return {"ok": False, "message": str(exc), "default_route": "", "routes": []}

    @pyqtSlot(str, str, "QVariant", result=bool)
    def saveStaticRouting(self, host: str, default_value: str, routes: Any) -> bool:
        host = (host or "").strip()
        if not host:
            return False

        try:
            with self._connect() as conn:
                conn.execute("DELETE FROM static_default_routes WHERE host = ?;", (host,))
                conn.execute("DELETE FROM static_routes WHERE host = ?;", (host,))

                default_text = (default_value or "").strip()
                if default_text:
                    conn.execute(
                        """
                        INSERT INTO static_default_routes (host, next_hop_ip, success)
                        VALUES (?, ?, 0);
                        """,
                        (host, default_text),
                    )

                for route_value in self._as_list(routes):
                    route = self._as_dict(route_value)
                    network = self._str_or_none(route.get("network"))
                    mask = self._str_or_none(route.get("mask"))
                    nexthop = self._str_or_none(route.get("nexthop"))
                    if not (network or mask or nexthop):
                        continue
                    if not (network and mask and nexthop):
                        raise ValueError("Static route must include network, mask, and next-hop")
                    ad = self._int_or_none(route.get("ad")) or 1
                    if ad < 1 or ad > 255:
                        ad = 1
                    conn.execute(
                        """
                        INSERT INTO static_routes (host, network, subnet_mask, next_hop, ad, success)
                        VALUES (?, ?, ?, ?, ?, 0);
                        """,
                        (host, network, mask, nexthop, ad),
                    )
                conn.commit()
            return True
        except (sqlite3.Error, ValueError) as exc:
            print(f"[db] saveStaticRouting failed: {exc}", file=sys.stderr)
            return False

    @pyqtSlot(str, result="QVariant")
    def getOspfRouting(self, host: str) -> dict[str, Any]:
        host = (host or "").strip()
        if not host:
            return {"ok": False, "message": "Host is empty", "processes": []}

        try:
            with self._connect() as conn:
                process_rows = conn.execute(
                    """
                    SELECT ospf_id, process_id, router_id, reference_bandwidth,
                           passive_default, default_originate, default_originate_always, success
                    FROM ospf_processes
                    WHERE host = ? AND success != -1
                    ORDER BY ospf_id ASC;
                    """,
                    (host,),
                ).fetchall()

                processes: list[dict[str, Any]] = []
                for process_row in process_rows:
                    ospf_id = process_row["ospf_id"]
                    process = dict(process_row)
                    process["networks"] = self._dict_rows(
                        conn.execute(
                            """
                            SELECT id, network, wildcard, area, success
                            FROM ospf_networks
                            WHERE ospf_id = ? AND success != -1
                            ORDER BY id ASC;
                            """,
                            (ospf_id,),
                        ).fetchall()
                    )

                    distance = conn.execute(
                        """
                        SELECT external, intra_area, inter_area, success
                        FROM ospf_distance
                        WHERE ospf_id = ? AND success != -1
                        LIMIT 1;
                        """,
                        (ospf_id,),
                    ).fetchone()
                    process["distance"] = dict(distance) if distance else {}

                    area_rows = conn.execute(
                        """
                        SELECT id, area_id, area_type, no_summary, authentication, success
                        FROM ospf_areas
                        WHERE ospf_id = ? AND success != -1
                        ORDER BY id ASC;
                        """,
                        (ospf_id,),
                    ).fetchall()
                    areas: list[dict[str, Any]] = []
                    for area_row in area_rows:
                        area = dict(area_row)
                        area["ranges"] = self._dict_rows(
                            conn.execute(
                                """
                                SELECT id, ip, mask, advertise, cost, success
                                FROM ospf_area_ranges
                                WHERE area_db_id = ? AND success != -1
                                ORDER BY id ASC;
                                """,
                                (area_row["id"],),
                            ).fetchall()
                        )
                        areas.append(area)
                    process["areas"] = areas

                    process["redistribute"] = self._dict_rows(
                        conn.execute(
                            """
                            SELECT id, protocol, process_id, subnets, metric, metric_type, route_map, success
                            FROM ospf_redistribute
                            WHERE ospf_id = ? AND success != -1
                            ORDER BY id ASC;
                            """,
                            (ospf_id,),
                        ).fetchall()
                    )
                    process["passive_interfaces"] = self._dict_rows(
                        conn.execute(
                            """
                            SELECT id, interface_name, passive, success
                            FROM ospf_passive_interfaces
                            WHERE ospf_id = ? AND success != -1
                            ORDER BY id ASC;
                            """,
                            (ospf_id,),
                        ).fetchall()
                    )
                    tuning = conn.execute(
                        """
                        SELECT maximum_paths, max_lsa, spf_delay, spf_min_delay, spf_max_delay,
                               lsa_delay, lsa_min_delay, lsa_max_delay, success
                        FROM ospf_tuning
                        WHERE ospf_id = ? AND success != -1
                        LIMIT 1;
                        """,
                        (ospf_id,),
                    ).fetchone()
                    process["tuning"] = dict(tuning) if tuning else {}
                    process["interface_settings"] = self._dict_rows(
                        conn.execute(
                            """
                            SELECT id, interface_name, area, cost, hello_interval, dead_interval,
                                   mtu_ignore, bfd, network_type, auth_type, success
                            FROM ospf_interface_settings
                            WHERE ospf_id = ? AND success != -1
                            ORDER BY id ASC;
                            """,
                            (ospf_id,),
                        ).fetchall()
                    )
                    processes.append(process)

            return {"ok": True, "message": "Loaded OSPF routing", "processes": processes}
        except sqlite3.Error as exc:
            print(f"[db] getOspfRouting failed: {exc}", file=sys.stderr)
            return {"ok": False, "message": str(exc), "processes": []}

    @pyqtSlot(str, "QVariant", result=bool)
    def saveOspfRouting(self, host: str, payload: Any) -> bool:
        host = (host or "").strip()
        if not host:
            return False

        try:
            with self._connect() as conn:
                conn.execute("DELETE FROM ospf_processes WHERE host = ?;", (host,))

                for process_value in self._as_list(payload):
                    process = self._as_dict(process_value)
                    process_id = self._int_or_none(process.get("process_id"))
                    if process_id is None:
                        raise ValueError("OSPF process_id is required")

                    cur = conn.execute(
                        """
                        INSERT INTO ospf_processes (
                            host, process_id, router_id, reference_bandwidth,
                            passive_default, default_originate, default_originate_always, success
                        )
                        VALUES (?, ?, ?, ?, ?, ?, ?, 0);
                        """,
                        (
                            host,
                            process_id,
                            self._str_or_none(process.get("router_id")),
                            self._int_or_none(process.get("reference_bandwidth")),
                            self._bool_int(process.get("passive_default")),
                            self._bool_int(process.get("default_originate")),
                            self._bool_int(process.get("default_originate_always")),
                        ),
                    )
                    ospf_id = cur.lastrowid

                    for network_value in self._as_list(process.get("networks")):
                        network = self._as_dict(network_value)
                        conn.execute(
                            """
                            INSERT INTO ospf_networks (ospf_id, network, wildcard, area, success)
                            VALUES (?, ?, ?, ?, 0);
                            """,
                            (
                                ospf_id,
                                self._str_or_none(network.get("network")),
                                self._str_or_none(network.get("wildcard")),
                                self._int_or_zero(network.get("area")),
                            ),
                        )

                    distance = self._as_dict(process.get("distance"))
                    if distance:
                        conn.execute(
                            """
                            INSERT INTO ospf_distance (ospf_id, external, intra_area, inter_area, success)
                            VALUES (?, ?, ?, ?, 0);
                            """,
                            (
                                ospf_id,
                                self._int_or_none(distance.get("external")),
                                self._int_or_none(distance.get("intra_area")),
                                self._int_or_none(distance.get("inter_area")),
                            ),
                        )

                    for area_value in self._as_list(process.get("areas")):
                        area = self._as_dict(area_value)
                        cur = conn.execute(
                            """
                            INSERT INTO ospf_areas (
                                ospf_id, area_id, area_type, no_summary, authentication, success
                            )
                            VALUES (?, ?, ?, ?, ?, 0);
                            """,
                            (
                                ospf_id,
                                self._int_or_zero(area.get("area_id")),
                                self._str_or_none(area.get("area_type")) or "normal",
                                self._bool_int(area.get("no_summary")),
                                self._str_or_none(area.get("authentication")),
                            ),
                        )
                        area_db_id = cur.lastrowid
                        for range_value in self._as_list(area.get("ranges")):
                            range_row = self._as_dict(range_value)
                            conn.execute(
                                """
                                INSERT INTO ospf_area_ranges (area_db_id, ip, mask, advertise, cost, success)
                                VALUES (?, ?, ?, ?, ?, 0);
                                """,
                                (
                                    area_db_id,
                                    self._str_or_none(range_row.get("ip")),
                                    self._str_or_none(range_row.get("mask")),
                                    self._bool_int(range_row.get("advertise", True)),
                                    self._int_or_none(range_row.get("cost")),
                                ),
                            )

                    for redist_value in self._as_list(process.get("redistribute")):
                        redist = self._as_dict(redist_value)
                        protocol = self._str_or_none(redist.get("protocol"))
                        if not protocol:
                            continue
                        conn.execute(
                            """
                            INSERT INTO ospf_redistribute (
                                ospf_id, protocol, process_id, subnets, metric, metric_type, route_map, success
                            )
                            VALUES (?, ?, ?, ?, ?, ?, ?, 0);
                            """,
                            (
                                ospf_id,
                                protocol,
                                self._int_or_none(redist.get("process_id")),
                                self._bool_int(redist.get("subnets", True)),
                                self._int_or_none(redist.get("metric")),
                                self._int_or_none(redist.get("metric_type")),
                                self._str_or_none(redist.get("route_map")),
                            ),
                        )

                    for passive_value in self._as_list(process.get("passive_interfaces")):
                        passive = self._as_dict(passive_value)
                        iface = self._str_or_none(passive.get("interface_name"))
                        if not iface:
                            continue
                        conn.execute(
                            """
                            INSERT INTO ospf_passive_interfaces (ospf_id, interface_name, passive, success)
                            VALUES (?, ?, ?, 0);
                            """,
                            (ospf_id, iface, self._bool_int(passive.get("passive", True))),
                        )

                    tuning = self._as_dict(process.get("tuning"))
                    if tuning:
                        conn.execute(
                            """
                            INSERT INTO ospf_tuning (
                                ospf_id, maximum_paths, max_lsa, spf_delay, spf_min_delay, spf_max_delay,
                                lsa_delay, lsa_min_delay, lsa_max_delay, success
                            )
                            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0);
                            """,
                            (
                                ospf_id,
                                self._int_or_none(tuning.get("maximum_paths")),
                                self._int_or_none(tuning.get("max_lsa")),
                                self._int_or_none(tuning.get("spf_delay")),
                                self._int_or_none(tuning.get("spf_min_delay")),
                                self._int_or_none(tuning.get("spf_max_delay")),
                                self._int_or_none(tuning.get("lsa_delay")),
                                self._int_or_none(tuning.get("lsa_min_delay")),
                                self._int_or_none(tuning.get("lsa_max_delay")),
                            ),
                        )

                    for iface_value in self._as_list(process.get("interface_settings")):
                        iface = self._as_dict(iface_value)
                        iface_name = self._str_or_none(iface.get("interface_name"))
                        if not iface_name:
                            continue
                        conn.execute(
                            """
                            INSERT INTO ospf_interface_settings (
                                ospf_id, interface_name, area, cost, hello_interval, dead_interval,
                                mtu_ignore, bfd, network_type, auth_type, success
                            )
                            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0);
                            """,
                            (
                                ospf_id,
                                iface_name,
                                self._int_or_zero(iface.get("area")),
                                self._int_or_none(iface.get("cost")),
                                self._int_or_none(iface.get("hello_interval")),
                                self._int_or_none(iface.get("dead_interval")),
                                self._bool_int(iface.get("mtu_ignore")),
                                self._bool_int(iface.get("bfd")),
                                self._str_or_none(iface.get("network_type")),
                                self._str_or_none(iface.get("auth_type")),
                            ),
                        )

                conn.commit()
            return True
        except (sqlite3.Error, ValueError) as exc:
            print(f"[db] saveOspfRouting failed: {exc}", file=sys.stderr)
            return False

    @pyqtSlot(str, result="QVariant")
    def getEigrpRouting(self, host: str) -> dict[str, Any]:
        host = (host or "").strip()
        if not host:
            return {"ok": False, "message": "Host is empty", "processes": []}

        try:
            with self._connect() as conn:
                key_chains = self._dict_rows(
                    conn.execute(
                        """
                        SELECT id, chain_name, key_id, key_string, accept_lifetime, send_lifetime, success
                        FROM eigrp_key_chains
                        WHERE host = ? AND success != -1
                        ORDER BY id ASC;
                        """,
                        (host,),
                    ).fetchall()
                )
                process_rows = conn.execute(
                    """
                    SELECT eigrp_id, as_number, router_id, timers_active_time, bfd_all_interfaces,
                           auto_summary, passive_default, metric_weights, distance_internal, distance_external,
                           variance, maximum_paths, stub_enabled, stub_options, stub_leak_map,
                           action, action_Cfg, success
                    FROM eigrp_processes
                    WHERE host = ? AND success != -1
                    ORDER BY eigrp_id ASC;
                    """,
                    (host,),
                ).fetchall()

                processes: list[dict[str, Any]] = []
                for process_row in process_rows:
                    eigrp_id = process_row["eigrp_id"]
                    process = dict(process_row)
                    process["networks"] = self._dict_rows(
                        conn.execute(
                            """
                            SELECT id, network, wildcard, interface_name, success
                            FROM eigrp_networks
                            WHERE eigrp_id = ? AND success != -1
                            ORDER BY id ASC;
                            """,
                            (eigrp_id,),
                        ).fetchall()
                    )
                    process["interface_settings"] = self._dict_rows(
                        conn.execute(
                            """
                            SELECT id, interface_name, bandwidth, delay, hello_interval, hold_time,
                                   auth_key_chain, summary_ip, summary_mask, split_horizon,
                                   bandwidth_percent, next_hop_self, bfd, bfd_tx, bfd_rx,
                                   bfd_multiplier, success
                            FROM eigrp_interface_settings
                            WHERE eigrp_id = ? AND success != -1
                            ORDER BY id ASC;
                            """,
                            (eigrp_id,),
                        ).fetchall()
                    )
                    process["passive_interfaces"] = self._dict_rows(
                        conn.execute(
                            """
                            SELECT id, interface_name, mode, success
                            FROM eigrp_passive_interfaces
                            WHERE eigrp_id = ? AND success != -1
                            ORDER BY id ASC;
                            """,
                            (eigrp_id,),
                        ).fetchall()
                    )
                    process["distribute_lists"] = self._dict_rows(
                        conn.execute(
                            """
                            SELECT id, list_name, direction, interface_name, success
                            FROM eigrp_distribute_lists
                            WHERE eigrp_id = ? AND success != -1
                            ORDER BY id ASC;
                            """,
                            (eigrp_id,),
                        ).fetchall()
                    )
                    process["offset_lists"] = self._dict_rows(
                        conn.execute(
                            """
                            SELECT id, list_name, direction, value, interface_name, success
                            FROM eigrp_offset_lists
                            WHERE eigrp_id = ? AND success != -1
                            ORDER BY id ASC;
                            """,
                            (eigrp_id,),
                        ).fetchall()
                    )
                    process["redistribute"] = self._dict_rows(
                        conn.execute(
                            """
                            SELECT id, protocol, route_map, metric_bw, metric_delay,
                                   metric_reliability, metric_load, metric_mtu, success
                            FROM eigrp_redistribute
                            WHERE eigrp_id = ? AND success != -1
                            ORDER BY id ASC;
                            """,
                            (eigrp_id,),
                        ).fetchall()
                    )
                    process["key_chains"] = key_chains
                    processes.append(process)

            return {"ok": True, "message": "Loaded EIGRP routing", "processes": processes}
        except sqlite3.Error as exc:
            print(f"[db] getEigrpRouting failed: {exc}", file=sys.stderr)
            return {"ok": False, "message": str(exc), "processes": []}

    @pyqtSlot(str, "QVariant", result=bool)
    def saveEigrpRouting(self, host: str, payload: Any) -> bool:
        host = (host or "").strip()
        if not host:
            return False

        try:
            with self._connect() as conn:
                conn.execute("DELETE FROM eigrp_processes WHERE host = ?;", (host,))
                conn.execute("DELETE FROM eigrp_key_chains WHERE host = ?;", (host,))

                saved_key_chain_names: set[tuple[str, int | None]] = set()
                for process_value in self._as_list(payload):
                    process = self._as_dict(process_value)
                    as_number = self._int_or_none(process.get("as_number"))
                    if as_number is None:
                        raise ValueError("EIGRP as_number is required")

                    action_cfg = str(process.get("action_Cfg") or "1111111").strip()
                    if len(action_cfg) != 7:
                        action_cfg = "1111111"

                    cur = conn.execute(
                        """
                        INSERT INTO eigrp_processes (
                            host, as_number, router_id, timers_active_time, bfd_all_interfaces,
                            auto_summary, passive_default, metric_weights, distance_internal,
                            distance_external, variance, maximum_paths, stub_enabled,
                            stub_options, stub_leak_map, action, action_Cfg, success
                        )
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0);
                        """,
                        (
                            host,
                            as_number,
                            self._str_or_none(process.get("router_id")),
                            self._int_or_none(process.get("timers_active_time")),
                            self._bool_int(process.get("bfd_all_interfaces")),
                            self._bool_int(process.get("auto_summary")),
                            self._bool_int(process.get("passive_default")),
                            self._str_or_none(process.get("metric_weights")) or "0 1 0 1 0 0",
                            self._int_or_none(process.get("distance_internal")),
                            self._int_or_none(process.get("distance_external")),
                            self._int_or_none(process.get("variance")),
                            self._int_or_none(process.get("maximum_paths")),
                            self._bool_int(process.get("stub_enabled")),
                            self._str_or_none(process.get("stub_options")),
                            self._str_or_none(process.get("stub_leak_map")),
                            self._int_or_none(process.get("action")) or 15,
                            action_cfg,
                        ),
                    )
                    eigrp_id = cur.lastrowid

                    for network_value in self._as_list(process.get("networks")):
                        network = self._as_dict(network_value)
                        network_text = self._str_or_none(network.get("network"))
                        if not network_text:
                            continue
                        conn.execute(
                            """
                            INSERT INTO eigrp_networks (eigrp_id, network, wildcard, interface_name, success)
                            VALUES (?, ?, ?, ?, 0);
                            """,
                            (
                                eigrp_id,
                                network_text,
                                self._str_or_none(network.get("wildcard")),
                                self._str_or_none(network.get("interface_name")),
                            ),
                        )

                    for iface_value in self._as_list(process.get("interface_settings")):
                        iface = self._as_dict(iface_value)
                        iface_name = self._str_or_none(iface.get("interface_name"))
                        if not iface_name:
                            continue
                        conn.execute(
                            """
                            INSERT INTO eigrp_interface_settings (
                                eigrp_id, interface_name, bandwidth, delay, hello_interval, hold_time,
                                auth_key_chain, summary_ip, summary_mask, split_horizon,
                                bandwidth_percent, next_hop_self, bfd, bfd_tx, bfd_rx,
                                bfd_multiplier, success
                            )
                            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0);
                            """,
                            (
                                eigrp_id,
                                iface_name,
                                self._int_or_none(iface.get("bandwidth")),
                                self._int_or_none(iface.get("delay")),
                                self._int_or_none(iface.get("hello_interval")),
                                self._int_or_none(iface.get("hold_time")),
                                self._str_or_none(iface.get("auth_key_chain")),
                                self._str_or_none(iface.get("summary_ip")),
                                self._str_or_none(iface.get("summary_mask")),
                                self._bool_int(iface.get("split_horizon")),
                                self._int_or_none(iface.get("bandwidth_percent")),
                                self._bool_int(iface.get("next_hop_self")),
                                self._bool_int(iface.get("bfd")),
                                self._int_or_none(iface.get("bfd_tx")),
                                self._int_or_none(iface.get("bfd_rx")),
                                self._int_or_none(iface.get("bfd_multiplier")),
                            ),
                        )

                    for passive_value in self._as_list(process.get("passive_interfaces")):
                        passive = self._as_dict(passive_value)
                        iface_name = self._str_or_none(passive.get("interface_name"))
                        if not iface_name:
                            continue
                        conn.execute(
                            """
                            INSERT INTO eigrp_passive_interfaces (eigrp_id, interface_name, mode, success)
                            VALUES (?, ?, ?, 0);
                            """,
                            (eigrp_id, iface_name, self._str_or_none(passive.get("mode")) or "passive"),
                        )

                    for distribute_value in self._as_list(process.get("distribute_lists")):
                        distribute = self._as_dict(distribute_value)
                        list_name = self._str_or_none(distribute.get("list_name"))
                        if not list_name:
                            continue
                        conn.execute(
                            """
                            INSERT INTO eigrp_distribute_lists (
                                eigrp_id, list_name, direction, interface_name, success
                            )
                            VALUES (?, ?, ?, ?, 0);
                            """,
                            (
                                eigrp_id,
                                list_name,
                                self._str_or_none(distribute.get("direction")) or "in",
                                self._str_or_none(distribute.get("interface_name")),
                            ),
                        )

                    for offset_value in self._as_list(process.get("offset_lists")):
                        offset = self._as_dict(offset_value)
                        list_name = self._str_or_none(offset.get("list_name"))
                        value = self._int_or_none(offset.get("value"))
                        if not list_name or value is None:
                            continue
                        conn.execute(
                            """
                            INSERT INTO eigrp_offset_lists (
                                eigrp_id, list_name, direction, value, interface_name, success
                            )
                            VALUES (?, ?, ?, ?, ?, 0);
                            """,
                            (
                                eigrp_id,
                                list_name,
                                self._str_or_none(offset.get("direction")) or "in",
                                value,
                                self._str_or_none(offset.get("interface_name")),
                            ),
                        )

                    for redist_value in self._as_list(process.get("redistribute")):
                        redist = self._as_dict(redist_value)
                        protocol = self._str_or_none(redist.get("protocol"))
                        if not protocol:
                            continue
                        conn.execute(
                            """
                            INSERT INTO eigrp_redistribute (
                                eigrp_id, protocol, route_map, metric_bw, metric_delay,
                                metric_reliability, metric_load, metric_mtu, success
                            )
                            VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0);
                            """,
                            (
                                eigrp_id,
                                protocol,
                                self._str_or_none(redist.get("route_map")),
                                self._int_or_none(redist.get("metric_bw")),
                                self._int_or_none(redist.get("metric_delay")),
                                self._int_or_none(redist.get("metric_reliability")),
                                self._int_or_none(redist.get("metric_load")),
                                self._int_or_none(redist.get("metric_mtu")),
                            ),
                        )

                    for key_value in self._as_list(process.get("key_chains")):
                        key_chain = self._as_dict(key_value)
                        chain_name = self._str_or_none(key_chain.get("chain_name"))
                        key_id = self._int_or_none(key_chain.get("key_id"))
                        if not chain_name:
                            continue
                        dedupe_key = (chain_name, key_id)
                        if dedupe_key in saved_key_chain_names:
                            continue
                        saved_key_chain_names.add(dedupe_key)
                        conn.execute(
                            """
                            INSERT INTO eigrp_key_chains (
                                host, chain_name, key_id, key_string,
                                accept_lifetime, send_lifetime, success
                            )
                            VALUES (?, ?, ?, ?, ?, ?, 0);
                            """,
                            (
                                host,
                                chain_name,
                                key_id,
                                self._str_or_none(key_chain.get("key_string")),
                                self._str_or_none(key_chain.get("accept_lifetime")),
                                self._str_or_none(key_chain.get("send_lifetime")),
                            ),
                        )

                conn.commit()
            return True
        except (sqlite3.Error, ValueError) as exc:
            print(f"[db] saveEigrpRouting failed: {exc}", file=sys.stderr)
            return False

    @pyqtSlot(str, str, result="QVariant")
    def getAcls(self, host: str, acl_type: str) -> list[dict[str, Any]]:
        return []

    @pyqtSlot("QVariant", result=bool)
    def saveAcl(self, payload: Any) -> bool:
        return True

    @pyqtSlot(int, result=bool)
    def deleteAcl(self, acl_id: int) -> bool:
        return True

    @pyqtSlot(str, result="QVariant")
    def getNatStaticEntries(self, host: str) -> list[dict[str, Any]]:
        return []

    @pyqtSlot(str, str, str, str, str, result=bool)
    def addNatStaticEntry(self, host: str, local_ip: str, global_ip: str, protocol: str, description: str) -> bool:
        return True

    @pyqtSlot(int, result=bool)
    def deleteNatStaticEntry(self, nat_static_id: int) -> bool:
        return True

    @pyqtSlot(str, result="QVariant")
    def getNatInterfaces(self, host: str) -> list[dict[str, Any]]:
        return []

    @pyqtSlot(str, str, str, result=bool)
    def addNatInterface(self, host: str, interface_name: str, nat_role: str) -> bool:
        return True

    @pyqtSlot(int, result=bool)
    def deleteNatInterface(self, nat_intf_id: int) -> bool:
        return True

    @pyqtSlot(str, result="QVariant")
    def getNatDynamicPools(self, host: str) -> list[dict[str, Any]]:
        return []

    @pyqtSlot(str, str, str, str, str, result=bool)
    def addNatDynamicPool(self, host: str, pool_name: str, start_ip: str, end_ip: str, netmask: str) -> bool:
        return True

    @pyqtSlot(int, result=bool)
    def deleteNatDynamicPool(self, nat_dynamic_id: int) -> bool:
        return True

    @pyqtSlot(str, result="QVariant")
    def getNatPatRules(self, host: str) -> list[dict[str, Any]]:
        return []

    @pyqtSlot(str, str, str, str, result=bool)
    def addNatPatRule(self, host: str, acl_name: str, interface_name: str, overload: str) -> bool:
        return True

    @pyqtSlot(int, result=bool)
    def deleteNatPatRule(self, nat_pat_id: int) -> bool:
        return True

    @pyqtSlot(str, result="QVariant")
    def getNatAcls(self, host: str) -> list[dict[str, Any]]:
        return []

    @pyqtSlot("QVariant", result=bool)
    def addNatAcl(self, payload: Any) -> bool:
        return True

    @pyqtSlot(int, result=bool)
    def deleteNatAcl(self, nat_acl_id: int) -> bool:
        return True

    @pyqtSlot(str, result="QVariant")
    def getNatRouteMapEntries(self, host: str) -> list[dict[str, Any]]:
        return []

    @pyqtSlot("QVariant", result=bool)
    def addNatRouteMapEntry(self, payload: Any) -> bool:
        return True

    @pyqtSlot(int, result=bool)
    def deleteNatRouteMapEntry(self, route_map_entry_id: int) -> bool:
        return True


class TerminalHelper(QObject):
    @pyqtSlot()
    def openTerminal(self) -> None:
        commands = [
            ["x-terminal-emulator"],
            ["gnome-terminal"],
            ["konsole"],
            ["xfce4-terminal"],
            ["xterm"],
        ]
        for command in commands:
            try:
                subprocess.Popen(command)
                return
            except OSError:
                continue

    @pyqtSlot(str)
    def pingHost(self, ip: str) -> None:
        try:
            subprocess.Popen(["x-terminal-emulator", "-e", "ping", ip])
        except OSError:
            subprocess.Popen(["ping", ip])

    @pyqtSlot(result="QVariant")
    def ensurePythonLoginDeps(self) -> dict[str, Any]:
        return {"ok": True, "message": "PyQt6 frontend runtime is ready."}

    @pyqtSlot(str, result="QVariant")
    def connectHostAndSync(self, host: str) -> dict[str, Any]:
        return {"ok": False, "message": f"Connect backend is not ported in app yet: {host}"}


class NetworkMonitor(QObject):
    networkChanged = pyqtSignal()
    systemInfoChanged = pyqtSignal()

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._connected = True
        self._connection_type = "ethernet"
        self._network_name = "local"
        self._ram_usage_percent = 0
        self._timer = QTimer(self)
        self._timer.timeout.connect(self._refresh)
        self._timer.start(3000)
        self._refresh()

    def _refresh(self) -> None:
        self._ram_usage_percent = self._read_ram_usage()
        self.systemInfoChanged.emit()

    def _read_ram_usage(self) -> int:
        try:
            meminfo = Path("/proc/meminfo").read_text(encoding="utf-8")
            values: dict[str, int] = {}
            for line in meminfo.splitlines():
                key, _, raw = line.partition(":")
                if key in {"MemTotal", "MemAvailable"}:
                    values[key] = int(raw.strip().split()[0])
            total = values.get("MemTotal", 0)
            available = values.get("MemAvailable", 0)
            if total > 0:
                return int(((total - available) * 100) / total)
        except Exception:
            pass
        return 0

    @pyqtProperty(bool, notify=networkChanged)
    def isConnected(self) -> bool:
        return self._connected

    @pyqtProperty(str, notify=networkChanged)
    def connectionType(self) -> str:
        return self._connection_type

    @pyqtProperty(str, notify=networkChanged)
    def networkName(self) -> str:
        return self._network_name

    @pyqtProperty(int, notify=systemInfoChanged)
    def ramUsagePercent(self) -> int:
        return self._ram_usage_percent
