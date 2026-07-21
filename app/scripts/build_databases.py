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

_SCHEMA_OBJECT_ORDER = {"table": 0, "index": 1, "trigger": 2, "view": 3}


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


def _canonical_objects(source_dir: Path) -> list[tuple[str, str, str]]:
    """Return user-defined objects from a clean copy of the canonical schema."""
    with closing(sqlite3.connect(":memory:")) as connection:
        connection.executescript(combine_sql(source_dir))
        rows = connection.execute(
            """
            SELECT type, name, sql
            FROM sqlite_master
            WHERE name NOT LIKE 'sqlite_%' AND sql IS NOT NULL
            """
        ).fetchall()
    return sorted(rows, key=lambda row: (_SCHEMA_OBJECT_ORDER.get(row[0], 99), row[1]))


def _repair_missing_objects(source_dir: Path, db_path: Path) -> list[str]:
    """Create schema objects that are absent without replacing user data."""
    canonical = _canonical_objects(source_dir)
    with closing(sqlite3.connect(db_path)) as connection:
        present = {
            (row[0], row[1])
            for row in connection.execute(
                "SELECT type, name FROM sqlite_master WHERE name NOT LIKE 'sqlite_%'"
            )
        }
        missing = [row for row in canonical if (row[0], row[1]) not in present]
        if not missing:
            return []

        with connection:
            connection.execute("PRAGMA foreign_keys = ON;")
            for _object_type, _name, sql in missing:
                connection.execute(sql)
            if connection.execute("PRAGMA integrity_check;").fetchone() != ("ok",):
                raise sqlite3.DatabaseError(f"integrity_check failed for {db_path}")
            errors = connection.execute("PRAGMA foreign_key_check;").fetchall()
            if errors:
                raise sqlite3.DatabaseError(f"foreign_key_check failed for {db_path}: {errors[:5]}")
    return [name for _object_type, name, _sql in missing]


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


def ensure_runtime_databases() -> dict[str, object]:
    """Create missing databases and non-destructively complete existing schemas."""
    ensure_data_dir()
    created: list[str] = []
    repaired: dict[str, list[str]] = {}
    for source_dir, db_path in TARGETS:
        if not db_path.is_file():
            build_database(source_dir, db_path)
            created.append(db_path.name)
            continue
        missing = _repair_missing_objects(source_dir, db_path)
        if missing:
            repaired[db_path.name] = missing

    created_count = len(created)
    repaired_count = sum(len(names) for names in repaired.values())
    if created_count:
        detail = f"Created {', '.join(created)} with the complete schema."
        status_text = f"DB CREATED: {created_count}"
    elif repaired_count:
        parts = [f"{name}: {', '.join(objects)}" for name, objects in repaired.items()]
        detail = f"Restored {repaired_count} missing database object(s): " + "; ".join(parts)
        status_text = f"DB REPAIRED: {repaired_count}"
    else:
        detail = "Python runtime and both database schemas are ready."
        status_text = "SYSTEM READY"
    return {
        "ok": True,
        "statusText": status_text,
        "message": detail,
        "created": created,
        "repaired": repaired,
    }


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
