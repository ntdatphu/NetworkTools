from __future__ import annotations

from contextlib import closing
from typing import Any

_SUCCESS_TARGETS = {
    "vlan": ("t06_vlan_db", "id", "success"),
    "svi": ("t06_svi_interface", "id", "sync_status"),
    "switch_l3": ("t06_switch_l3_config", "host", "sync_status"),
    "interface": ("t06_interface_l2", "id", "success"),
    "etherchannel": ("t06_etherchannel", "id", "success"),
    "stp": ("t06_stp_config", "id", "success"),
    "l2_vlan": ("t06_security_l2", "id", "success"),
    "trust_port": ("t06_dhcp_trust_ports", "id", "success"),
    "static_mac": ("t06_iface_mac_table", "id", "success"),
    "port_security": ("t06_iface_port_security", "iface_id", "success"),
    "vtp": ("t09_vtp_switches", "vtp_switch_id", "success"),
}


def mark_task_success(db: Any, tracking: dict[str, Any]) -> None:
    """Commit only the business rows represented by one successful task."""
    rows = tracking.get("success_rows") or []
    if not rows:
        raise ValueError("A successful switching task must identify its business row")
    with closing(db._connect()) as conn:
        with conn:
            for row in rows:
                kind = str(row.get("kind") or "")
                target = _SUCCESS_TARGETS.get(kind)
                if target is None:
                    raise ValueError(f"Unsupported switching success target: {kind}")
                table, id_column, status_column = target
                row_id = str(row["id"]) if id_column == "host" else int(row["id"])
                if row.get("action") == "delete":
                    cursor = conn.execute(
                        f"DELETE FROM {table} WHERE {id_column} = ?;",
                        (row_id,),
                    )
                else:
                    cursor = conn.execute(
                        f"UPDATE {table} SET {status_column} = 'synchronized' "
                        f"WHERE {id_column} = ?;",
                        (row_id,),
                    )
                if cursor.rowcount != 1:
                    raise ValueError(
                        f"Switching success row no longer exists: {kind}:{row_id}"
                    )
                if kind in {"port_security", "vtp"}:
                    conn.execute(
                        f"UPDATE {table} SET sync_status = 'synchronized' "
                        f"WHERE {id_column} = ?;",
                        (row_id,),
                    )


__all__ = ["mark_task_success"]
