"""ACL persistence helpers.

Mirrors the structure of backend/dhcp/ for consistency.
All public functions receive the DatabaseManager instance (``db``) as the
first argument so they can call ``db._connect()`` and ``db._dict_rows()``.
"""

from .acl_db import (
    delete_acl,
    get_acls,
    save_acl,
)

__all__ = [
    "delete_acl",
    "get_acls",
    "save_acl",
]
