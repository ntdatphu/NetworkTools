"""Application/resource paths exposed to Python and QML."""

from infrastructure.database.paths import APP_DIR, DATA_DIR
from PyQt6.QtCore import QObject, QUrl, pyqtSlot

QML_MODULE_DIR = APP_DIR / "UI"
TEMPLATES_DIR = APP_DIR / "templates"
FEATURES_DIR = APP_DIR / "features"


class AppPaths(QObject):
    """Expose safe local UI resource URLs to QML."""

    @pyqtSlot(str, result=QUrl)
    def resource(self, relative_path: str) -> QUrl:
        """Resolve one path below the public QML module directory."""
        return QUrl.fromLocalFile(str((QML_MODULE_DIR / relative_path).resolve()))

__all__ = ["APP_DIR", "AppPaths", "DATA_DIR", "FEATURES_DIR", "QML_MODULE_DIR", "TEMPLATES_DIR"]
