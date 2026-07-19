"""Canonical, working-directory-independent database paths."""

from __future__ import annotations

import os
from pathlib import Path


APP_DIR = Path(__file__).resolve().parents[2]
DATA_DIR = Path(os.environ.get("NETWORKTOOLS_DATA_DIR", APP_DIR / "data")).expanduser().resolve()
SCHEMA_DIR = Path(__file__).resolve().parent / "schemas"
DEVICE_NETWORK_SCHEMA_DIR = SCHEMA_DIR / "device_network"
INFO_COLLECTED_SCHEMA_DIR = SCHEMA_DIR / "info_collected"
AGGREGATE_DIR = Path(__file__).resolve().parent / "aggregates"
DEVICE_NETWORK_SQL = AGGREGATE_DIR / "device_network.sql"
INFO_COLLECTED_SQL = AGGREGATE_DIR / "info_collected.sql"
DEVICE_NETWORK_DB = DATA_DIR / "device_network.db"
INFO_COLLECTED_DB = DATA_DIR / "info_collected.db"


def ensure_data_dir() -> Path:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    return DATA_DIR


def require_database(path: str | Path) -> Path:
    resolved = Path(path)
    if not resolved.is_file():
        raise FileNotFoundError(
            f"Database not found: {resolved}. Run `python scripts/build_databases.py`."
        )
    return resolved
