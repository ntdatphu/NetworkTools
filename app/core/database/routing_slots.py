"""QML slots grouped by the routing responsibility."""

from __future__ import annotations

import sqlite3
import sys
from contextlib import closing
from typing import Any

from PyQt6.QtCore import pyqtSlot
from infrastructure.database.paths import INFO_COLLECTED_DB, require_database

from features.routing import (
    get_eigrp_routing,
    get_ospf_routing,
    get_static_routing,
    save_eigrp_routing,
    save_ospf_routing,
    save_static_routing,
)
from .conversion import _variant_list


class RoutingSlotsMixin:
    """Provide the stable QML contract for this responsibility."""

    def _set_last_routing_error(self, message: str) -> None:
        """Store the latest routing error exposed through the compatibility slot."""
        self._last_routing_error = (message or "").strip()

    @pyqtSlot(result=str)
    def getLastRoutingError(self) -> str:
        """Return the latest routing operation error message."""
        return self._last_routing_error

    @pyqtSlot(str, result="QVariant")
    def getRoutingInfo(self, host: str) -> dict[str, Any]:
        """Đọc bảng routing đã thu thập từ DB cho một thiết bị."""
        host = (host or "").strip()
        if not host:
            return {"ok": False, "message": "Host is empty", "routes": []}
        try:
            # Collected routing snapshots live in info_collected.db, separate
            # from editable device configuration in device_network.db.
            with closing(sqlite3.connect(require_database(INFO_COLLECTED_DB), timeout=10.0)) as conn:
                conn.row_factory = sqlite3.Row
                conn.execute("PRAGMA busy_timeout = 10000;")
                rows = conn.execute(
                    """
                    SELECT id, host, vrf_name, protocol_code, protocol_name,
                           destination, prefix_length, administrative_distance,
                           metric, next_hop, route_age, exit_interface,
                           is_best, collected_at, raw_line
                    FROM t08_info_routing_table
                    WHERE host = ?
                    ORDER BY
                        is_best DESC,
                        vrf_name COLLATE NOCASE,
                        protocol_code COLLATE NOCASE,
                        destination COLLATE NOCASE,
                        prefix_length DESC,
                        id ASC;
                    """,
                    (host,),
                ).fetchall()
            routes: list[dict[str, Any]] = []
            for row in rows:
                routes.append(
                    {
                        "id": row["id"],
                        "host": row["host"] or "",
                        "vrf_name": row["vrf_name"] or "default",
                        "protocol_code": row["protocol_code"] or "",
                        "protocol_name": row["protocol_name"] or "",
                        "destination": row["destination"] or "",
                        "prefix_length": row["prefix_length"] if row["prefix_length"] is not None else "",
                        "administrative_distance": row["administrative_distance"] if row["administrative_distance"] is not None else "",
                        "metric": row["metric"] if row["metric"] is not None else "",
                        "next_hop": row["next_hop"] or "",
                        "route_age": row["route_age"] or "",
                        "exit_interface": row["exit_interface"] or "",
                        "is_best": row["is_best"] if row["is_best"] is not None else 0,
                        "collected_at": row["collected_at"] or "",
                        "raw_line": row["raw_line"] or "",
                    }
                )
            return {"ok": True, "message": "Loaded routing table info", "routes": _variant_list(routes)}
        except sqlite3.Error as exc:
            print(f"[db] getRoutingInfo failed: {exc}", file=sys.stderr)
            return {"ok": False, "message": str(exc), "routes": []}

    @pyqtSlot(str, result="QVariant")
    def getStaticRouting(self, host: str) -> dict[str, Any]:
        """Load static-routing data for a host through the routing feature."""
        return get_static_routing(self, host)

    @pyqtSlot(str, str, "QVariant", result=bool)
    def saveStaticRouting(self, host: str, default_value: str, routes: Any) -> bool:
        """Validate and persist static-routing changes through the routing feature."""
        self._set_last_routing_error("")
        ok = save_static_routing(self, host, default_value, routes)
        return ok

    @pyqtSlot(str, result="QVariant")
    def getOspfRouting(self, host: str) -> dict[str, Any]:
        """Load OSPF routing data for a host through the routing feature."""
        return get_ospf_routing(self, host)

    @pyqtSlot(str, "QVariant", result=bool)
    def saveOspfRouting(self, host: str, payload: Any) -> bool:
        """Validate and persist OSPF changes through the routing feature."""
        self._set_last_routing_error("")
        ok = save_ospf_routing(self, host, payload)
        return ok

    @pyqtSlot(str, result="QVariant")
    def getEigrpRouting(self, host: str) -> dict[str, Any]:
        """Load EIGRP routing data for a host through the routing feature."""
        return get_eigrp_routing(self, host)

    @pyqtSlot(str, "QVariant", result=bool)
    def saveEigrpRouting(self, host: str, payload: Any) -> bool:
        """Validate and persist EIGRP changes through the routing feature."""
        self._set_last_routing_error("")
        ok = save_eigrp_routing(self, host, payload)
        return ok
