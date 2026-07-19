"""Deprecated import adapter for the canonical infrastructure paths."""

from infrastructure.database.paths import (  # noqa: F401
    APP_DIR,
    DATABASE_DIR,
    DATA_DIR,
    DEVICE_NETWORK_DB,
    DEVICE_NETWORK_SQL,
    INFO_COLLECTED_DB,
    INFO_COLLECTED_SQL,
    require_database,
)
