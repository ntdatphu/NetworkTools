from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from core.database.manager import DatabaseManager
from infrastructure.workspace import WorkspaceService


class WorkspaceDatabaseIsolationTests(unittest.TestCase):
    def test_switching_projects_does_not_reuse_device_inventory(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            service = WorkspaceService()
            first = service.create_project("test1", root / "test1.ntp")
            second = None
            manager = DatabaseManager(
                db_path=first.device_network_db,
                info_db_path=first.info_collected_db,
            )
            try:
                self.assertTrue(
                    manager.addDevice(
                        "10.2.3.1", "router", "ssh", "22", "user", "pass"
                    )
                )
                self.assertEqual(
                    [row["ip"] for row in manager.getDevices()], ["10.2.3.1"]
                )

                second = service.create_project("test2", root / "test2.ntp")
                self.assertTrue(
                    manager.set_workspace_databases(
                        second.device_network_db, second.info_collected_db
                    )
                )
                self.assertEqual(manager.getDevices(), [])
            finally:
                manager.shutdown()
                service.close_project(first)
                service.close_project(second)


if __name__ == "__main__":
    unittest.main()
