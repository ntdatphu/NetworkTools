from __future__ import annotations

import stat
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

import paramiko

from sftp_client.controller import valid_entry_name
from sftp_client.file_model import format_size
from sftp_client.local_service import LocalFileService
from sftp_client.sftp_service import (
    CaptureHostKeyPolicy,
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

    def test_implementation_avoids_unsafe_host_key_and_recursive_delete_shortcuts(self) -> None:
        app_dir = Path(__file__).resolve().parents[1]
        source = "\n".join(
            path.read_text(encoding="utf-8")
            for path in (app_dir / "backend" /"sftp_client").glob("*.py")
        )
        self.assertNotIn("AutoAddPolicy", source)
        self.assertNotIn("shutil.rmtree", source)


if __name__ == "__main__":
    unittest.main()
