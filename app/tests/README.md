# Tests

Chạy `python -m unittest discover -s tests`. `unit` dành cho validation/repository nhỏ, `integration` dùng SQLite tạm và fake connector, `qml` chứa harness smoke, `fixtures` chứa dữ liệu không bí mật. Test không được mở kết nối thiết bị thật; dev mode phải dùng fake/session giả.

Config backup có unit test repository Dulwich trong `tests/unit/` và integration test migration trong `tests/integration/`; toàn bộ dùng thư mục tạm.

`test_core_refactor_contracts.py` khóa các ranh giới refactor: import tương thích vẫn hoạt động, terminal không phụ thuộc `DatabaseManager`, và chỉ có một implementation `DeviceSessionRegistry`. `scripts/validate_structure.py` cũng giới hạn `runtime.py` ở dạng shim ngắn để monolith không quay lại.

Các regression test cho sidebar/session nhiều thiết bị:

- `test_device_selection_contracts.py`: action dùng host, context target là
  snapshot và đóng tab không đóng session.
- `test_session_registry_concurrency.py`: cùng host được serialize, host khác
  được chạy overlap và session vẫn sống sau operation.
- `test_multi_device_batch.py`: deduplicate, giới hạn concurrency và partial
  failure không dừng cả batch.
- `test_terminal_multi_host.py`: contract tương thích của API nhiều host cũ.
