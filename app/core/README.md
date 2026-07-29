# Core

Dịch vụ dùng chung và các facade QML ổn định. Không thêm CRUD, SQL, template lệnh hoặc protocol worker mới vào đây; chúng thuộc `features` hoặc `infrastructure`.

- `runtime.py`: shim import tương thích, hạn loại bỏ 2026-10-20; code mới không import file này.
- `terminal.py`: facade QML cho phiên terminal, nhận registry/device service/coordinator qua constructor.
- `tasks.py`: một cơ chế quản lý vòng đời `QThread` dùng chung.
- `app_paths.py`, `settings.py`, `monitoring.py`: owner thật của các QObject cấp ứng dụng.
- `external_tools.py`: facade tương thích; phần repository/discovery còn được tách tiếp.
- `database/`: giữ contract `DatabaseManager`; manager chỉ composition/signal/health slot, còn inventory, import, routing, view-push và unsupported contract nằm trong các file `*_slots.py` riêng; `conversion.py` chứa helper thuần.
- `terminal.py`: hỗ trợ connect/sync từng host hoặc khởi chạy nhiều host đồng thời; mỗi host có task key độc lập để một kết nối chậm không khóa các host còn lại.
- `__init__.py`: export facade theo lazy import để feature/test thuần không phải tải toàn bộ dependency runtime.

Context property và chữ ký slot/signal QML phải được giữ ổn định trong thời gian di chuyển.
