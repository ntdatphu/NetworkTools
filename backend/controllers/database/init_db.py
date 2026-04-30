#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Initialize SQLite DB from a SQL file (compatible with project's data.sql).

Usage:
  python script/database/init_db.py --sql /path/to/data.sql --db /path/to/device_network.db

Defaults: `data.sql` in repo root and `device_network.db` created next to it.
"""
from __future__ import annotations

import argparse
import sqlite3
from pathlib import Path
from typing import List


def split_sql_statements(sql: str) -> List[str]:
    statements: List[str] = []
    current = []

    in_single = False
    in_double = False
    in_line_comment = False
    in_block_comment = False

    i = 0
    length = len(sql)
    while i < length:
        c = sql[i]
        nxt = sql[i + 1] if i + 1 < length else ""

        if in_line_comment:
            if c == "\n":
                in_line_comment = False
                current.append(c)
            i += 1
            continue

        if in_block_comment:
            if c == '*' and nxt == '/':
                in_block_comment = False
                i += 2
                continue
            i += 1
            continue

        if not in_single and not in_double:
            if c == '-' and nxt == '-':
                in_line_comment = True
                i += 2
                continue
            if c == '/' and nxt == '*':
                in_block_comment = True
                i += 2
                continue

        if c == "'" and not in_double:
            in_single = not in_single
            current.append(c)
            i += 1
            continue

        if c == '"' and not in_single:
            in_double = not in_double
            current.append(c)
            i += 1
            continue

        if c == ';' and not in_single and not in_double:
            stmt = ''.join(current).strip()
            if stmt:
                statements.append(stmt)
            current = []
            i += 1
            continue

        current.append(c)
        i += 1

    last = ''.join(current).strip()
    if last:
        statements.append(last)

    return statements


def initialize_db(sql_path: Path, db_path: Path) -> bool:
    if not sql_path.exists():
        print(f"SQL file not found: {sql_path}")
        return False

    sql_text = sql_path.read_text(encoding='utf-8')
    statements = split_sql_statements(sql_text)
    if not statements:
        print("No valid SQL statements found.")
        return False

    db_path_parent = db_path.parent
    db_path_parent.mkdir(parents=True, exist_ok=True)

    conn = sqlite3.connect(str(db_path))
    try:
        cur = conn.cursor()
        cur.execute('PRAGMA foreign_keys = ON;')
        conn.execute('BEGIN;')

        for stmt in statements:
            try:
                if '\n' in stmt and stmt.strip().upper().startswith('CREATE'):
                    cur.executescript(stmt)
                else:
                    cur.execute(stmt)
            except sqlite3.DatabaseError as e:
                print('Failed to execute statement:', e)
                print('Statement:', stmt)
                conn.rollback()
                return False

        try:
            cur.execute(
                """
                INSERT OR IGNORE INTO devices
                (host, device_name, method, portnumber, username, password, os, role, success, yangcfg)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                """,
                ("0.0.0.0", None, None, None, None, None, None, None, 3, 0),
            )
        except sqlite3.DatabaseError as e:
            print('Failed to insert default device row:', e)
            conn.rollback()
            return False

        conn.commit()
        print(f"Database initialized successfully at: {db_path}")
        return True
    finally:
        conn.close()


def main() -> None:
    parser = argparse.ArgumentParser(description='Initialize SQLite DB from SQL file')
    parser.add_argument('--sql', '-s', type=Path, default=None, help='Path to data.sql')
    parser.add_argument('--db', '-d', type=Path, default=None, help='Path to output device_network.db')

    args = parser.parse_args()

    script_root = Path(__file__).resolve().parent
    repo_root = script_root.parents[2] if len(script_root.parents) >= 2 else script_root

    sql_path = args.sql if args.sql is not None else repo_root / 'data.sql'
    db_path = args.db if args.db is not None else repo_root / 'device_network.db'

    success = initialize_db(sql_path, db_path)
    if not success:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
