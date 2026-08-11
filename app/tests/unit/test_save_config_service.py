import unittest

from features.devices.save_config_service import SaveConfigService


class _Connection:
    def __init__(self, output="[OK]"):
        self.output = output
        self.calls = 0

    def save_config(self):
        self.calls += 1
        return self.output


class _Connector:
    def __init__(self, connection):
        self.connection = connection


class _Registry:
    def __init__(self, connector=None, failure=None):
        self.connector = connector
        self.failure = failure
        self.ensure_open = None

    def execute(self, host, operation, *, ensure_open=True):
        self.ensure_open = ensure_open
        if self.failure:
            return {"ok": False, "severity": "error", "message": self.failure}
        try:
            return {"ok": True, "value": operation(self.connector)}
        except Exception as exc:
            return {"ok": False, "severity": "error", "message": str(exc)}


class SaveConfigServiceTests(unittest.TestCase):
    def test_save_uses_driver_and_never_opens_a_session_implicitly(self):
        connection = _Connection("Building configuration...\n[OK]")
        registry = _Registry(_Connector(connection))

        result = SaveConfigService(registry).save("192.0.2.10")

        self.assertTrue(result["ok"])
        self.assertEqual(connection.calls, 1)
        self.assertFalse(registry.ensure_open)
        self.assertIn("startup configuration", result["message"])

    def test_missing_driver_capability_fails_closed(self):
        registry = _Registry(_Connector(object()))

        result = SaveConfigService(registry).save("192.0.2.10")

        self.assertFalse(result["ok"])
        self.assertIn("does not support", result["message"])

    def test_invalid_command_output_is_not_reported_as_success(self):
        registry = _Registry(_Connector(_Connection("% Invalid input detected")))

        result = SaveConfigService(registry).save("192.0.2.10")

        self.assertFalse(result["ok"])
        self.assertIn("rejected", result["message"])


if __name__ == "__main__":
    unittest.main()
