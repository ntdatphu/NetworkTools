from __future__ import annotations

import sqlite3
from contextlib import closing
from typing import Any

from infrastructure.network.config import DB_PATH, DB_TABLES


ACL = DB_TABLES["acl"]
RULE_COLUMNS = {
    "standard": "id, sequence, action, source, wildcard, success",
    "extended": (
        "id, sequence, action, protocol, source, src_wildcard, src_port, "
        "destination, dst_wildcard, dst_port, success"
    ),
    "dynamic": (
        "id, sequence, action, protocol, source, src_wildcard, src_port, "
        "destination, dst_wildcard, dst_port, dynamic_name, timeout_seconds, success"
    ),
    "reflexive": (
        "id, sequence, action, protocol, source, src_wildcard, src_port, "
        "destination, dst_wildcard, dst_port, reflect_name, timeout_seconds, success"
    ),
    "mac": "id, sequence, action, src_mac, src_mask, dst_mac, dst_mask, ethertype, success",
}


def _pending(value: Any) -> bool:
    return value is None or value in (0, "0", -1, "-1")


def _rule_payload(acl_type: str, row: sqlite3.Row) -> dict[str, Any]:
    item = dict(row)
    item["seq"] = item.pop("sequence") or int(item["id"]) * 10
    if acl_type == "standard":
        item["src"] = item.pop("source")
        item["src_mask"] = item.pop("wildcard")
    elif acl_type in {"extended", "dynamic", "reflexive"}:
        item["src"] = item.pop("source")
        item["src_mask"] = item.pop("src_wildcard")
        item["dst"] = item.pop("destination")
        item["dst_mask"] = item.pop("dst_wildcard")
        if acl_type == "dynamic":
            item["dyn_name"] = item.pop("dynamic_name")
            item["timeout"] = item.pop("timeout_seconds")
        elif acl_type == "reflexive":
            item["timeout"] = item.pop("timeout_seconds")
    return item


def _collect_bindings(cursor: sqlite3.Cursor, acl_id: int) -> tuple[list[dict[str, Any]], dict[str, list[int]]]:
    rows = cursor.execute(
        f"""
        SELECT b.id, i.interface_name, b.direction, b.success
        FROM {ACL['bindings']} AS b
        JOIN t02_interface_name AS i ON i.iface_id = b.iface_id
        WHERE b.acl_id = ? AND (b.success <= 0 OR b.success IS NULL)
        ORDER BY i.interface_name COLLATE NOCASE, b.direction;
        """,
        (acl_id,),
    ).fetchall()
    bindings: list[dict[str, Any]] = []
    tracking = {"add": [], "del": []}
    for row in rows:
        state = "remove" if row["success"] == -1 else "setup"
        bindings.append({
            "id": row["id"],
            "interface_name": row["interface_name"],
            "direction": row["direction"],
            "state": state,
        })
        tracking["del" if state == "remove" else "add"].append(int(row["id"]))
    return bindings, tracking


def _collect_acl(cursor: sqlite3.Cursor, row: sqlite3.Row) -> tuple[dict[str, Any], dict[str, Any]]:
    acl_id = int(row["Acl_id"])
    acl_type = str(row["acl_type"]).lower()
    parent_remove = row["success"] == -1
    rules = cursor.execute(
        f"SELECT {RULE_COLUMNS[acl_type]} FROM {ACL[acl_type]} "
        "WHERE acl_id = ? AND (success <= 0 OR success IS NULL) "
        "ORDER BY COALESCE(sequence, id * 10), id;",
        (acl_id,),
    ).fetchall()
    rules_add: list[dict[str, Any]] = []
    rules_del: list[dict[str, Any]] = []
    rule_tracking = {"add": [], "del": []}
    for rule in rules:
        payload = _rule_payload(acl_type, rule)
        state = "remove" if parent_remove or rule["success"] == -1 else "setup"
        payload.pop("success", None)
        payload.pop("id", None)
        (rules_del if state == "remove" else rules_add).append(payload)
        rule_tracking["del" if state == "remove" else "add"].append(int(rule["id"]))

    bindings, binding_tracking = _collect_bindings(cursor, acl_id)
    payload = {
        "acl_id": acl_id,
        "acl_name": row["acl_name"],
        "acl_type": acl_type,
        "description": row["description"],
        "push_desc": bool(int(row["action_Cfg"] or 0) & 1),
        "action": "delete" if parent_remove else ("set" if row["success"] in (None, 0) else "change"),
        "rules_add": rules_add,
        "rules_del": rules_del,
        "bindings": bindings,
    }
    tracking = {
        "acl": {
            "add": [acl_id] if _pending(row["success"]) and not parent_remove else [],
            "del": [acl_id] if parent_remove else [],
        },
        "rules": {acl_type: rule_tracking},
        "bindings": binding_tracking,
    }
    return payload, tracking


def collect_acl_tasks(target_ip: str = "all", db_path: str = DB_PATH) -> list[dict[str, Any]]:
    with closing(sqlite3.connect(db_path)) as conn:
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        host_clause = "" if target_ip == "all" else "AND a.host = ?"
        parameters: tuple[Any, ...] = () if target_ip == "all" else (target_ip,)
        child_checks = " OR ".join(
            f"EXISTS (SELECT 1 FROM {ACL[kind]} r WHERE r.acl_id=a.Acl_id AND (r.success <= 0 OR r.success IS NULL))"
            for kind in RULE_COLUMNS
        )
        rows = cursor.execute(
            f"""
            SELECT a.Acl_id, a.acl_name, a.acl_type, a.host, a.description,
                   a.success, a.action_Cfg
            FROM {ACL['main']} AS a
            WHERE ({'a.success <= 0 OR a.success IS NULL OR ' + child_checks}
                   OR EXISTS (
                       SELECT 1 FROM {ACL['bindings']} b
                       WHERE b.acl_id=a.Acl_id AND (b.success <= 0 OR b.success IS NULL)
                   ))
              {host_clause}
            ORDER BY a.host, a.Acl_id;
            """,
            parameters,
        ).fetchall()

        tasks: list[dict[str, Any]] = []
        for row in rows:
            payload, tracking = _collect_acl(cursor, row)
            tasks.append({
                "module": "acl",
                "target": {"ip": row["host"]},
                "action": "setup",
                "config": payload,
                "tracking": tracking,
            })
        return tasks
