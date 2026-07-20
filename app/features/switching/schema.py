from __future__ import annotations

import sqlite3
from contextlib import closing
from typing import Any


def ensure_switch_schema(db: Any) -> None:
    """Add switch schema extensions without replacing existing data."""
    with closing(db._connect()) as conn:
        with conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS t06_switch_l3_config (
                    host TEXT PRIMARY KEY,
                    ip_routing INTEGER NOT NULL DEFAULT 0 CHECK(ip_routing IN (0,1)),
                    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
                    FOREIGN KEY (host) REFERENCES t01_devices(host) ON DELETE CASCADE
                );
                """
            )
            duplicate = conn.execute(
                """
                SELECT host, vlan_id
                FROM t06_svi_interface
                GROUP BY host, vlan_id
                HAVING COUNT(*) > 1
                LIMIT 1;
                """
            ).fetchone()
            if duplicate is not None:
                raise sqlite3.IntegrityError(
                    "Cannot enforce unique SVI host/VLAN values while duplicate rows exist"
                )
            conn.execute(
                "CREATE UNIQUE INDEX IF NOT EXISTS ux_t06_svi_host_vlan "
                "ON t06_svi_interface(host, vlan_id);"
            )
