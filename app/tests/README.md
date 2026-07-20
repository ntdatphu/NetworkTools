# Tests

Chạy `python -m unittest discover -s tests`. `unit` dành cho validation/repository nhỏ, `integration` dùng SQLite tạm và fake connector, `qml` chứa harness smoke, `fixtures` chứa dữ liệu không bí mật. Test không được mở kết nối thiết bị thật; dev mode phải dùng fake/session giả.

Config backup có unit test repository Dulwich trong `tests/unit/` và integration test migration trong `tests/integration/`; toàn bộ dùng thư mục tạm.
