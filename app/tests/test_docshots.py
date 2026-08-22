from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stderr
from io import StringIO
from pathlib import Path
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

import main as _main_bootstrap  # noqa: F401 - configures PyQt paths
from PyQt6.QtGui import QImageReader

from docshots.cli import DEFAULT_OUTPUT_DIR, build_parser, ensure_output_directory
from docshots.runtime import DocumentationTerminal
from docshots.shots import SHOT_REGISTRY, resolve_shots


APP_DIR = Path(__file__).resolve().parents[1]


class DocshotCliTests(unittest.TestCase):
    def test_parser_defaults_and_overrides(self) -> None:
        defaults = build_parser().parse_args(["welcome"])
        self.assertEqual(defaults.width, 1600)
        self.assertEqual(defaults.height, 1000)
        self.assertEqual(defaults.scale, 2.0)
        self.assertEqual(defaults.theme, "light")
        self.assertEqual(defaults.output_dir, DEFAULT_OUTPUT_DIR)

        custom = build_parser().parse_args(
            ["workspace", "--width", "1200", "--height", "750", "--scale", "1.5", "--theme", "dark"]
        )
        self.assertEqual((custom.width, custom.height, custom.scale), (1200, 750, 1.5))
        self.assertEqual(custom.theme, "dark")

    def test_output_directory_is_created(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "nested" / "gui"
            self.assertEqual(ensure_output_directory(output), output.resolve())
            self.assertTrue(output.is_dir())

    def test_registry_and_all_are_stable(self) -> None:
        self.assertEqual(tuple(SHOT_REGISTRY), ("welcome", "workspace", "devices"))
        self.assertEqual(
            tuple(shot.name for shot in resolve_shots("all")),
            tuple(SHOT_REGISTRY),
        )

    def test_unknown_shot_is_rejected(self) -> None:
        with redirect_stderr(StringIO()), self.assertRaises(SystemExit):
            build_parser().parse_args(["not-a-shot"])
        with self.assertRaisesRegex(ValueError, "Unknown shot"):
            resolve_shots("not-a-shot")

    def test_documentation_terminal_never_starts_network_or_processes(self) -> None:
        terminal = DocumentationTerminal()
        with patch("socket.create_connection") as connect, patch("subprocess.Popen") as popen:
            self.assertTrue(terminal.openDeviceSessionAsync("192.0.2.1"))
            self.assertTrue(terminal.hasDeviceSession("192.0.2.1"))
            self.assertFalse(terminal.connectHostAndSyncAsync("192.0.2.1"))
            connect.assert_not_called()
            popen.assert_not_called()
        terminal.shutdown()
        self.assertTrue(terminal.shut_down)


class DocshotHeadlessTests(unittest.TestCase):
    def test_all_renders_lossless_pngs_at_requested_size(self) -> None:
        fixture_pattern = "networktools-docshots-*"
        fixtures_before = set(Path(tempfile.gettempdir()).glob(fixture_pattern))
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "gui"
            command = [
                sys.executable,
                str(APP_DIR / "scripts" / "docshots.py"),
                "all",
                "--width",
                "800",
                "--height",
                "500",
                "--scale",
                "1",
                "--output-dir",
                str(output),
            ]
            completed = subprocess.run(
                command,
                cwd=APP_DIR,
                text=True,
                capture_output=True,
                timeout=90,
                check=False,
            )
            self.assertEqual(completed.returncode, 0, completed.stderr)
            for name in SHOT_REGISTRY:
                path = output / f"{name}.png"
                self.assertTrue(path.is_file(), path)
                self.assertGreater(path.stat().st_size, 0)
                reader = QImageReader(str(path), b"PNG")
                self.assertTrue(reader.canRead(), reader.errorString())
                self.assertEqual((reader.size().width(), reader.size().height()), (800, 500))
                self.assertFalse(reader.read().isNull(), reader.errorString())
        self.assertEqual(
            set(Path(tempfile.gettempdir()).glob(fixture_pattern)),
            fixtures_before,
        )


if __name__ == "__main__":
    unittest.main()
