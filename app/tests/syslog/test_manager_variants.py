from PyQt6.QtQml import QJSEngine
from PyQt6.QtWidgets import QApplication

from syslog_server.manager import _variant_dict


def test_qml_filter_object_converts_to_python_dict() -> None:
    _app = QApplication.instance() or QApplication([])
    engine = QJSEngine()
    filters = engine.evaluate("({host: '192.0.2.1', search: 'CONFIG', severities: [4, 5]})")

    result = _variant_dict(filters)

    assert result == {
        "host": "192.0.2.1",
        "search": "CONFIG",
        "severities": [4, 5],
    }
