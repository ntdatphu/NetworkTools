from __future__ import annotations

import argparse
import sqlite3
import sys
from contextlib import closing
from pathlib import Path


DATABASE_DIR = Path(__file__).resolve().parent
APP_DIR = DATABASE_DIR.parent
TARGETS = (
    (DATABASE_DIR / "schema", DATABASE_DIR / "device_network.sql", APP_DIR / "device_network.db"),
    (DATABASE_DIR / "info_collected", DATABASE_DIR / "info_collected.sql", APP_DIR / "info_collected.db"),
)


def _natural_key(path: Path) -> tuple[object, ...]:
    import re

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


def build_database(
    source_dir: Path,
    sql_path: Path,
    db_path: Path,
    *,
    update_combined_sql: bool = True,
) -> None:
    script = combine_sql(source_dir)
    temp_db = db_path.with_suffix(db_path.suffix + ".tmp")
    temp_sql = sql_path.with_suffix(sql_path.suffix + ".tmp")
    _remove_sqlite_side_files(temp_db)
    if update_combined_sql:
        temp_sql.write_text(script, encoding="utf-8")

    try:
        # sqlite3.Connection context chỉ commit/rollback, không đảm bảo đóng
        # connection. closing() giải phóng file handle trước khi replace(),
        # điều này đặc biệt cần thiết trên Windows.
        with closing(sqlite3.connect(temp_db)) as conn:
            with conn:
                conn.execute("PRAGMA foreign_keys = ON;")
                conn.executescript(script)
                result = conn.execute("PRAGMA integrity_check;").fetchone()
                if result is None or result[0] != "ok":
                    raise sqlite3.DatabaseError(f"integrity_check failed for {db_path}: {result}")
                foreign_key_errors = conn.execute("PRAGMA foreign_key_check;").fetchall()
                if foreign_key_errors:
                    raise sqlite3.DatabaseError(
                        f"foreign_key_check failed for {db_path}: {foreign_key_errors[:5]}"
                    )
                conn.execute("PRAGMA wal_checkpoint(TRUNCATE);")

        try:
            if update_combined_sql:
                temp_sql.replace(sql_path)
            temp_db.replace(db_path)
        except PermissionError as exc:
            raise PermissionError(
                f"Không thể ghi đè {db_path.name} hoặc {sql_path.name}. "
                "Trên Windows điều này thường do file đang được một chương trình khác "
                "(ví dụ ứng dụng C++/QML, DB Browser for SQLite, VS Code SQLite extension...) "
                "mở sẵn. Hãy đóng chương trình đó rồi chạy lại."
            ) from exc

        _remove_sqlite_side_files(temp_db)
    except Exception:
        _remove_sqlite_side_files(temp_db)
        temp_sql.unlink(missing_ok=True)
        raise


def build_all() -> None:
    for source_dir, sql_path, db_path in TARGETS:
        build_database(source_dir, sql_path, db_path)
        print(f"Built {db_path.name} from {source_dir.name}/*.sql")


def build_missing_databases() -> list[Path]:
    """Build only missing runtime databases, preserving every existing database."""
    built: list[Path] = []
    for source_dir, sql_path, db_path in TARGETS:
        if db_path.is_file():
            continue
        # Startup initialization must not rewrite a tracked source artifact.
        # The explicit build_all() command remains the only operation that
        # regenerates the combined SQL files.
        build_database(source_dir, sql_path, db_path, update_combined_sql=False)
        built.append(db_path)
    return built


def main() -> int:
    parser = argparse.ArgumentParser(description="Build NetworkTools SQLite databases from modular SQL sources.")
    parser.parse_args()
    try:
        build_all()
    except PermissionError as exc:
        print(f"Lỗi: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
