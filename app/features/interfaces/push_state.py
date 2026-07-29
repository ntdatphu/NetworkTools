"""Commit successful router-interface tasks back to pending-state tables."""

from __future__ import annotations

from typing import Any


_PROFILE_TABLES = {
    "l3": "t02_router_iface_l3",
    "tunnel": "t02_router_iface_tunnel",
    "wan": "t02_router_iface_wan",
}


def mark_interface_task_applied(db: Any, task: dict[str, Any]) -> None:
    """Update only the rows represented by one successfully pushed task."""
    tracking = task["tracking"]
    iface_id = int(tracking["iface_id"])
    with db._connect() as connection:
        if task.get("action") == "remove":
            connection.execute(
                "DELETE FROM t02_interface_name WHERE iface_id = ?;",
                (iface_id,),
            )
            connection.commit()
            return

        if tracking.get("base_pending"):
            connection.execute(
                "UPDATE t02_interface_name SET success = 1 WHERE iface_id = ?;",
                (iface_id,),
            )
        for kind, state in tracking.get("profile_states", {}).items():
            table = _PROFILE_TABLES.get(kind)
            if table is None:
                continue
            if int(state) == -1:
                connection.execute(
                    f"DELETE FROM {table} WHERE iface_id = ?;",
                    (iface_id,),
                )
            elif int(state) == 0:
                connection.execute(
                    f"UPDATE {table} SET success = 1 WHERE iface_id = ?;",
                    (iface_id,),
                )
        connection.commit()


__all__ = ["mark_interface_task_applied"]
