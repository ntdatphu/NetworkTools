from typing import Any, Dict

from db_client import DbClient


ALLOWED_ACL_TYPES = {"standard", "extended", "dynamic", "reflexive", "mac"}
ALLOWED_ACTIONS = {"permit", "deny"}


def save_acl_payload(db: DbClient, payload: Dict[str, Any]) -> None:
    host = payload.get("host")
    if not host:
        return

    db.clear_acl_for_host(host)

    for acl in payload.get("acls", []):
        acl_name = (acl.get("acl_name") or "").strip()
        acl_type = (acl.get("acl_type") or "").strip().lower()
        if not acl_name or acl_type not in ALLOWED_ACL_TYPES:
            continue

        acl_id = db.insert_acl_root(acl_name, acl_type, host, acl.get("description"))

        for rule in acl.get("rules", []):
            action = (rule.get("action") or "").strip().lower()
            if action not in ALLOWED_ACTIONS:
                continue

            if acl_type == "standard":
                if not rule.get("source"):
                    continue
                db.insert_standard_rule(
                    acl_id=acl_id,
                    sequence=rule.get("sequence"),
                    action=action,
                    source=rule.get("source"),
                    wildcard=rule.get("wildcard"),
                )
            elif acl_type == "extended":
                if not rule.get("protocol") or not rule.get("source") or not rule.get("destination"):
                    continue
                db.insert_extended_rule(acl_id, rule)
            elif acl_type == "dynamic":
                if not rule.get("protocol") or not rule.get("source") or not rule.get("destination"):
                    continue
                db.insert_dynamic_rule(acl_id, rule)
            elif acl_type == "reflexive":
                if not rule.get("protocol") or not rule.get("source") or not rule.get("destination"):
                    continue
                db.insert_reflexive_rule(acl_id, rule)
            elif acl_type == "mac":
                if not rule.get("src_mac"):
                    continue
                db.insert_mac_rule(acl_id, rule)
