from __future__ import annotations

import sqlite3
from contextlib import closing
from datetime import datetime, timezone
from pathlib import Path

from PyQt6.QtCore import QObject, QRunnable, pyqtSignal

from .types import PacketSummary


SCHEMA = """
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS capture_sessions (
    session_id INTEGER PRIMARY KEY AUTOINCREMENT,
    interface_id TEXT NOT NULL,
    interface_name TEXT NOT NULL,
    interface_ip TEXT,
    device_host TEXT,
    capture_filter TEXT,
    capture_file TEXT NOT NULL,
    started_at TEXT NOT NULL,
    ended_at TEXT,
    packet_count INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'capturing'
        CHECK (status IN ('capturing', 'completed', 'stopped', 'limit', 'error'))
);

CREATE TABLE IF NOT EXISTS packets (
    packet_id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id INTEGER NOT NULL
        REFERENCES capture_sessions(session_id) ON DELETE CASCADE,
    packet_no INTEGER NOT NULL,
    frame_number INTEGER NOT NULL,
    captured_at TEXT,
    time_offset REAL NOT NULL,
    src_mac TEXT,
    dst_mac TEXT,
    src_ip TEXT,
    dst_ip TEXT,
    src_port INTEGER,
    dst_port INTEGER,
    transport_protocol TEXT,
    protocol TEXT NOT NULL,
    length INTEGER NOT NULL,
    info TEXT,
    UNIQUE (session_id, packet_no)
);

CREATE INDEX IF NOT EXISTS idx_packets_session
    ON packets(session_id, packet_no);
CREATE INDEX IF NOT EXISTS idx_packets_protocol
    ON packets(protocol);
CREATE INDEX IF NOT EXISTS idx_packets_src_ip
    ON packets(src_ip);
CREATE INDEX IF NOT EXISTS idx_packets_dst_ip
    ON packets(dst_ip);
"""


