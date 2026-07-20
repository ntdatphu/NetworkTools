"""Persistent QSettings-backed QML objects."""

from __future__ import annotations

from typing import Any

from PyQt6.QtCore import QObject, QSettings, pyqtProperty, pyqtSignal, pyqtSlot

class WindowSettings(QObject):
    """Persist main-window geometry without depending on optional QML plugins."""

    settingsChanged = pyqtSignal()

    DEFAULTS: dict[str, Any] = {
        "savedX": 0,
        "savedY": 0,
        "savedWidth": 1280,
        "savedHeight": 800,
        "isMaximized": True,
        "isFirstLaunch": True,
    }

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        settings = QSettings()
        self._settings = settings
        self._values = {
            key: settings.value(f"Window/{key}", default, type=type(default))
            for key, default in self.DEFAULTS.items()
        }

    @pyqtSlot(int, int, int, int, bool)
    def saveState(self, x: int, y: int, width: int, height: int, is_maximized: bool) -> None:
        updates = {
            "savedX": int(x),
            "savedY": int(y),
            "savedWidth": max(1, int(width)),
            "savedHeight": max(1, int(height)),
            "isMaximized": bool(is_maximized),
            "isFirstLaunch": False,
        }
        self._values.update(updates)
        for key, value in updates.items():
            self._settings.setValue(f"Window/{key}", value)
        self._settings.sync()
        self.settingsChanged.emit()

    @pyqtSlot()
    def markLaunched(self) -> None:
        if not bool(self._values["isFirstLaunch"]):
            return
        self._values["isFirstLaunch"] = False
        self._settings.setValue("Window/isFirstLaunch", False)
        self._settings.sync()
        self.settingsChanged.emit()

    @pyqtProperty(int, notify=settingsChanged)
    def savedX(self) -> int:
        return int(self._values["savedX"])

    @pyqtProperty(int, notify=settingsChanged)
    def savedY(self) -> int:
        return int(self._values["savedY"])

    @pyqtProperty(int, notify=settingsChanged)
    def savedWidth(self) -> int:
        return int(self._values["savedWidth"])

    @pyqtProperty(int, notify=settingsChanged)
    def savedHeight(self) -> int:
        return int(self._values["savedHeight"])

    @pyqtProperty(bool, notify=settingsChanged)
    def isMaximized(self) -> bool:
        return bool(self._values["isMaximized"])

    @pyqtProperty(bool, notify=settingsChanged)
    def isFirstLaunch(self) -> bool:
        return bool(self._values["isFirstLaunch"])


