"""Qt bridge between the Welcome window and the workspace package service."""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any

from PyQt6.QtCore import QObject, QUrl, pyqtProperty, pyqtSignal, pyqtSlot

from infrastructure.workspace import (
    WorkspacePackageError,
    WorkspacePasswordRequired,
    WorkspaceService,
    WorkspaceSession,
)


class WelcomeController(QObject):
    """Expose project create/open lifecycle operations to QML."""

    recentProjectsChanged = pyqtSignal()
    workspaceRequested = pyqtSignal(str, str)
    welcomeRequested = pyqtSignal(str)
    passwordRequired = pyqtSignal(str)
    operationFailed = pyqtSignal(str, str)
    activeWorkspaceChanged = pyqtSignal()

    def __init__(
        self,
        parent: QObject | None = None,
        *,
        workspace_service: WorkspaceService | None = None,
        default_project_directory: str | Path | None = None,
    ) -> None:
        super().__init__(parent)
        self._workspace_service = workspace_service or WorkspaceService()
        self._default_project_directory = Path(
            default_project_directory or (Path.home() / "Documents")
        ).expanduser()
        self._active_session: WorkspaceSession | None = None
        self._pending_encrypted_path: Path | None = None
        # Persistent recents arrive in a later phase.  Keeping clearly marked
        # mock rows lets the Phase-1 Welcome UI retain its stable model contract.
        self._recent_projects: list[dict[str, Any]] = [
            {
                "id": "mock-core-lab",
                "name": "Core Lab",
                "path": str(Path.home() / "Documents" / "Core-Lab.ntp"),
                "lastOpened": "Today, 09:42",
                "isMock": True,
            },
            {
                "id": "mock-campus-network",
                "name": "Campus Network",
                "path": str(Path.home() / "Documents" / "Campus-Network.ntp"),
                "lastOpened": "Yesterday",
                "isMock": True,
            },
            {
                "id": "mock-branch-rollout",
                "name": "Branch Rollout",
                "path": str(Path.home() / "Documents" / "Branch-Rollout.ntp"),
                "lastOpened": "28 Jul 2026",
                "isMock": True,
            },
        ]

    @pyqtProperty("QVariantList", notify=recentProjectsChanged)
    def recentProjects(self) -> list[dict[str, Any]]:
        return [dict(project) for project in self._recent_projects]

    @pyqtProperty(str, notify=activeWorkspaceChanged)
    def activeProjectPath(self) -> str:
        return str(self._active_session.project_path) if self._active_session else ""

    @pyqtProperty(str, notify=activeWorkspaceChanged)
    def activeWorkspacePath(self) -> str:
        return (
            str(self._active_session.working_directory)
            if self._active_session
            else ""
        )

    @pyqtProperty(bool, notify=activeWorkspaceChanged)
    def activeProjectEncrypted(self) -> bool:
        return bool(self._active_session and self._active_session.encrypted)

    def active_session(self) -> WorkspaceSession | None:
        """Return the Python session object for lifecycle coordinators."""

        return self._active_session

    @property
    def workspace_service(self) -> WorkspaceService:
        return self._workspace_service

    def _request_mock_workspace(self, name: str, path: str) -> None:
        display_name = (name or "NetworkTools Project").strip()
        self.workspaceRequested.emit(display_name, (path or "").strip())

    def _activate(self, session: WorkspaceSession) -> None:
        previous = self._active_session
        self._active_session = session
        self._pending_encrypted_path = None
        if previous is not None and previous is not session:
            previous.close()
        self.activeWorkspaceChanged.emit()
        self.workspaceRequested.emit(session.manifest.name, str(session.project_path))

    @pyqtSlot(str)
    def openRecent(self, project_id: str) -> None:
        wanted = (project_id or "").strip()
        project = next(
            (entry for entry in self._recent_projects if entry["id"] == wanted),
            None,
        )
        if project is None:
            return
        if project.get("isMock"):
            self._request_mock_workspace(str(project["name"]), str(project["path"]))
            return
        self._open_path(Path(str(project["path"])), password=None)

    @pyqtSlot(str)
    @pyqtSlot(str, str)
    def createProject(self, project_name: str, password: str = "") -> None:
        """Create under the default project folder; blank password means plain ZIP."""

        name = (project_name or "").strip() or "Untitled Project"
        safe_stem = re.sub(r"[^A-Za-z0-9._-]+", "-", name).strip("-.")
        if not safe_stem:
            safe_stem = "Untitled-Project"
        target = self._default_project_directory / f"{safe_stem}.ntp"
        self._create_at(name, target, password)

    @pyqtSlot(str, QUrl, str)
    def createProjectAt(
        self, project_name: str, project_url: QUrl, password: str = ""
    ) -> None:
        """Create at an explicit local file URL for the completed location picker."""

        if not project_url.isLocalFile():
            self.operationFailed.emit("Create Project", "Choose a local project path.")
            return
        local_path = project_url.toLocalFile().strip()
        if not local_path:
            self.operationFailed.emit("Create Project", "Choose a project path.")
            return
        self._create_at((project_name or "").strip(), Path(local_path), password)

    def _create_at(self, name: str, target: Path, password: str) -> None:
        try:
            session = self._workspace_service.create_project(
                name or "Untitled Project",
                target,
                password=password or None,
            )
        except (OSError, ValueError, WorkspacePackageError) as exc:
            self.operationFailed.emit("Create Project", str(exc))
            return
        self._activate(session)

    @pyqtSlot(QUrl)
    def openProject(self, project_url: QUrl) -> None:
        if not project_url.isLocalFile():
            self.operationFailed.emit("Open Project", "Choose a local .ntp file.")
            return
        local_path = project_url.toLocalFile().strip()
        if not local_path:
            self.operationFailed.emit("Open Project", "Choose a project file.")
            return
        self._open_path(Path(local_path), password=None)

    @pyqtSlot(str)
    def unlockProject(self, password: str) -> None:
        """Retry the pending encrypted project without persisting the password."""

        path = self._pending_encrypted_path
        if path is None:
            return
        self._open_path(path, password=password)

    def _open_path(self, path: Path, password: str | None) -> None:
        try:
            session = self._workspace_service.open_project(path, password=password)
        except WorkspacePasswordRequired:
            self._pending_encrypted_path = path
            self.passwordRequired.emit(str(path))
            return
        except (OSError, ValueError, WorkspacePackageError) as exc:
            self.operationFailed.emit("Open Project", str(exc))
            return
        self._activate(session)

    @pyqtSlot()
    def closeProject(self) -> None:
        session = self._active_session
        self._active_session = None
        self._pending_encrypted_path = None
        if session is not None:
            session.close()
            self.activeWorkspaceChanged.emit()

    def shutdown(self) -> None:
        self.closeProject()

    @pyqtSlot(str)
    def requestWelcome(self, mode: str = "") -> None:
        normalized_mode = (mode or "").strip().lower()
        if normalized_mode not in {"", "create", "open", "settings"}:
            normalized_mode = ""
        self.welcomeRequested.emit(normalized_mode)


__all__ = ["WelcomeController"]
