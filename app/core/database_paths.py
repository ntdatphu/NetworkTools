"""Canonical, working-directory-independent paths for application databases."""

from pathlib import Path


APP_DIR = Path(__file__).resolve().parents[1]
DATABASE_DIR = APP_DIR / "database"

DEVICE_NETWORK_DB = DATABASE_DIR / "device_network.db"
INFO_COLLECTED_DB = DATABASE_DIR / "info_collected.db"
DEVICE_NETWORK_SQL = DATABASE_DIR / "device_network.sql"
INFO_COLLECTED_SQL = DATABASE_DIR / "info_collected.sql"


def require_database(path: Path) -> Path:
    """Return an existing database path; never let SQLite create an empty file."""
    if not path.is_file():
        raise FileNotFoundError(
            f"Database not found: {path}. Run database/build_databases.py first."
        )
    return path
