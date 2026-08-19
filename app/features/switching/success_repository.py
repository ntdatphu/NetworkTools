from __future__ import annotations

from contextlib import closing
from typing import Any

_SUCCESS_TARGETS = {
    "vlan": ("t06_vlan_db", "id"),
    "interface": ("t06_interface_l2", "id"),
    "etherchannel": ("t06_etherchannel", "id"),
    "stp": ("t06_stp_config", "id"),
    "l2_vlan": ("t06_security_l2", "id"),
    "trust_port": ("t06_dhcp_trust_ports", "id"),
    "static_mac": ("t06_iface_mac_table", "id"),
    "port_security": ("t06_iface_port_security", "iface_id"),
    "vtp": ("t09_vtp_switches", "vtp_switch_id"),
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
                table, id_column = target
                row_id = int(row["id"])
                cursor = conn.execute(
                    f"UPDATE {table} SET success = 'synchronized' "
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
