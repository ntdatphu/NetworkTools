# Kiểm kê `app/` theo nhánh

## Phương pháp

Số liệu lấy từ `git ls-tree -r --name-only <ref> -- app`, không tính
`app/uv.lock`. File test là file nằm dưới `app/tests/`, không phải số test case.
Số liệu worktree dùng tracked + untracked non-ignored files.

## So sánh quy mô

| Nhóm | `frontend/test` | `feature/tools-extension-nqv` | `frontend/merges` worktree cuối |
|---|---:|---:|---:|
| Tổng file `app/` | 335 | 445 | 382 |
| Python | 77 | 109 | 104 |
| QML | 145 | 170 | 165 |
| SVG | 50 | 94 | 50 |
| File test | 15 | 18 | 18 |

Nhánh đích giữ nguyên 50 SVG của nền: không nhập kho icon SFTP riêng. Phần tăng
Python/QML tập trung vào repository, controller, view và test có ownership rõ.

## `frontend/test`: kiến trúc nền

- `app/UI/`: module `UI`, theme/state/token, shared/base/standard component,
  Activity Bar, Sidebar, Device Tabs, Feature Bar, Content Area, routing,
  DHCP, ACL, NAT, Information, Settings và notification.
- `app/backend/`: persistence/worker cho routing và các dịch vụ hiện hữu.
- `app/network_code/`: worker và logic mạng được gọi qua backend bridge.
- `app/core/`: runtime QObjects, DB bridge, background task và slot modules.
- `app/database/`: SQL schema/build logic.
- `app/tests/`: backend persistence, worker, QML smoke và UI contract.
- `app/main.py`: tạo QApplication, context properties và load module `UI/Main`.

## `feature/tools-extension-nqv`: phần được phát hiện

Thư mục/tính năng mới đáng chú ý:

- `app/backend/log_core/`, `app/UI/qml/logQml/`, `app/database/log_schema/`;
- `app/backend/sftpCient/`, `app/UI/qml/sftpCientQml/`;
- `app/backend/switching/`, `app/UI/qml/switch/`;
- `app/sftp_icons/` và `app/sftp_icons/filetype_icons/`;
- capture/runtime sample dưới `app/captures/`;
- installer và thay đổi CLI/SSH trong `app/core/`, `app/main.py`;
- thay đổi OSPF trong `app/backend/route/ospf/`.

Các vấn đề:

- TShark discovery/decode có đường chạy đồng bộ; signal theo từng packet; chưa
  có giới hạn phiên/DB/retention.
- SFTP package sai chính tả, dùng nhiều asset riêng, host-key/lifecycle chưa
  đồng nhất với runtime hiện tại.
- installer preselect app thiếu và gọi package manager để thay đổi hệ thống.
- CLI bỏ External Tools do người dùng cấu hình, thêm Telnet/native SSH và thuật
  toán SHA-1.
- nhiều QML không dùng đầy đủ theme/component contract hiện tại.

## `frontend/merges`: cấu trúc sau smart merge

### Giữ nguyên và gia cố

- `app/backend/route/ospf/`, `app/backend/route/eigrp/`: canonical persistence.
- `app/core/runtime.py`: giữ External Tools workflow, bổ sung catalog query.
- `app/UI/qml/app/Main.qml`: workspace độc lập cho SFTP và Logs.

### Module mới chuẩn hóa

- `app/backend/switching/`: navigation, validation và repository có transaction.
- `app/core/switch_slots.py`: QML bridge cho Switching.
- `app/UI/qml/switch/`: workspace và SubFeatureBar role-aware.
- `app/sftp_client/`: controller/model/service/worker đúng tên package.
- `app/UI/qml/sftp/`: workspace SFTP dùng theme/component chung.
- `app/log_monitor/`: parser, filter, model, SQLite repository, capture/store/
  decode worker và controller bounded.
- `app/UI/qml/logs/`: toolbar, packet table, inspector và saved sessions.
- `app/core/tool_catalog.py`: allowlist ứng dụng và vendor URL chính thức.
- `app/UI/qml/content/ExternalToolCatalogSettings.qml`: catalog read-only.

### Runtime data không version-control

- `app/logs/packet_logs.db`
- `app/logs/captures/*.pcapng`
- SQLite WAL/SHM

`app/.gitignore` dùng `/logs/` để chỉ bỏ runtime directory ở gốc `app/`, không
vô tình bỏ source `app/UI/qml/logs/`.

## Khác biệt với nhánh nguồn

So với `feature/tools-extension-nqv`, nhánh đích có ít hơn khoảng 63 file dù
có đủ Switching, SFTP, Logs và ý tưởng công cụ ngoài. Chênh lệch chủ yếu do:

- không mang 44 SVG bổ sung và kho icon file type;
- bỏ package cũ `sftpCient`, `log_core`, schema/sample runtime rời;
- dùng shared component/theme;
- gom lifecycle và persistence vào module nhỏ có test;
- không mang installer/native SSH/legacy algorithm.

## Ownership sau merge

| Thành phần | Source of truth |
|---|---|
| Theme, component, Activity Bar, Settings | `app/UI/` |
| Routing persistence | `app/backend/route/` |
| Switching desired state | `app/backend/switching/` |
| SFTP | `app/sftp_client/` |
| Device Logs | `app/log_monitor/` |
| External Tools detection/catalog | `app/core/runtime.py`, `app/core/tool_catalog.py` |
| QML/runtime regression | `app/tests/` |