class PacketDatabase:
    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)

    def connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(self.path, timeout=10)
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA foreign_keys = ON")
        connection.execute("PRAGMA journal_mode = WAL")
        return connection

    def ensure(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        with closing(self.connect()) as connection:
            connection.executescript(SCHEMA)
            connection.commit()


class PacketRepository:
    def __init__(self, database: PacketDatabase) -> None:
        self.database = database

    def create_session(
        self,
        interface: dict,
        capture_filter: str,
        capture_file: str,
        device_host: str,
    ) -> int:
        with closing(self.database.connect()) as connection:
            cursor = connection.execute(
                """
                INSERT INTO capture_sessions (
                    interface_id, interface_name, interface_ip, device_host,
                    capture_filter, capture_file, started_at, status
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, 'capturing')
                """,
                (
                    interface["id"],
                    interface["name"],
                    interface.get("ipv4", ""),
                    device_host or None,
                    capture_filter or None,
                    capture_file,
                    datetime.now(timezone.utc).isoformat(),
                ),
            )
            connection.commit()
            return int(cursor.lastrowid)

    def finish_session(
        self,
        session_id: int,
        packet_count: int,
        status: str,
    ) -> None:
        with closing(self.database.connect()) as connection:
            connection.execute(
                """
                UPDATE capture_sessions
                SET ended_at = ?, packet_count = ?, status = ?
                WHERE session_id = ?
                """,
                (
                    datetime.now(timezone.utc).isoformat(),
                    packet_count,
                    status,
                    session_id,
                ),
            )
            connection.commit()

    def insert_many(
        self,
        session_id: int,
        packets: list[PacketSummary],
    ) -> list[int]:
        if not packets:
            return []
        packet_ids: list[int] = []
        with closing(self.database.connect()) as connection:
            for packet in packets:
                cursor = connection.execute(
                    """
                    INSERT OR IGNORE INTO packets (
                        session_id, packet_no, frame_number, captured_at,
                        time_offset, src_mac, dst_mac, src_ip, dst_ip,
                        src_port, dst_port, transport_protocol, protocol,
                        length, info
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        session_id,
                        packet.packet_no,
                        packet.frame_number,
                        packet.captured_at,
                        packet.time_offset,
                        packet.src_mac or None,
                        packet.dst_mac or None,
                        packet.src_ip or None,
                        packet.dst_ip or None,
                        packet.src_port,
                        packet.dst_port,
                        packet.transport_protocol or None,
                        packet.protocol,
                        packet.length,
                        packet.info,
                    ),
                )
                if cursor.rowcount:
                    packet_ids.append(int(cursor.lastrowid))
                else:
                    row = connection.execute(
                        """
                        SELECT packet_id FROM packets
                        WHERE session_id = ? AND packet_no = ?
                        """,
                        (session_id, packet.packet_no),
                    ).fetchone()
                    packet_ids.append(int(row["packet_id"]) if row else 0)
            connection.commit()
        return packet_ids

    def list_sessions(self, limit: int = 100) -> list[dict]:
        with closing(self.database.connect()) as connection:
            rows = connection.execute(
                """
                SELECT session_id, interface_name, device_host, started_at,
                       ended_at, packet_count, status
                FROM capture_sessions
                ORDER BY session_id DESC
                LIMIT ?
                """,
                (limit,),
            ).fetchall()
        return [dict(row) for row in rows]

    def load_session(
        self,
        session_id: int,
        limit: int = 5_000,
    ) -> list[PacketSummary]:
        with closing(self.database.connect()) as connection:
            rows = connection.execute(
                """
                SELECT * FROM (
                    SELECT * FROM packets
                    WHERE session_id = ?
                    ORDER BY packet_no DESC
                    LIMIT ?
                )
                ORDER BY packet_no
                """,
                (session_id, limit),
            ).fetchall()
        return [self._packet_from_row(row) for row in rows]

    def find_packet(self, packet_id: int) -> dict | None:
        with closing(self.database.connect()) as connection:
            row = connection.execute(
                """
                SELECT p.*, s.capture_file
                FROM packets p
                JOIN capture_sessions s ON s.session_id = p.session_id
                WHERE p.packet_id = ?
                """,
                (packet_id,),
            ).fetchone()
        return dict(row) if row else None

    def find_packet_number(
        self,
        session_id: int,
        packet_no: int,
    ) -> dict | None:
        with closing(self.database.connect()) as connection:
            row = connection.execute(
                """
                SELECT p.*, s.capture_file
                FROM packets p
                JOIN capture_sessions s ON s.session_id = p.session_id
                WHERE p.session_id = ? AND p.packet_no = ?
                """,
                (session_id, packet_no),
            ).fetchone()
        return dict(row) if row else None

    def prune_sessions(self, keep: int) -> list[str]:
        with closing(self.database.connect()) as connection:
            rows = connection.execute(
                """
                SELECT session_id, capture_file
                FROM capture_sessions
                ORDER BY session_id DESC
                LIMIT -1 OFFSET ?
                """,
                (max(keep, 0),),
            ).fetchall()
            if rows:
                connection.executemany(
                    "DELETE FROM capture_sessions WHERE session_id = ?",
                    ((row["session_id"],) for row in rows),
                )
                connection.commit()
        return [str(row["capture_file"] or "") for row in rows]

    @staticmethod
    def _packet_from_row(row: sqlite3.Row) -> PacketSummary:
        return PacketSummary(
            packet_id=row["packet_id"],
            session_id=row["session_id"],
            packet_no=row["packet_no"],
            frame_number=row["frame_number"],
            captured_at=row["captured_at"] or "",
            time_offset=row["time_offset"],
            source=row["src_ip"] or row["src_mac"] or "",
            destination=row["dst_ip"] or row["dst_mac"] or "",
            protocol=row["protocol"],
            length=row["length"],
            info=row["info"] or "",
            transport_protocol=row["transport_protocol"] or "",
            src_mac=row["src_mac"] or "",
            dst_mac=row["dst_mac"] or "",
            src_ip=row["src_ip"] or "",
            dst_ip=row["dst_ip"] or "",
            src_port=row["src_port"],
            dst_port=row["dst_port"],
        )


class PacketStoreSignals(QObject):
    completed = pyqtSignal(object, object, str)


class PacketStoreTask(QRunnable):
    def __init__(
        self,
        repository: PacketRepository,
        session_id: int,
        packets: list[PacketSummary],
    ) -> None:
        super().__init__()
        self.repository = repository
        self.session_id = session_id
        self.packets = packets
        self.signals = PacketStoreSignals()

    def run(self) -> None:
        try:
            packet_ids = self.repository.insert_many(
                self.session_id,
                self.packets,
            )
            self.signals.completed.emit(
                self.packets,
                packet_ids,
                "",
            )
        except Exception as exc:
            self.signals.completed.emit(
                self.packets,
                [],
                str(exc),
            )