class ThemeSettings(QObject):
    settingsChanged = pyqtSignal()

    DEFAULTS: dict[str, Any] = {
        "themeMode": 0,
        "accentColorIndex": 4,
        "lightDarkSideBar": False,
        "useCustomAccentColor": False,
        "customAccentColor": "#356FD6",
    }

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._settings = QSettings()
        self._values: dict[str, Any] = {
            key: self._read_value(key, default)
            for key, default in self.DEFAULTS.items()
        }

    def _read_value(self, key: str, default: Any) -> Any:
        value_type = type(default)
        try:
            value = self._settings.value(f"Theme/{key}", default, type=value_type)
        except TypeError:
            value = self._settings.value(f"Theme/{key}", default)
        return self._normalize_value(key, value)

    def _normalize_value(self, key: str, value: Any) -> Any:
        if key == "themeMode":
            try:
                value = int(value)
            except (TypeError, ValueError):
                return self.DEFAULTS[key]
            return value if value in {0, 1, 2, 3, 4} else self.DEFAULTS[key]
        if key == "accentColorIndex":
            try:
                value = int(value)
            except (TypeError, ValueError):
                return self.DEFAULTS[key]
            return value if 0 <= value <= 11 else self.DEFAULTS[key]
        if key == "lightDarkSideBar":
            if isinstance(value, str):
                return value.strip().casefold() in {"1", "true", "yes", "on"}
            return bool(value)
        if key == "useCustomAccentColor":
            if isinstance(value, str):
                return value.strip().casefold() in {"1", "true", "yes", "on"}
            return bool(value)
        if key == "customAccentColor":
            value = str(value or "").strip()
            return value if value else self.DEFAULTS[key]
        return value

    def _set_value(self, key: str, value: Any) -> None:
        value = self._normalize_value(key, value)
        if self._values.get(key) == value:
            return

        self._values[key] = value
        self._settings.setValue(f"Theme/{key}", value)
        self._settings.sync()
        self.settingsChanged.emit()

    @pyqtProperty(int, notify=settingsChanged)
    def themeMode(self) -> int:
        return int(self._values["themeMode"])

    @themeMode.setter
    def themeMode(self, value: int) -> None:
        self._set_value("themeMode", value)

    @pyqtProperty(int, notify=settingsChanged)
    def accentColorIndex(self) -> int:
        return int(self._values["accentColorIndex"])

    @accentColorIndex.setter
    def accentColorIndex(self, value: int) -> None:
        self._set_value("accentColorIndex", value)

    @pyqtProperty(bool, notify=settingsChanged)
    def lightDarkSideBar(self) -> bool:
        return bool(self._values["lightDarkSideBar"])

    @lightDarkSideBar.setter
    def lightDarkSideBar(self, value: bool) -> None:
        self._set_value("lightDarkSideBar", value)

    @pyqtProperty(bool, notify=settingsChanged)
    def useCustomAccentColor(self) -> bool:
        return bool(self._values["useCustomAccentColor"])

    @useCustomAccentColor.setter
    def useCustomAccentColor(self, value: bool) -> None:
        self._set_value("useCustomAccentColor", value)

    @pyqtProperty(str, notify=settingsChanged)
    def customAccentColor(self) -> str:
        return str(self._values["customAccentColor"])

    @customAccentColor.setter
    def customAccentColor(self, value: str) -> None:
        self._set_value("customAccentColor", value)


