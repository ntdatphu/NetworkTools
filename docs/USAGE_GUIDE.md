# Hướng dẫn cài đặt và sử dụng NetworkTools

Ngày đối chiếu: **2026-07-16**.

Hướng dẫn này bao phủ toàn dự án nhưng tách rõ phần **đã có quy trình chạy tái lập** và phần **chưa chạy được từ cây hiện tại**. Không đổi tên/copy thư mục backend để né lỗi import vì điều đó che mất contract cần sửa.

## 1. Thành phần và mức sẵn sàng

| Thành phần | Cách sử dụng hiện tại |
|---|---|
| Desktop `app/` | Có `pyproject.toml`, `uv.lock`, entry point và test; đây là đường chạy tái lập được. |
| Backend `backend cua kien/` | Có worker/schema/setup script nhưng path/import/schema/dependency chưa nhất quán; chưa coi là “run after clone”. |
| `api_server.py` | Có endpoint FastAPI nhưng import package `backend` không tồn tại; chưa khởi động được nguyên trạng. |
| `mock/` | Fixture/config mẫu; không phải executable contract. |
| `latex/` | Có script build XeLaTeX/latexmk. |
| `report/` | Bộ LaTeX thứ hai, chưa có build script và nội dung còn placeholder. |

## 2. Chạy ứng dụng desktop

### Yêu cầu

- Python **>= 3.11** theo `app/pyproject.toml`;
- repository pin `.python-version` là **3.14** cho môi trường phát triển;
- `uv`;
- dependency từ `app/pyproject.toml` và `app/uv.lock`.

### Cài đặt và chạy

```powershell
cd NetworkTools\app
uv sync
uv run python main.py
```

Hoặc entry point sau khi package được cài:

```powershell
uv run networktools
```

Lần chạy đầu tạo các DB còn thiếu:

- `app/device_network.db`;
- `app/info_collected.db`.

`ExternalToolsManager` tự tạo `app/external_tools.db`. Startup không migrate DB đã tồn tại.

### Device workflow

1. Mở Devices, dùng Add hoặc `Ctrl+N`; `Ctrl+Shift+N` mở batch import.
2. Nhập host, protocol/port, credential, OS/role/type.
3. Device mới ở trạng thái Waiting/pending.
4. Dùng context menu để Ping, Connect, Reconnect, Running Config, CLI, Dev Up/Down, Edit hoặc Delete.

Connect/sync chạy nền và có thể lưu running-config vào `app/backup/<host>/`. Hỗ trợ thực tế phụ thuộc vendor/protocol/lab; không coi mọi nhánh template là đã được thử trên thiết bị thật.

Khi session hoặc màn hình feature/subtab của tab active đang được chuẩn bị, icon thiết bị trên Device Tab được thay bằng vòng tròn loading màu Accent. Icon tự trở lại khi view sẵn sàng. Có thể tiếp tục chọn feature/tab khác; các lượt tải chưa hoàn thành và không còn active sẽ bị hủy, còn view đã mở xong được cache để lần quay lại không dựng lại từ đầu.

### Dev-mode desktop

1. thêm device giả;
2. dùng **Up (Dev)** khi device đang Waiting;
3. lưu cấu hình local;
4. dùng View & Push cho Routing/DHCP.

`dev = 1` bỏ login thật nhưng vẫn chạy dispatcher/report để cập nhật pending state. Dev-mode chưa bao phủ ACL/NAT/Interface View & Push.

## 3. Tính năng desktop đã kiểm chứng

### Information và Routing Info

- Information đọc running-config từ session hoặc backup.
- Routing Info đọc `info_collected.db`/backup.
- Information và trang Routing Config dùng viewer chung: chữ mặc định 13 px, `Ctrl+F` focus ô tìm kiếm, Enter/Shift+Enter chuyển kết quả, zoom 9–40 px bằng `Ctrl+lăn chuột` hoặc `−`/`+`/`Reset`, gutter số dòng đồng bộ baseline, click gutter chọn dòng, Copy All ở header và syntax highlight theo màu ngữ nghĩa riêng. Search/Zoom nằm dưới nội dung. Information tự reload khi được kích hoạt nhưng không chạy lệnh trùng.
- `Ctrl+R` reload Information theo context; `Ctrl+1/2/3` chuyển Devices/Database/Settings. Registry chặn các command này khi modal/window lock hoặc ô nhập đang focus.
- Routing table vẫn chưa virtualized/paged; đây là PERF-02 riêng, không phải phần text viewer.

