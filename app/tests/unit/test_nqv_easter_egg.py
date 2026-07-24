from __future__ import annotations

import base64
import unittest

from core.app_paths import AppPaths
from main import _runtime_arguments


class NqvEasterEggTests(unittest.TestCase):
    def test_v_flag_is_private_and_removed_before_qt(self):
        arguments, mode = _runtime_arguments(["main.py", "-v", "--style", "Fusion"])
        self.assertEqual(mode, "nqv")
        self.assertEqual(arguments, ["main.py", "--style", "Fusion"])

    def test_default_launch_does_not_enable_easter_egg(self):
        arguments, mode = _runtime_arguments(["main.py"])
        self.assertEqual(mode, "")
        self.assertEqual(arguments, ["main.py"])

    def test_hidden_asset_is_served_as_svg_data_url(self):
        url = AppPaths().hiddenBrandLogo().toString()
        self.assertTrue(url.startswith("data:image/svg+xml;base64,"))
        payload = base64.b64decode(url.split(",", 1)[1]).decode("utf-8")
        self.assertIn("<svg", payload)
        self.assertIn('viewBox="0 0 3892 3892"', payload)

    def test_p_flag_selects_ptit_and_last_brand_flag_wins(self):
        arguments, mode = _runtime_arguments(["main.py", "-v", "-p"])
        self.assertEqual(arguments, ["main.py"])
        self.assertEqual(mode, "ptit")

    def test_hidden_ptit_asset_is_served_as_svg_data_url(self):
        url = AppPaths().hiddenPtitLogo().toString()
        self.assertTrue(url.startswith("data:image/svg+xml;base64,"))
        payload = base64.b64decode(url.split(",", 1)[1]).decode("utf-8")
        self.assertIn("<svg", payload)
        self.assertIn('viewBox="0 0 1000 1000"', payload)
