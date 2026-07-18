from __future__ import annotations

import sqlite3
import tempfile
import unittest
from contextlib import closing
from pathlib import Path
from unittest.mock import patch

from core.runtime import APP_DIR, ExternalToolsManager
from core.tool_catalog import EXTERNAL_TOOL_CATALOG


class ExternalToolsManagerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary_directory.name)
        self.manager = ExternalToolsManager(
            db_path=self.root / "external_tools.db",
            device_db_path=self.root / "device_network.db",
        )

    def tearDown(self) -> None:
        self.temporary_directory.cleanup()

    def _executable(self, name: str = "tool.exe") -> Path:
        path = self.root / name
        path.write_bytes(b"MZ")
        return path

    def test_validate_executable_normalizes_file_urls_and_rejects_invalid_paths(self) -> None:
        executable = self._executable("Detected Tool.exe")

        with patch("core.runtime.sys.platform", "win32"):
            valid = self.manager.validateExecutable(executable.as_uri())
            invalid_extension = self.manager.validateExecutable(str(self._executable("notes.txt")))
            missing = self.manager.validateExecutable(str(self.root / "missing.exe"))

        self.assertTrue(valid["ok"])
        self.assertEqual(Path(valid["path"]), executable)
        self.assertFalse(invalid_extension["ok"])
        self.assertIn("Windows executable", invalid_extension["message"])
        self.assertFalse(missing["ok"])
        self.assertFalse(missing["exists"])

    def test_save_blocks_password_placeholders_and_persists_valid_tools(self) -> None:
        executable = self._executable("putty.exe")

        blocked = self.manager.saveTool(
            "Unsafe PuTTY",
            "SSH Client",
            str(executable),
            "-ssh {ip} -pw {password}",
            True,
            "Must not be saved",
        )
        saved = self.manager.saveTool(
            "PuTTY",
            "SSH Client",
            str(executable),
            "-ssh {ip}",
            True,
            "Detected SSH client",
        )

        self.assertFalse(blocked["ok"])
        self.assertIn("blocked", blocked["message"])
        self.assertTrue(saved["ok"])
        self.assertEqual([tool["app"] for tool in self.manager.getTools()], ["PuTTY"])

    def test_discovery_merges_default_associations_and_marks_saved_candidates(self) -> None:
        executable = self._executable("putty.exe")

        def installed_paths(spec):
            if spec["app"] == "PuTTY":
                return [(str(executable), "Windows App Paths", "High")]
            return []

        defaults = [
            {
                "executable": str(executable),
                "association": "ssh",
                "explicit": True,
                "type": "SSH Client",
            }
        ]

        with (
            patch("core.runtime.sys.platform", "win32"),
            patch.object(self.manager, "_installed_paths_for_spec", side_effect=installed_paths),
            patch.object(self.manager, "_windows_default_handlers", return_value=defaults),
        ):
            first_scan = self.manager.discoverWindowsTools()
            self.manager.saveTool("PuTTY", "SSH Client", str(executable), "-ssh {ip}", True, "")
            second_scan = self.manager.discoverWindowsTools()

        self.assertEqual(len(first_scan), 1)
        self.assertTrue(first_scan[0]["isDefault"])
        self.assertTrue(first_scan[0]["explicitDefault"])
        self.assertEqual(first_scan[0]["defaultFor"], ["ssh"])
        self.assertEqual(first_scan[0]["source"], "Windows default association")
        self.assertFalse(first_scan[0]["alreadyConfigured"])
        self.assertTrue(second_scan[0]["alreadyConfigured"])

    def test_xshell_is_detected_with_safe_official_url_arguments(self) -> None:
        executable = self._executable("Xshell.exe")

        def installed_paths(spec):
            if spec["app"] == "Xshell":
                return [(str(executable), "Windows App Paths", "High")]
            return []

        with (
            patch("core.runtime.sys.platform", "win32"),
            patch.object(self.manager, "_installed_paths_for_spec", side_effect=installed_paths),
            patch.object(self.manager, "_windows_default_handlers", return_value=[]),
        ):
            candidates = self.manager.discoverWindowsTools()

        self.assertEqual(len(candidates), 1)
        self.assertEqual(candidates[0]["app"], "Xshell")
        self.assertEqual(candidates[0]["type"], "SSH Client")
        self.assertEqual(candidates[0]["arguments"], "-url ssh://{ip}")
        self.assertEqual(candidates[0]["source"], "Windows App Paths")

    def test_installed_app_registry_path_participates_in_discovery(self) -> None:
        executable = self._executable("MobaXterm.exe")
        target_spec = next(
            spec for spec in self.manager.WINDOWS_TOOL_SPECS
            if spec["app"] == "MobaXterm"
        )

        with (
            patch.object(self.manager, "_windows_app_path", return_value=""),
            patch("core.runtime.shutil.which", return_value=None),
            patch.object(
                self.manager,
                "_windows_uninstall_paths",
                return_value=[str(executable)],
            ),
        ):
            paths = self.manager._installed_paths_for_spec(target_spec)

        self.assertEqual(
            paths,
            [(str(executable), "Windows installed applications", "High")],
        )

    def test_official_default_terminal_guids_resolve_expected_applications(self) -> None:
        terminal = self._executable("wt.exe")
        console_host = self._executable("cmd.exe")
        scenarios = (
            (self.manager.DEFAULT_TERMINAL_AUTOMATIC_GUID, terminal, False),
            (self.manager.DEFAULT_CONSOLE_HOST_GUID, console_host, True),
            (self.manager.DEFAULT_WINDOWS_TERMINAL_GUID, terminal, True),
            (self.manager.DEFAULT_WINDOWS_TERMINAL_PREVIEW_GUID, terminal, True),
        )

        for delegation_guid, expected_path, expected_explicit in scenarios:
            with self.subTest(delegation_guid=delegation_guid):
                def registry_value(_root, _key_path, value_name=None):
                    if value_name == "DelegationTerminal":
                        return delegation_guid
                    return ""

                def which(executable_name):
                    if executable_name.casefold() == "cmd.exe":
                        return str(console_host)
                    if executable_name.casefold() == "wt.exe":
                        return str(terminal)
                    return None

                with (
                    patch("core.runtime.sys.platform", "win32"),
                    patch("core.runtime.shutil.which", side_effect=which),
                    patch.object(self.manager, "_windows_registry_value", side_effect=registry_value),
                    patch.object(self.manager, "_windows_app_path", return_value=str(terminal)),
                ):
                    handlers = self.manager._windows_default_handlers()

                terminal_handlers = [row for row in handlers if row["association"] == "Default terminal"]
                self.assertEqual(len(terminal_handlers), 1)
                self.assertEqual(Path(terminal_handlers[0]["executable"]), expected_path)
                self.assertEqual(terminal_handlers[0]["explicit"], expected_explicit)

    def test_launch_refuses_legacy_password_arguments_before_process_creation(self) -> None:
        executable = self._executable("legacy.exe")
        with closing(sqlite3.connect(self.manager.db_path)) as connection:
            connection.execute(
                """
                INSERT INTO apps (app, type, executable, arguments, enabled, description)
                VALUES (?, ?, ?, ?, 1, '');
                """,
                ("Legacy", "SSH Client", str(executable), "-pw {password} {ip}"),
            )
            connection.commit()

        with patch("core.runtime.subprocess.Popen") as popen:
            result = self.manager.openDeviceCli("192.0.2.10")

        self.assertFalse(result["ok"])
        self.assertIn("blocked", result["message"])
        popen.assert_not_called()

    def test_launches_enabled_xshell_for_selected_device(self) -> None:
        executable = self._executable("Xshell.exe")
        saved = self.manager.saveTool(
            "Xshell",
            "SSH Client",
            str(executable),
            "-url ssh://{ip}",
            True,
            "Preferred SSH client",
        )
        self.assertTrue(saved["ok"])

        with patch("core.runtime.subprocess.Popen") as popen:
            result = self.manager.openDeviceCli("192.0.2.25")

        self.assertTrue(result["ok"])
        self.assertIn("Xshell", result["message"])
        popen.assert_called_once_with(
            [str(executable), "-url", "ssh://192.0.2.25"],
            cwd=str(APP_DIR),
        )

    def test_catalog_is_an_https_allowlist_and_never_runs_an_installer(self) -> None:
        self.assertGreaterEqual(len(EXTERNAL_TOOL_CATALOG), 8)
        self.assertTrue(
            all(
                str(entry["officialUrl"]).startswith("https://")
                for entry in EXTERNAL_TOOL_CATALOG
            )
        )

        with (
            patch.object(
                self.manager,
                "_installed_paths_for_spec",
                return_value=[],
            ),
            patch("core.runtime.subprocess.run") as run,
            patch("core.runtime.subprocess.Popen") as popen,
        ):
            catalog = self.manager.getExternalToolCatalog()

        self.assertTrue(catalog)
        self.assertTrue(all(row["status"] == "Not installed" for row in catalog))
        run.assert_not_called()
        popen.assert_not_called()

    def test_catalog_does_not_mark_a_missing_saved_executable_as_ready(self) -> None:
        with closing(sqlite3.connect(self.manager.db_path)) as connection:
            connection.execute(
                """
                INSERT INTO apps (
                    app, type, executable, arguments, enabled, description
                )
                VALUES ('PuTTY', 'SSH Client', ?, '-ssh {ip}', 1, '');
                """,
                (str(self.root / "missing-putty.exe"),),
            )
            connection.commit()

        with patch.object(
            self.manager,
            "_installed_paths_for_spec",
            return_value=[],
        ):
            catalog = self.manager.getExternalToolCatalog()

        putty = next(row for row in catalog if row["app"] == "PuTTY")
        self.assertTrue(putty["saved"])
        self.assertFalse(putty["installed"])
        self.assertFalse(putty["configured"])
        self.assertEqual(putty["status"], "Configured path missing")


if __name__ == "__main__":
    unittest.main()