### Routing

- Static: local CRUD + View & Push.
- OSPF/EIGRP: schema canonical tồn tại nhưng repository hiện đang gọi tên bảng interface legacy; routing contract test thất bại. Không coi hai feature này là L2-tested cho tới khi backend desktop được sửa và gate chạy lại.
- BGP: disabled/not implemented trong UI desktop.

### DHCP, ACL, NAT, Interface

- DHCP Pool/Excluded/Helper: local CRUD và preview/push; validation còn thiếu.
- ACL: local CRUD; chưa có View & Push desktop/test persistence tương đương NAT.
- NAT: local persistence đã có test; chưa có View & Push desktop.
- Interface: local CRUD cho L3/Tunnel/WAN/QoS; chưa có View & Push desktop.
- DHCP/NAT Info: schema có nhưng tab disabled/placeholder; ACL Info chưa có dashboard.

### Settings và Database

- Theme/Status Bar dùng `QSettings`.
- External Tools có CRUD, nhận diện ứng dụng Windows, native Browse/validation và command preview redacted.
- Database Browser giới hạn 500 row, chưa paging/grouping và chưa redact credential.

#### External Tools

1. Mở **Settings → External Tools**. Danh sách bên trái tách cấu hình đã lưu và ứng dụng được Windows phát hiện; có thể Search hoặc lọc SSH/Terminal/Database.
2. Chọn một candidate để kiểm tra đường dẫn, nguồn nhận diện, độ tin cậy và association mặc định liên quan. Candidate không được lưu tự động; nhấn **Add Tool** sau khi đã xác nhận.
   Candidate chưa cấu hình được hiển thị bằng màu xám/trung tính để phân biệt với ứng dụng đã lưu.
3. Dùng **Browse** để chọn `.exe`, `.com`, `.bat` hoặc `.cmd` thủ công. Đường dẫn không tồn tại hoặc sai loại file sẽ chặn Save.
4. Arguments hỗ trợ `{ip}`, `{username}` cho SSH và `{db}` cho DB Browser. Command preview dùng dữ liệu minh họa, không hiển thị credential thật.
5. `{password}` bị chặn ở cả Save và launch. Dùng xác thực tương tác hoặc key/agent của ứng dụng ngoài thay vì password trên command line.
6. **Windows defaults** chỉ mở trang Default Apps của Windows; NetworkTools không tự đổi registry/default application. Nếu phát hiện nhiều bản cài, chọn đúng executable trước khi lưu.
7. SSH client được nhận diện sẵn gồm PuTTY, Xshell, MobaXterm, Tera Term và SecureCRT. Với Xshell, template mặc định là `-url ssh://{ip}`; vẫn nên kiểm tra preview trước khi Add Tool.

## 4. Backend dự án: điều kiện phải sửa trước khi chạy

`backend cua kien/` là backend thật của dự án. Tuy nhiên không nên đưa lệnh khởi động như thể nó đã sẵn sàng, vì các lỗi sau đã được xác nhận tĩnh:

1. `api_server.py` và module sync import `backend.PyCode...`, trong khi không có thư mục/package `backend/`;
2. config hard-code `<project>/backend`, không phải `<project>/backend cua kien`;
3. config yêu cầu `.env` nhưng repository không cung cấp mẫu `.env.example`;
4. `DB_TABLES` dùng 42 tên prefix `tNN_`, trong khi `backend cua kien/sql` chứa 0 tên tương ứng;
5. `build_db.py` đọc `backend cua kien/main.sql`, nhưng file thật là `backend cua kien/sql/main.sql`;
6. setup script tìm `script/check_packages_imports.py`, nhưng checker nằm ngay ở gốc backend;
7. `packages.txt` thiếu ít nhất `python-dotenv`; API còn cần `fastapi` và `uvicorn`.

### Contract môi trường cần chuẩn hóa

