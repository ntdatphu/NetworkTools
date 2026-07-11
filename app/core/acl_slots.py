"""AclSlotsMixin — PyQt6 slots for ACL CRUD.

Mirrors DhcpSlotsMixin in dhcp_slots.py.

MRO note: DatabaseManager must list AclSlotsMixin *before* StubSlotsMixin
so that these real implementations shadow the stubs:

    class DatabaseManager(DhcpSlotsMixin, AclSlotsMixin, StubSlotsMixin, QObject): ...
"""
from __future__ import annotations

from typing import Any

from PyQt6.QtCore import pyqtSlot

from acl import delete_acl, get_acls, save_acl


class AclSlotsMixin:
    @pyqtSlot(str, str, result="QVariant")
    def getAcls(self, host: str, acl_type: str) -> list[dict[str, Any]]:
        """Return all non-deleted ACLs for host+type, including rules and bindings."""
        return get_acls(self, host, acl_type)

    @pyqtSlot("QVariant", result=bool)
    def saveAcl(self, payload: Any) -> bool:
        """Create or update an ACL.

        *payload* is the JS object from AclForm.saveAcl():
        {
          acl_id, host, acl_name, acl_type, description,
          description_only, rules, binding: {iface_id, direction}
        }
        Returns True on success, False on validation or DB error.
        """
        if isinstance(payload, dict):
            data = payload
        else:
            # QML may pass a QJSValue; convert to plain dict via str round-trip isn't
            # needed here because PyQt6 marshals QVariant dicts automatically.
            data = dict(payload) if payload else {}
        return save_acl(self, data)

    @pyqtSlot(int, result=bool)
    def deleteAcl(self, acl_id: int) -> bool:
        """Soft-delete ACL (success = -1) and clean up its interface bindings."""
        return delete_acl(self, acl_id)
