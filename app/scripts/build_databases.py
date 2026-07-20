"""Build runtime SQLite databases atomically from the canonical schemas."""

from __future__ import annotations

import argparse
import re
import sqlite3
import sys
from contextlib import closing
from pathlib import Path

APP_DIR = Path(__file__).resolve().parents[1]
if str(APP_DIR) not in sys.path:
    sys.path.insert(0, str(APP_DIR))

from infrastructure.database.paths import (
    DEVICE_NETWORK_DB,
    DEVICE_NETWORK_SCHEMA_DIR,
    INFO_COLLECTED_DB,
    INFO_COLLECTED_SCHEMA_DIR,
    ensure_data_dir,
)

TARGETS = (
    (DEVICE_NETWORK_SCHEMA_DIR, DEVICE_NETWORK_DB),
    (INFO_COLLECTED_SCHEMA_DIR, INFO_COLLECTED_DB),
)


def _natural_key(path: Path) -> tuple[object, ...]:
    return tuple(int(part) if part.isdigit() else part.lower() for part in re.split(r"(\d+)", path.name))


def combine_sql(source_dir: Path) -> str:
    files = sorted(source_dir.glob("*.sql"), key=_natural_key)
    if not files:
        raise FileNotFoundError(f"No SQL source files found in {source_dir}")
    return "\n\n".join(path.read_text(encoding="utf-8-sig").rstrip() for path in files) + "\n"


def _remove_sqlite_side_files(db_path: Path) -> None:
    db_path.unlink(missing_ok=True)
    db_path.with_name(db_path.name + "-shm").unlink(missing_ok=True)
    db_path.with_name(db_path.name + "-wal").unlink(missing_ok=True)


def build_database(source_dir: Path, db_path: Path) -> None:
    """Build one SQLite database directly from ordered modular schema files."""
    script = combine_sql(source_dir)
    db_path.parent.mkdir(parents=True, exist_ok=True)
    temp_db = db_path.with_suffix(db_path.suffix + ".tmp")
    _remove_sqlite_side_files(temp_db)
    try:
        with closing(sqlite3.connect(temp_db)) as connection:
            with connection:
                connection.execute("PRAGMA foreign_keys = ON;")
                connection.executescript(script)
                if connection.execute("PRAGMA integrity_check;").fetchone() != ("ok",):
                    raise sqlite3.DatabaseError(f"integrity_check failed for {db_path}")
                errors = connection.execute("PRAGMA foreign_key_check;").fetchall()
                if errors:
                    raise sqlite3.DatabaseError(f"foreign_key_check failed for {db_path}: {errors[:5]}")
        temp_db.replace(db_path)
    except Exception:
        _remove_sqlite_side_files(temp_db)
        raise


def build_all() -> None:
    ensure_data_dir()
    for source_dir, db_path in TARGETS:
        build_database(source_dir, db_path)
        print(f"Built {db_path} from {source_dir}")


def build_missing_databases() -> list[Path]:
    ensure_data_dir()
    built = []
    for source_dir, db_path in TARGETS:
        if not db_path.is_file():
            build_database(source_dir, db_path)
            built.append(db_path)
    return built


def main() -> int:
    argparse.ArgumentParser(description="Build NetworkTools SQLite databases.").parse_args()
    try:
        build_all()
    except (OSError, sqlite3.Error) as exc:
        print(f"Database build failed: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