Nên tạo một entry point/package hợp lệ và một manifest khóa phiên bản. Cấu hình tối thiểu cần mô tả rõ:

```dotenv
# Ví dụ contract; chưa phải file được phép tự tạo trong đợt tài liệu này.
DB_RELATIVE_PATH=...
BACKEND_TMP_DIR=...
BACKUP_DIR=...
```

Sau khi sửa code, quality gate backend tối thiểu phải chứng minh:

```text
import package thành công
→ tạo DB fixture từ schema authority
→ dispatcher đọc đúng bảng
→ fake worker nhận payload
→ trạng thái task/pending cập nhật đúng
→ API trả task ID và status thật
```

Không dùng thao tác rename/copy thủ công `backend cua kien` thành `backend` như một bước cài đặt chính thức; package/path phải được sửa trong code và test.

## 5. API server

Endpoint hiện được khai báo cho DHCP, sync, Interface, OSPF, EIGRP, Static, ACL và NAT. Sau khi package/dependency/config/schema được sửa, điểm chạy dự kiến là:

```powershell
uvicorn api_server:app --host 127.0.0.1 --port 8000
```

Lệnh trên là **mục tiêu sau tích hợp**, không phải hướng dẫn đã xác nhận cho commit hiện tại. API chưa có auth, request model đầy đủ, task status/cancel hoặc error propagation; không expose ra mạng ngoài localhost trước khi có security gate.

## 6. Fixture trong `mock/`

Payload mẫu có nhiều dạng contract và giai đoạn thử nghiệm khác nhau. Khi dùng:

- chọn đúng family/vendor/protocol;
- validate JSON/schema trước khi đưa vào dispatcher;
- thay credential/IP lab bằng placeholder;
- không suy ra capability DONE chỉ vì có fixture;
- không chạy `mock/nqv/build_sql.*` cho tới khi bổ sung đúng `schema/` và `info_collected/` mà script yêu cầu.

## 7. Build báo cáo

README gốc chỉ định `latex/` là pipeline báo cáo chuẩn:

```powershell
cd NetworkTools\latex
.\build.ps1
```

Dọn file trung gian:

```powershell
.\build.ps1 -Clean
```

Yêu cầu `latexmk` và XeLaTeX (TeX Live/MiKTeX). Nhiều chương hiện còn khung nội dung; trước khi xuất bản cần đồng bộ số bảng, trạng thái feature, test và kiến trúc từ `docs/`.

`report/` là nguồn LaTeX thứ hai, chưa phải pipeline được README gốc chọn. Nếu tiếp tục dùng, phải xác định rõ đây là bìa/phần nào của deliverable để tránh hai báo cáo mâu thuẫn.

## 8. Kiểm thử desktop

Từ `app/`:

```powershell
python -m unittest discover -s tests -v
```

Baseline ngày 2026-07-16: gate `tests.test_ui_contracts` + `tests.test_qml_smoke` đạt 57/57 trong chế độ offscreen; 15/15 test mục tiêu External Tools và tổng 82/82 test ngoài routing đạt. Feature Bar CLI và `Ctrl+Alt+T` mở SSH Client đang bật cho tab device active. Gate toàn bộ còn fail 2 routing contract test vì `app/backend/route/` truy vấn tên bảng interface legacy; lượt QML cũng còn cảnh báo connection SQLite từ fixture/manager ngoài External Tools. Xem [CODE_AUDIT.md](CODE_AUDIT.md).

## 9. Vận hành an toàn

- Backup DB/running-config trước khi rebuild hoặc push.
- Xác minh host và `dev` trước View & Push.
- Không truyền password qua command-line placeholder.
- Không dùng DB Browser để xem/sửa credential trong demo công khai.
- Không tắt TLS/host-key verification trong môi trường ngoài lab.
- AI-generated config phải được validate/preview theo thiết bị; không push hàng loạt chỉ dựa vào JSON parse thành công.
- Packet capture/Telnet credential tools chỉ dùng trong lab có ủy quyền.

Backlog UI/UX desktop: [beta/PENDING_CHANGES_UI_UX.md](beta/PENDING_CHANGES_UI_UX.md). Kiến trúc toàn dự án: [ARCHITECTURE.md](ARCHITECTURE.md).
