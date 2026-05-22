# Kế hoạch Routing Backend và UI

Tài liệu này mô tả kế hoạch/định hướng phát triển module Routing theo source hiện tại trên nhánh `main`.

## Mục tiêu

- Hoàn thiện luồng quản lý cấu hình Routing theo từng thiết bị.
- Hỗ trợ các nhóm cấu hình chính:
  - Static route.
  - Default route.
  - OSPF.
  - EIGRP.
- Đồng bộ dữ liệu giữa QML UI và C++ repository/database layer.
- Chuẩn bị nền tảng cho sinh và triển khai cấu hình tự động trong môi trường lab.

## Hiện trạng source

Module Routing hiện nằm ở các nhóm source chính:

```text
frontend/qml/routing/
frontend/qml/routing/static/
frontend/qml/routing/ospf/
frontend/qml/routing/eigrp/
frontend/src/database/routing/
```

Các file QML và source C++ liên quan được đăng ký trong:

```text
frontend/CMakeLists.txt
```

## Thành phần UI

### Routing shell

```text
qml/routing/RoutingView.qml
qml/routing/RoutingSubBar.qml
```

Vai trò:

- Điều phối màn hình Routing.
- Chuyển đổi giữa các nhóm Routing.
- Nhận context thiết bị hiện tại từ content/device flow.

### Static routing

```text
qml/routing/static/StaticRoutingForm.qml
qml/routing/static/StaticRouteRow.qml
qml/routing/static/StaticRoutingDefaultCard.qml
qml/routing/static/StaticRoutingRoutesCard.qml
```

Vai trò:

- Nhập default route.
- Nhập static routes.
- Hiển thị danh sách route đã lưu.
- Chuẩn hóa UI cho thao tác thêm/sửa/xóa route.

### OSPF

```text
qml/routing/ospf/OspfRoutingForm.qml
qml/routing/ospf/OspfProcessCard.qml
```

Vai trò:

- Nhập OSPF process.
- Nhập router ID, network statements và các tùy chọn liên quan.

### EIGRP

```text
qml/routing/eigrp/EigrpRoutingForm.qml
qml/routing/eigrp/EigrpProcessCard.qml
```

Vai trò:

- Nhập EIGRP process.
- Nhập network statements và các tùy chọn liên quan.

## Thành phần backend/database

Routing repositories nằm trong:

```text
frontend/src/database/routing/
```

Nhóm repository chính:

```text
RoutingStaticRepository
OspfRoutingRepository
EigrpRoutingRepository
```

Vai trò:

- Tách logic truy vấn SQL theo domain Routing.
- Giảm tải cho `DatabaseManager`.
- Giúp QML gọi nghiệp vụ thông qua facade thay vì truy cập SQL trực tiếp.

## Schema liên quan

Schema runtime nằm trong:

```text
python app kenel/sql/main.sql
```

Các nhóm bảng Routing có thể gồm:

```text
static_default_routes
static_routes
ospf_processes
ospf_networks
eigrp_processes
eigrp_networks
```

## Hướng hoàn thiện

### Giai đoạn 1: Ổn định CRUD

- Đảm bảo UI load đúng dữ liệu theo `host`.
- Đảm bảo thêm/sửa/xóa route hoặc process lưu đúng database.
- Đảm bảo khi đổi thiết bị/tab, dữ liệu được reload đúng.
- Chuẩn hóa trạng thái empty/loading/error nếu cần.

### Giai đoạn 2: Chuẩn hóa validation

- Kiểm tra thiếu trường bắt buộc.
- Kiểm tra định dạng IP/subnet/wildcard/AD/process ID.
- Hiển thị lỗi rõ ràng trên UI.
- Hạn chế dữ liệu sai đi vào database.

### Giai đoạn 3: Chuẩn bị sinh cấu hình

- Chuyển dữ liệu trong database thành model cấu hình trung gian.
- Định nghĩa mapping từ database sang câu lệnh cấu hình.
- Tách phần generate config khỏi UI.
- Cho phép preview cấu hình trước khi triển khai.

### Giai đoạn 4: Kiểm thử lab

- Kiểm thử với dữ liệu mock.
- Kiểm thử trong môi trường mô phỏng/lab.
- Ghi nhận thời gian thao tác, số lỗi, số bước so với cấu hình thủ công.

## Tiêu chí hoàn thành

| Nhóm | Tiêu chí |
|---|---|
| UI | Người dùng nhập/sửa/xóa cấu hình Routing rõ ràng |
| Database | Dữ liệu lưu đúng host và đúng bảng |
| Validation | Hạn chế lỗi nhập liệu cơ bản |
| Reload state | Đổi tab/thiết bị không mất hoặc lẫn dữ liệu |
| Research | Có kịch bản kiểm thử và kết quả đánh giá |

## Liên kết tài liệu liên quan

- [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)
- [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md)
- [analysis/DATA_SQL_ANALYSIS.md](analysis/DATA_SQL_ANALYSIS.md)
- [research/TEST_SCENARIOS.md](research/TEST_SCENARIOS.md)
- [research/EVALUATION_CRITERIA.md](research/EVALUATION_CRITERIA.md)
