from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path


APP_ROOT = Path(__file__).resolve().parents[1]


class LauncherContractTests(unittest.TestCase):
    def test_setup_treats_cython_acceleration_as_optional(self) -> None:
        batch = (APP_ROOT / "networktools.bat").read_text(encoding="utf-8")
        shell = (APP_ROOT / "networktools.sh").read_text(encoding="utf-8")

        self.assertIn('"%~f0" build', batch)
        self.assertIn("build_cython_optional", shell)
        self.assertIn("sync engine fallback", batch)
        self.assertIn("sync engine fallback", shell)

    def test_explicit_build_stays_strict(self) -> None:
        batch = (APP_ROOT / "networktools.bat").read_text(encoding="utf-8")
        shell = (APP_ROOT / "networktools.sh").read_text(encoding="utf-8")

        self.assertIn('if /I "%~1"=="build" goto build', batch)
        self.assertIn("build) build_cython ;;", shell)

    def test_windows_can_replace_blocked_cython_wheel(self) -> None:
        batch = (APP_ROOT / "networktools.bat").read_text(encoding="utf-8")

        self.assertIn("set \"NO_CYTHON_COMPILE=true\"", batch)
        self.assertIn("--reinstall-package cython", batch)
        self.assertIn("--no-binary-package cython", batch)

    @unittest.skipUnless(os.name == "nt", "Windows batch launcher test")
    def test_windows_menu_full_setup_dispatches_without_nested_call(self) -> None:
        batch_path = APP_ROOT / "networktools.bat"
        batch = batch_path.read_text(encoding="utf-8")
        self.assertNotIn("call :", batch)

        with tempfile.TemporaryDirectory() as temp_dir:
            fake_uv = Path(temp_dir) / "uv.cmd"
            fake_uv.write_text(
                '@echo off\r\nif /I "%~1"=="--version" echo uv-test 0.0\r\nexit /b 0\r\n',
                encoding="utf-8",
            )
            environment = os.environ.copy()
            environment["PATH"] = temp_dir + os.pathsep + environment.get("PATH", "")

            completed = subprocess.run(
                ["cmd.exe", "/d", "/c", str(batch_path)],
                input="6\n",
                text=True,
                capture_output=True,
                cwd=APP_ROOT,
                env=environment,
                timeout=30,
                check=False,
            )

        output = completed.stdout + completed.stderr
        self.assertEqual(completed.returncode, 0, output)
        self.assertEqual(output.count("uv-test 0.0"), 3, output)
        self.assertNotIn("cannot find the batch label", output.lower())


if __name__ == "__main__":
    unittest.main()
