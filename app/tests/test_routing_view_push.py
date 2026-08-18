from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from features.routing.view_push import RoutingViewPushController


class _Database:
    def _sync_worker_paths(self) -> None:
        pass

    def _routing_module(self, module: str) -> str:
        return module


class RoutingViewPushControllerTests(unittest.TestCase):
    def test_missing_current_report_never_reuses_stale_success(self) -> None:
        controller = RoutingViewPushController(_Database(), session_registry=object())
        controller._session_provider_for_host = lambda _host: object()

        with tempfile.TemporaryDirectory() as temp_dir:
            stale = Path(temp_dir) / "routing_log_ospf_192_0_2_1.json"
            stale.write_text(
                '[{"status": "SUCCESS", "log": "old run"}]',
                encoding="utf-8",
            )
            with (
                patch("infrastructure.network.config.TMP_DIR", temp_dir),
                patch("features.routing.dispatcher.routing_dispatcher"),
            ):
                result = controller.push_tasks(
                    "192.0.2.1", "ospf", [{"target": {"ip": "192.0.2.1"}}]
                )

        self.assertFalse(result["ok"])
        self.assertIn("returned no result", result["message"])


if __name__ == "__main__":
    unittest.main()
