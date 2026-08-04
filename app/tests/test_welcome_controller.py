from __future__ import annotations

import unittest
import tempfile
from pathlib import Path

from PyQt6.QtCore import QUrl

from core.welcome import WelcomeController
from infrastructure.workspace import Argon2Parameters, WorkspacePackageCodec, WorkspaceService


class WelcomeControllerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        codec = WorkspacePackageCodec(
            encryption_parameters=Argon2Parameters(
                memory_cost_kib=8 * 1024, iterations=1, lanes=1
            )
        )
        self.controller = WelcomeController(
            workspace_service=WorkspaceService(codec),
            default_project_directory=self.temporary.name,
        )
        self.workspace_requests: list[tuple[str, str]] = []
        self.welcome_requests: list[str] = []
        self.password_requests: list[str] = []
        self.controller.workspaceRequested.connect(
            lambda name, path: self.workspace_requests.append((name, path))
        )
        self.controller.welcomeRequested.connect(self.welcome_requests.append)
        self.controller.passwordRequired.connect(self.password_requests.append)

    def tearDown(self) -> None:
        self.controller.shutdown()
        self.temporary.cleanup()

    def test_mock_recent_project_opens_through_stable_signal(self) -> None:
        projects = self.controller.recentProjects

        self.assertGreaterEqual(len(projects), 3)
        self.assertTrue(all(project["isMock"] for project in projects))

        self.controller.openRecent(projects[0]["id"])

        self.assertEqual(self.workspace_requests[0][0], projects[0]["name"])
        self.assertTrue(self.workspace_requests[0][1].endswith(".ntp"))

    def test_create_project_builds_real_ntp_and_active_temp_workspace(self) -> None:
        self.controller.createProject("Campus Core / Lab")

        name, path = self.workspace_requests[0]
        self.assertEqual(name, "Campus Core / Lab")
        self.assertTrue(path.endswith("Campus-Core-Lab.ntp"))
        self.assertTrue(Path(path).is_file())
        self.assertTrue(Path(self.controller.activeWorkspacePath).is_dir())

    def test_open_project_uses_selected_file_name(self) -> None:
        self.controller.createProject("Edge-Lab")
        project_path = self.workspace_requests[-1][1]
        self.workspace_requests.clear()
        self.controller.openProject(QUrl.fromLocalFile(project_path))

        self.assertEqual(self.workspace_requests[0][0], "Edge-Lab")
        self.assertTrue(self.workspace_requests[0][1].endswith("Edge-Lab.ntp"))

    def test_encrypted_project_requests_password_then_unlocks(self) -> None:
        self.controller.createProject("Secret Lab", "correct password")
        project_path = self.workspace_requests[-1][1]
        self.workspace_requests.clear()

        self.controller.openProject(QUrl.fromLocalFile(project_path))

        self.assertEqual(self.password_requests, [project_path])
        self.assertEqual(self.workspace_requests, [])
        self.controller.unlockProject("correct password")
        self.assertEqual(self.workspace_requests[0][0], "Secret Lab")
        self.assertTrue(self.controller.activeProjectEncrypted)

    def test_welcome_mode_is_bounded_to_supported_actions(self) -> None:
        self.controller.requestWelcome("settings")
        self.controller.requestWelcome("unsupported")

        self.assertEqual(self.welcome_requests, ["settings", ""])

    def test_launcher_loads_welcome_before_workspace(self) -> None:
        source = (Path(__file__).resolve().parents[1] / "main.py").read_text(
            encoding="utf-8"
        )

        welcome_load = source.index('engine.loadFromModule("UI", "Welcome")')
        workspace_load = source.index('engine.loadFromModule("UI", "Main")')
        workspace_handler = source.index("def open_workspace(")

        self.assertGreater(workspace_load, workspace_handler)
        self.assertGreater(welcome_load, workspace_handler)
        self.assertIn(
            'context.setContextProperty("welcomeController", welcome_controller)',
            source,
        )


    def test_persistent_recents_record_and_get_most_recent(self) -> None:
        self.controller.createProject("Persistent Lab")
        _, created_path = self.workspace_requests[-1]

        most_recent = self.controller.get_most_recent_project()
        self.assertIsNotNone(most_recent)
        self.assertEqual(most_recent["name"], "Persistent Lab")
        self.assertEqual(most_recent["path"], created_path)
        self.assertFalse(most_recent.get("isMock", False))

        self.controller.removeRecent(created_path)
        new_most_recent = self.controller.get_most_recent_project()
        self.assertIsNone(new_most_recent)


if __name__ == "__main__":
    unittest.main()
