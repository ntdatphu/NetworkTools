from __future__ import annotations

import tempfile
import threading
import unittest
from pathlib import Path

from log_monitor.capture import CaptureWorker, PacketLineParser
from log_monitor.controller import LogController
from log_monitor.filtering import build_packet_predicate
from log_monitor.models import PacketTableModel
from log_monitor.storage import PacketDatabase, PacketRepository
from log_monitor.types import PacketSummary


def packet(number: int, protocol: str = "TCP") -> PacketSummary:
    return PacketSummary(
        packet_no=number,
        frame_number=number,
        captured_at="2026-07-16T00:00:00+00:00",
        time_offset=float(number) / 10,
        source="192.0.2.1",
        destination="198.51.100.2",
        protocol=protocol,
        length=64,
        info="test packet",
        transport_protocol=protocol if protocol in {"TCP", "UDP"} else "",
        src_ip="192.0.2.1",
        dst_ip="198.51.100.2",
        src_port=22,
        dst_port=50_000,
    )


class LogMonitorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary_directory.name)
        self.database = PacketDatabase(self.root / "logs.db")
        self.database.ensure()
        self.repository = PacketRepository(self.database)

    def tearDown(self) -> None:
        self.temporary_directory.cleanup()

    def test_tshark_line_parser_extracts_summary_without_raw_payload(self) -> None:
        fields = [
            "7",
            "1721088000.5",
            "128",
            "00:11:22:33:44:55",
            "66:77:88:99:aa:bb",
            "192.0.2.1",
            "198.51.100.2",
            "",
            "",
            "22",
            "50000",
            "",
            "",
            "TCP",
            "SSH packet",
        ]
        parsed = PacketLineParser().parse("\t".join(fields))

        self.assertIsNotNone(parsed)
        self.assertEqual(parsed.packet_no, 7)
        self.assertEqual(parsed.protocol, "TCP")
        self.assertEqual(parsed.source, "192.0.2.1")
        self.assertEqual(parsed.src_port, 22)
        self.assertEqual(parsed.length, 128)

    def test_display_filter_is_bounded_to_supported_fields(self) -> None:
        row = packet(1)

        self.assertTrue(build_packet_predicate("tcp")(row))
        self.assertTrue(build_packet_predicate("ip.addr == 192.0.2.1")(row))
        self.assertTrue(build_packet_predicate("tcp.port == 22")(row))
        self.assertFalse(build_packet_predicate("udp")(row))
        with self.assertRaises(ValueError):
            build_packet_predicate("frame contains secret")

    def test_repository_round_trip_and_retention_prunes_old_sessions(self) -> None:
        capture_files: list[Path] = []
        for index in range(3):
            capture_file = self.root / f"capture-{index}.pcapng"
            capture_file.write_bytes(b"pcap")
            capture_files.append(capture_file)
            session_id = self.repository.create_session(
                {"id": "1", "name": "Ethernet", "ipv4": "192.0.2.5"},
                "tcp",
                str(capture_file),
                "192.0.2.1",
            )
            ids = self.repository.insert_many(session_id, [packet(index + 1)])
            self.repository.finish_session(session_id, 1, "completed")
            self.assertGreater(ids[0], 0)

        newest = self.repository.list_sessions(limit=1)[0]
        loaded = self.repository.load_session(newest["session_id"])
        removed = self.repository.prune_sessions(2)

        self.assertEqual(len(loaded), 1)
        self.assertEqual(loaded[0].source, "192.0.2.1")
        self.assertEqual(removed, [str(capture_files[0])])
        self.assertEqual(len(self.repository.list_sessions()), 2)

    def test_packet_model_caps_live_rows_and_filters_without_db_queries(self) -> None:
        model = PacketTableModel()
        model.MAX_LIVE_PACKETS = 5
        model.append_many([packet(index) for index in range(1, 9)])

        self.assertEqual(model.count, 5)
        model.apply_filter("tcp")
        self.assertEqual(model.count, 5)
        model.apply_filter("udp")
        self.assertEqual(model.count, 0)

    def test_controller_initializes_saved_sessions_without_capture_dependency(self) -> None:
        controller = LogController(
            database_path=self.root / "controller.db",
            capture_dir=self.root / "captures",
            device_db_path=self.root / "devices.db",
            auto_probe=False,
        )
        try:
            controller.initialize()

            self.assertEqual(controller.captureState, "idle")
            self.assertFalse(controller.initializing)
            self.assertFalse(controller.captureAvailable)
            self.assertTrue((self.root / "captures").is_dir())
            self.assertIn("disabled", controller.statusMessage)
        finally:
            controller.shutdown()

    def test_capture_limits_bound_runtime_disk_and_signal_pressure(self) -> None:
        self.assertEqual(CaptureWorker.BATCH_SIZE, 64)
        self.assertLessEqual(CaptureWorker.BATCH_INTERVAL_SECONDS, 0.1)
        self.assertEqual(CaptureWorker.MAX_DURATION_SECONDS, 3_600)
        self.assertEqual(CaptureWorker.MAX_CAPTURE_SIZE_KIB, 262_144)
        self.assertEqual(CaptureWorker.MAX_CAPTURE_PACKETS, 250_000)

    def test_controller_persists_packet_batches_off_the_ui_thread(self) -> None:
        controller = LogController(
            database_path=self.root / "async-controller.db",
            capture_dir=self.root / "captures",
            device_db_path=self.root / "devices.db",
            auto_probe=False,
        )
        controller.initialize()
        session_id = controller._repository.create_session(
            {"id": "1", "name": "Ethernet", "ipv4": ""},
            "",
            str(self.root / "capture.pcapng"),
            "",
        )
        controller._session_id = session_id
        controller._session_finalized = False
        caller_thread = threading.get_ident()
        worker_threads: list[int] = []
        insert_many = controller._repository.insert_many

        def recording_insert(current_session_id, packets):
            worker_threads.append(threading.get_ident())
            return insert_many(current_session_id, packets)

        controller._repository.insert_many = recording_insert
        try:
            controller._on_packet_batch([packet(1), packet(2)])
            controller._flush_pending()
            self.assertEqual(controller._storage_pool.maxThreadCount(), 1)
            self.assertTrue(controller._storage_pool.waitForDone(3_000))

            stored = controller._repository.load_session(session_id)
            self.assertEqual(len(stored), 2)
            self.assertTrue(worker_threads)
            self.assertNotEqual(worker_threads[0], caller_thread)
        finally:
            controller.shutdown()


if __name__ == "__main__":
    unittest.main()
