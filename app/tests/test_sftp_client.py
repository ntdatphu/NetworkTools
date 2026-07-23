from __future__ import annotations

import stat
import tempfile
import unittest
import json
from pathlib import Path
from types import SimpleNamespace

import paramiko
from PyQt6.QtCore import QSettings

from features.sftp.controller import SftpController, valid_entry_name
from features.sftp.credential_store import DpapiCredentialStore
from features.sftp.file_model import FileItem, FileListModel, file_type_text, format_size
from features.sftp.local_service import LocalFileService
from features.sftp.sftp_service import (
    CaptureHostKeyPolicy,
    ConnectionOptions,
    ConfirmedHostKeyPolicy,
    SftpService,
    UnknownHostKeyError,
    host_key_fingerprint,
)


class _FakeHostKeys:
    def __init__(self) -> None:
        self.added = []

    def add(self, hostname, key_type, key) -> None:
        self.added.append((hostname, key_type, key))


class _FakeClient:
    def __init__(self) -> None:
        self.keys = _FakeHostKeys()
        self.saved_to = ""

    def get_host_keys(self):
        return self.keys

    def save_host_keys(self, path: str) -> None:
        self.saved_to = path


class _MemoryCredentialStore:
    available = True

    def __init__(self) -> None:
        self.values = {}

    def has(self, profile_id: str) -> bool:
        return profile_id in self.values

    def read(self, profile_id: str) -> str:
        return self.values.get(profile_id, "")

    def write(self, profile_id: str, password: str) -> None:
        self.values[profile_id] = password

    def delete(self, profile_id: str) -> None:
        self.values.pop(profile_id, None)


