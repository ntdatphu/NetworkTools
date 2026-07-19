import unittest

from PyQt6.QtQml import QJSEngine
from PyQt6.QtWidgets import QApplication

from features.syslog.manager import _variant_dict


class SyslogManagerVariantTests(unittest.TestCase):
    def test_qml_filter_object_converts_to_python_dict(self) -> None:
        _app = QApplication.instance() or QApplication([])
        engine = QJSEngine()
        filters = engine.evaluate(
            "({host: '192.0.2.1', search: 'CONFIG', severities: [4, 5]})"
        )

        result = _variant_dict(filters)

        self.assertEqual(
            result,
            {
                "host": "192.0.2.1",
                "search": "CONFIG",
                "severities": [4, 5],
            },
        )


if __name__ == "__main__":
    unittest.main()