class StatusBarSettings(QObject):
    settingsChanged = pyqtSignal()

    DEFAULTS: dict[str, Any] = {
        "showStatusBar": True,
        "showPythonStatus": True,
        "showNetwork": True,
        "showNetworkName": True,
        "showRam": True,
        "showRamBar": True,
        "showRamText": True,
        "ramWarningEnabled": True,
        "ramBlinkOnHigh": True,
        "ramWarningThreshold": 85,
        "showDate": True,
        "showTime": True,
        "showNotifications": True,
        "dateTimeFormatMode": 0,
        "customDateFormat": "dd/MM/yyyy",
        "customTimeFormat": "HH:mm",
    }

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._settings = QSettings()
        self._values: dict[str, Any] = {
            key: self._read_value(key, default)
            for key, default in self.DEFAULTS.items()
        }

    def _read_value(self, key: str, default: Any) -> Any:
        value_type = type(default)
        try:
            return self._settings.value(f"StatusBar/{key}", default, type=value_type)
        except TypeError:
            return self._settings.value(f"StatusBar/{key}", default)

    def _set_value(self, key: str, value: Any) -> None:
        default = self.DEFAULTS[key]
        if isinstance(default, bool):
            value = bool(value)
        elif isinstance(default, int):
            value = int(value)
        else:
            value = str(value)

        if key == "ramWarningThreshold":
            value = max(1, min(100, value))
        elif key == "dateTimeFormatMode":
            value = 1 if value == 1 else 0

        if self._values.get(key) == value:
            return

        self._values[key] = value
        self._settings.setValue(f"StatusBar/{key}", value)
        self._settings.sync()
        self.settingsChanged.emit()

    @pyqtSlot()
    def resetDefaults(self) -> None:
        changed = False
        for key, default in self.DEFAULTS.items():
            if self._values.get(key) != default:
                self._values[key] = default
                self._settings.setValue(f"StatusBar/{key}", default)
                changed = True
        if changed:
            self._settings.sync()
            self.settingsChanged.emit()

    @pyqtProperty(bool, notify=settingsChanged)
    def showStatusBar(self) -> bool:
        return bool(self._values["showStatusBar"])

    @showStatusBar.setter
    def showStatusBar(self, value: bool) -> None:
        self._set_value("showStatusBar", value)

    @pyqtProperty(bool, notify=settingsChanged)
    def showPythonStatus(self) -> bool:
        return bool(self._values["showPythonStatus"])

    @showPythonStatus.setter
    def showPythonStatus(self, value: bool) -> None:
        self._set_value("showPythonStatus", value)

    @pyqtProperty(bool, notify=settingsChanged)
    def showNetwork(self) -> bool:
        return bool(self._values["showNetwork"])

    @showNetwork.setter
    def showNetwork(self, value: bool) -> None:
        self._set_value("showNetwork", value)

    @pyqtProperty(bool, notify=settingsChanged)
    def showNetworkName(self) -> bool:
        return bool(self._values["showNetworkName"])

    @showNetworkName.setter
    def showNetworkName(self, value: bool) -> None:
        self._set_value("showNetworkName", value)

    @pyqtProperty(bool, notify=settingsChanged)
    def showRam(self) -> bool:
        return bool(self._values["showRam"])

    @showRam.setter
    def showRam(self, value: bool) -> None:
        self._set_value("showRam", value)

    @pyqtProperty(bool, notify=settingsChanged)
    def showRamBar(self) -> bool:
        return bool(self._values["showRamBar"])

    @showRamBar.setter
    def showRamBar(self, value: bool) -> None:
        self._set_value("showRamBar", value)

    @pyqtProperty(bool, notify=settingsChanged)
    def showRamText(self) -> bool:
        return bool(self._values["showRamText"])

    @showRamText.setter
    def showRamText(self, value: bool) -> None:
        self._set_value("showRamText", value)

    @pyqtProperty(bool, notify=settingsChanged)
    def ramWarningEnabled(self) -> bool:
        return bool(self._values["ramWarningEnabled"])

    @ramWarningEnabled.setter
    def ramWarningEnabled(self, value: bool) -> None:
        self._set_value("ramWarningEnabled", value)

    @pyqtProperty(bool, notify=settingsChanged)
    def ramBlinkOnHigh(self) -> bool:
        return bool(self._values["ramBlinkOnHigh"])

    @ramBlinkOnHigh.setter
    def ramBlinkOnHigh(self, value: bool) -> None:
        self._set_value("ramBlinkOnHigh", value)

    @pyqtProperty(int, notify=settingsChanged)
    def ramWarningThreshold(self) -> int:
        return int(self._values["ramWarningThreshold"])

    @ramWarningThreshold.setter
    def ramWarningThreshold(self, value: int) -> None:
        self._set_value("ramWarningThreshold", value)

    @pyqtProperty(bool, notify=settingsChanged)
    def showDate(self) -> bool:
        return bool(self._values["showDate"])

    @showDate.setter
    def showDate(self, value: bool) -> None:
        self._set_value("showDate", value)

    @pyqtProperty(bool, notify=settingsChanged)
    def showTime(self) -> bool:
        return bool(self._values["showTime"])

    @showTime.setter
    def showTime(self, value: bool) -> None:
        self._set_value("showTime", value)

    @pyqtProperty(bool, notify=settingsChanged)
    def showNotifications(self) -> bool:
        return bool(self._values["showNotifications"])

    @showNotifications.setter
    def showNotifications(self, value: bool) -> None:
        self._set_value("showNotifications", value)

    @pyqtProperty(int, notify=settingsChanged)
    def dateTimeFormatMode(self) -> int:
        return int(self._values["dateTimeFormatMode"])

    @dateTimeFormatMode.setter
    def dateTimeFormatMode(self, value: int) -> None:
        self._set_value("dateTimeFormatMode", value)

    @pyqtProperty(str, notify=settingsChanged)
    def customDateFormat(self) -> str:
        return str(self._values["customDateFormat"])

    @customDateFormat.setter
    def customDateFormat(self, value: str) -> None:
        self._set_value("customDateFormat", value)

    @pyqtProperty(str, notify=settingsChanged)
    def customTimeFormat(self) -> str:
        return str(self._values["customTimeFormat"])

    @customTimeFormat.setter
    def customTimeFormat(self, value: str) -> None:
        self._set_value("customTimeFormat", value)

__all__ = ["StatusBarSettings", "ThemeSettings", "WindowSettings"]
