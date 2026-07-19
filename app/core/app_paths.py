"""Application/resource paths exposed to Python and QML."""

from infrastructure.database.paths import APP_DIR, DATA_DIR

QML_MODULE_DIR = APP_DIR / "UI"
TEMPLATES_DIR = APP_DIR / "templates"

__all__ = ["APP_DIR", "DATA_DIR", "QML_MODULE_DIR", "TEMPLATES_DIR"]