class SftpClientTests(unittest.TestCase):
    def test_entry_names_reject_traversal_and_separators(self) -> None:
        self.assertTrue(valid_entry_name("reports"))
        for value in ("", "  ", ".", "..", "../x", "a/b", r"a\b"):
            with self.subTest(value=value):
                self.assertFalse(valid_entry_name(value))

    def test_local_delete_refuses_recursive_directory_removal(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            folder = root / "important"
            folder.mkdir()
            child = folder / "keep.txt"
            child.write_text("keep", encoding="utf-8")

            with self.assertRaises(OSError):
                LocalFileService.delete(str(folder))
            self.assertTrue(child.exists())

            child.unlink()
            LocalFileService.delete(str(folder))
            self.assertFalse(folder.exists())

    def test_unknown_host_key_requires_explicit_confirmation(self) -> None:
        key = paramiko.RSAKey.generate(1024)
        expected = host_key_fingerprint(key)
        self.assertTrue(expected.startswith("SHA256:"))
        with self.assertRaises(UnknownHostKeyError) as raised:
            CaptureHostKeyPolicy().missing_host_key(None, "switch.local", key)
        self.assertEqual(raised.exception.info["fingerprint"], expected)

    def test_confirmed_host_key_rejects_changed_fingerprint(self) -> None:
        key = paramiko.RSAKey.generate(1024)
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "known_hosts"
            policy = ConfirmedHostKeyPolicy("SHA256:not-the-key", path)
            with self.assertRaises(paramiko.SSHException):
                policy.missing_host_key(_FakeClient(), "switch.local", key)
            self.assertFalse(path.exists())

    def test_confirmed_host_key_is_saved_only_after_exact_match(self) -> None:
        key = paramiko.RSAKey.generate(1024)
        client = _FakeClient()
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / ".ssh" / "known_hosts"
            policy = ConfirmedHostKeyPolicy(host_key_fingerprint(key), path)
            policy.missing_host_key(client, "switch.local", key)
            self.assertEqual(client.keys.added[0][:2], ("switch.local", key.get_name()))
            self.assertEqual(client.saved_to, str(path))

    def test_remote_directory_listing_is_directory_first_and_name_sorted(self) -> None:
        directory_mode = stat.S_IFDIR | 0o755
        file_mode = stat.S_IFREG | 0o644
        service = SftpService()
        service._sftp = SimpleNamespace(
            listdir_attr=lambda _path: [
                SimpleNamespace(
                    filename="z.txt",
                    st_mode=file_mode,
                    st_size=1024,
                    st_mtime=0,
                ),
                SimpleNamespace(
                    filename="Beta",
                    st_mode=directory_mode,
                    st_size=0,
                    st_mtime=0,
                ),
                SimpleNamespace(
                    filename="alpha",
                    st_mode=directory_mode,
                    st_size=0,
                    st_mtime=0,
                ),
            ]
        )
        self.assertEqual(
            [item.name for item in service.list_directory("/")],
            ["alpha", "Beta", "z.txt"],
        )

    def test_size_format_is_stable_for_qml(self) -> None:
        self.assertEqual(format_size(0), "0 B")
        self.assertEqual(format_size(1024), "1.0 KB")
        self.assertEqual(format_size(None), "-")
        self.assertEqual(format_size(-1), "-")

    def test_file_metadata_distinguishes_type_and_unavailable_size(self) -> None:
        self.assertEqual(file_type_text("running.cfg", False), "Config file")
        self.assertEqual(file_type_text("archive.tar.gz", False), "GZ file")
        self.assertEqual(file_type_text(".bashrc", False), "File")
        self.assertEqual(file_type_text("extensionless.", False), "File")
        self.assertEqual(file_type_text("configs", True), "Folder")

        model = FileListModel()
        model.set_items(
            [
                FileItem("configs", "/configs", True, size=4096),
                FileItem("empty.txt", "/empty.txt", False, size=0),
                FileItem("unknown.log", "/unknown.log", False, size=None),
            ]
        )
        self.assertEqual(model.get(0)["sizeText"], "-")
        self.assertEqual(model.get(0)["typeText"], "Folder")
        self.assertEqual(model.get(1)["sizeText"], "0 B")
        self.assertEqual(model.get(2)["sizeText"], "-")

    def test_local_directory_size_is_not_reported_as_file_bytes(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "folder").mkdir()
            (root / "empty.txt").touch()
            items = {item.name: item for item in LocalFileService().list_directory(temp)}
            self.assertIsNone(items["folder"].size)
            self.assertEqual(items["folder"].size_text, "-")
            self.assertEqual(items["empty.txt"].size_text, "0 B")

    def test_saved_connections_persist_without_passwords(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            settings_path = Path(temp) / "sftp.ini"
            settings = QSettings(str(settings_path), QSettings.Format.IniFormat)
            controller = SftpController(settings=settings)
            try:
                profile_id = controller.saveConnection(
                    "",
                    "Lab server",
                    "192.0.2.25",
                    2222,
                    "student",
                    "",
                    temp,
                    "/opt/labs",
                )
                self.assertTrue(profile_id)
                self.assertEqual(controller.selectedConnection["host"], "192.0.2.25")
                payload = json.loads(settings.value("SFTP/savedConnections"))
                self.assertEqual(payload[0]["remotePath"], "/opt/labs")
                self.assertNotIn("password", payload[0])
            finally:
                controller.shutdown()

            restored = SftpController(
                settings=QSettings(str(settings_path), QSettings.Format.IniFormat)
            )
            try:
                self.assertEqual(len(restored.savedConnections), 1)
                self.assertEqual(restored.savedConnections[0]["username"], "student")
            finally:
                restored.shutdown()

    def test_password_storage_is_explicit_and_absent_from_profile_json(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            settings = QSettings(
                str(Path(temp) / "credentials.ini"), QSettings.Format.IniFormat
            )
            store = _MemoryCredentialStore()
            controller = SftpController(settings=settings, credential_store=store)
            try:
                profile_id = controller.saveConnection(
                    "",
                    "Lab",
                    "192.0.2.30",
                    22,
                    "operator",
                    "",
                    temp,
                    "/",
                    "not-in-json",
                    True,
                )
                self.assertEqual(store.read(profile_id), "not-in-json")
                self.assertTrue(controller.selectedConnection["passwordSaved"])
                self.assertNotIn("password", controller.selectedConnection)
                serialized = str(settings.value("SFTP/savedConnections"))
                self.assertNotIn("not-in-json", serialized)
                self.assertNotIn('"password":', serialized)

                controller.saveConnection(
                    profile_id,
                    "Lab",
                    "192.0.2.30",
                    22,
                    "operator",
                    "",
                    temp,
                    "/",
                    "",
                    False,
                )
                self.assertFalse(store.has(profile_id))
                self.assertFalse(controller.selectedConnection["passwordSaved"])
            finally:
                controller.shutdown()

    def test_profile_connection_uses_protected_password_without_exposing_it(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            store = _MemoryCredentialStore()
            controller = SftpController(
                settings=QSettings(
                    str(Path(temp) / "profile.ini"), QSettings.Format.IniFormat
                ),
                credential_store=store,
            )
            try:
                profile_id = controller.saveConnection(
                    "",
                    "Lab",
                    "192.0.2.31",
                    22,
                    "operator",
                    "",
                    temp,
                    "/",
                    "protected-secret",
                    True,
                )
                captured = {}
                controller._connect_server = (
                    lambda *args: captured.update(
                        profile_id=args[0], password=args[4]
                    )
                )
                controller.connectServerForProfile(
                    profile_id,
                    "192.0.2.31",
                    22,
                    "operator",
                    "",
                    "",
                )
                self.assertEqual(captured["password"], "protected-secret")
                self.assertNotIn("password", controller.savedConnections[0])
            finally:
                controller.shutdown()

    def test_auto_save_password_setting_is_opt_in(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            settings = QSettings(
                str(Path(temp) / "auto-save.ini"), QSettings.Format.IniFormat
            )
            store = _MemoryCredentialStore()
            controller = SftpController(settings=settings, credential_store=store)
            try:
                self.assertFalse(controller.autoSavePasswords)
                result = controller.setAutoSavePasswords(True)
                self.assertTrue(result["ok"])
                self.assertTrue(controller.autoSavePasswords)
                self.assertTrue(bool(settings.value("SFTP/autoSavePasswords")))

                controller.refreshRemote = lambda: None
                controller._pending_connection = ConnectionOptions(
                    "lab.example.test",
                    22,
                    "student",
                    "auto-protected",
                    "",
                )
                controller._pending_initial_remote_path = "/"
                controller._operation_completed(
                    "connect", ("/", "lab.example.test", 22)
                )
                profile = controller.savedConnections[0]
                self.assertTrue(profile["passwordSaved"])
                self.assertEqual(store.read(profile["id"]), "auto-protected")
            finally:
                controller.shutdown()

    def test_windows_dpapi_store_round_trips_without_plaintext(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            settings = QSettings(
                str(Path(temp) / "dpapi.ini"), QSettings.Format.IniFormat
            )
            store = DpapiCredentialStore(settings)
            if not store.available:
                self.skipTest("Windows DPAPI is unavailable")
            store.write("profile-1", "dpapi-secret")
            self.assertEqual(store.read("profile-1"), "dpapi-secret")
            settings.sync()
            self.assertNotIn(
                "dpapi-secret",
                (Path(temp) / "dpapi.ini").read_text(encoding="utf-8"),
            )
            store.delete("profile-1")
            self.assertFalse(store.has("profile-1"))

    def test_successful_connection_is_added_to_saved_connections(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            settings = QSettings(
                str(Path(temp) / "connected.ini"), QSettings.Format.IniFormat
            )
            controller = SftpController(settings=settings)
            try:
                controller.refreshRemote = lambda: None
                controller._pending_connection = ConnectionOptions(
                    "lab.example.test",
                    22,
                    "student",
                    "top-secret",
                    "",
                )
                controller._pending_initial_remote_path = "/"
                controller._operation_completed(
                    "connect", ("/", "lab.example.test", 22)
                )

                self.assertTrue(controller.connected)
                self.assertEqual(len(controller.savedConnections), 1)
                self.assertEqual(
                    controller.savedConnections[0]["host"], "lab.example.test"
                )
                stored = settings.value("SFTP/savedConnections")
                self.assertNotIn("top-secret", stored)
                self.assertNotIn('"password":', stored)
            finally:
                controller.shutdown()

    def test_local_navigation_history_and_default_paths(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            first = Path(temp) / "first"
            second = Path(temp) / "second"
            first.mkdir()
            second.mkdir()
            settings = QSettings(
                str(Path(temp) / "navigation.ini"), QSettings.Format.IniFormat
            )
            controller = SftpController(settings=settings)
            try:
                result = controller.setDefaultPaths(str(first), "/srv/sftp")
                self.assertTrue(result["ok"])
                self.assertEqual(controller.defaultRemotePath, "/srv/sftp")

                controller.openLocalDirectory(str(first))
                controller.openLocalDirectory(str(second))
                self.assertTrue(controller.localCanGoBack)
                controller.localGoBack()
                self.assertEqual(Path(controller.localPath), first)
                self.assertTrue(controller.localCanGoForward)
                controller.localGoForward()
                self.assertEqual(Path(controller.localPath), second)
            finally:
                controller.shutdown()

    def test_batch_entry_rows_are_unique_valid_indices(self) -> None:
        self.assertEqual(
            SftpController._normalize_rows([2, "1", 2, -1, None, "invalid"]),
            [2, 1],
        )

    def test_implementation_avoids_unsafe_host_key_and_recursive_delete_shortcuts(self) -> None:
        app_dir = Path(__file__).resolve().parents[1]
        source = "\n".join(
            path.read_text(encoding="utf-8")
            for path in (app_dir / "features" / "sftp").glob("*.py")
        )
        self.assertNotIn("AutoAddPolicy", source)
        self.assertNotIn("shutil.rmtree", source)


if __name__ == "__main__":
    unittest.main()
