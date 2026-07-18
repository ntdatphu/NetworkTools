# Rà soát lỗi và file bị bỏ sót sau smart merge

Ngày rà soát: **2026-07-18**. Nhánh đích: `frontend/merges`. Baseline đối chiếu
là `origin/merge-v-p`; các nguồn feature được kiểm kê gồm
`feature/tools-extension-nqv`, `origin/feature/tools-extension-nqv`,
`origin/sftp`, `origin/nqv-acl`, `origin/nqv-nat` và hợp asset của toàn bộ remote
branch hiện có.

Mục tiêu của lượt này không phải chạy `git merge` nguyên khối. File có giá trị
được phục hồi; implementation trùng tên hoặc trái safety contract được đối chiếu
và giữ lại phiên bản đã tái cấu trúc trên nhánh đích.

## 1. Lỗi đã xác minh và khắc phục

| ID | Mức | Nguyên nhân sau merge | Kết quả |
|---|---|---|---|
| PM-DB-01 | P0 | Startup thấy thiếu `.db` đã build từ `schema/*.sql` rồi ghi đè luôn `database/device_network.sql`. Modular L2 schema lại cũ hơn aggregate nên SVI mất constraint/unique và thiếu `t06_switch_l3_config`; hai dòng `Built missing ...` là dấu vết của đường chạy này. | Commit `b82c691` tách startup initialization khỏi sinh aggregate, bỏ output gây hiểu nhầm, đồng bộ L2 schema. Regression test khóa aggregate = modular source, startup không sửa tracked SQL và không ghi đè DB hiện có. |
| PM-ASSET-01 | P1 | Smart merge nhận code SFTP nhưng bỏ toàn bộ bundle icon của nhánh nguồn; một số asset từ các nhánh khác cũng biến mất dù consumer mới có thể đã thay thế chúng. | Phục hồi 44 SVG SFTP + 2 README giấy phép và 5 image asset còn thiếu. Ngày 2026-07-18, toàn bộ được kiểm kê lại: 12 SVG SFTP chuyên biệt vào resource active, 32 SVG chưa dùng vào `_unused/sftp/`, license vào `resources/licenses/`. |
| PM-SFTP-01 | P1 | Backend hiện tại vẫn phát `logMessage` nhưng `SftpLogPanel.qml` của nhánh nguồn không được chuyển sang, làm mất Session Log. | Xây lại `SftpLogPanel` theo component/theme hiện tại, export trong `qmldir`, nối vào workspace và giới hạn 500 sự kiện để không tăng RAM vô hạn như ListModel nguồn. |
| PM-SFTP-02 | P2 | SFTP UI dùng glyph hoặc icon chung dù nhánh nguồn đã có icon đúng ngữ nghĩa. | Connect/Disconnect, Back/Refresh, Rename/Delete, Upload/Download, queue/log và file/folder/file-type dùng property ngữ nghĩa của `AppAssets`; icon cùng chức năng được dùng chung toàn app. Add/New tiếp tục text-only theo UX contract. |
| PM-QML-01 | P1 | Không có gate tổng quát bắt đường dẫn asset literal hoặc entry `qmldir` trỏ tới file đã bị bỏ trong merge. | SVG path được gom vào `AppAssets.qml`; contract xác nhận 59 asset active tồn tại, không có active SVG mồ côi và consumer không chứa literal path. |
| PM-SCHEMA-01 | P1 | Test Switching chỉ build DB mới từ aggregate nên không chứng minh DB của `merge-v-p` cũ nâng cấp an toàn. | Thêm fixture schema cũ; xác nhận compatibility shim tạo L3 table/unique index mà giữ nguyên SVI. |
| PM-PERF-01 | P1 | Benchmark ConfigTextViewer 10.000 dòng đạt khi chạy riêng nhưng vượt ngưỡng 8 giây khi chạy sau toàn suite (8,72 s và 8,18 s), cho thấy hot path còn quá sát biên. | Không nới ngưỡng. Thêm fast path HTML escape, cache regex token, lowercase mỗi dòng một lần và tránh nhận diện IPv4 lặp. Full suite 128/128 đạt trong 15,49 s. |

## 2. File được phục hồi

### SFTP

- bundle nguồn gồm 44 SVG; hiện 12 file chuyên biệt active nằm trong `app/UI/resources/actions/` và `files/`;
- 32 SVG chưa có consumer nằm trong `app/UI/resources/_unused/sftp/` để duyệt xóa;
- `app/UI/resources/licenses/LUCIDE.txt`: nguồn Lucide Icons, MIT;
- `app/UI/resources/licenses/VSCODE-ICONS.txt`: nguồn vscode-icons, MIT;
- `app/UI/qml/sftp/SftpLogPanel.qml`: được xây lại thay vì chép nguyên ListModel
  không giới hạn từ source branch.

### Asset từ các nhánh còn lại

- `app/UI/resources/_unused/legacy/activitybar/devices.svg`;
- `app/UI/resources/_unused/legacy/activitybar/logs-alerts.svg`;
- `app/UI/resources/_unused/legacy/devicetabs/close.svg`;
- `app/UI/resources/_unused/legacy/icons/database.svg`;
- `app/UI/resources/_unused/legacy/statusbar/bell-slash.svg`.

Năm file này được giữ trong khu vực cách ly để không làm mất asset lịch sử.
Consumer hiện tại không được phép tham chiếu `_unused/`.

## 3. File source-only không chép mù quáng

| Nhóm nguồn | Quyết định |
|---|---|
| `backend/sftpCient/`, `UI/qml/sftpCientQml/` | Không tạo bản runtime thứ hai. API hiện tại ở `sftp_client/` đã bao phủ source, thêm exact host-key policy, path/delete guard và serialized worker. Phần thiếu thật là Log Panel đã được xây lại. |
| `backend/log_core/`, `UI/qml/logQml/`, `database/log_schema/` | Không nhân đôi. `log_monitor/` + `UI/qml/logs/` hiện đã có capture/filter/details/bytes/saved sessions, batching, retention và DB riêng có giới hạn. |
| `core/external_tool_installer.py`, `DownloadExternalToolsSettings.qml` | Tiếp tục loại khỏi runtime: tự download/install tạo thay đổi hệ thống ngoài contract và trái allowlist/read-only Tool Catalog. |
| `components/base/BaseButton.qml`, `BaseCard.qml` | Không phục hồi vào module vì đã có `StandardButton` và component family mới; đưa lại sẽ tái tạo hai design system. |
| `switch/components/FormSection.qml` | Không phục hồi vì inspector hiện dùng `SwitchInspectorSection`/`SwitchInspectorPane`; bản cũ là duplicate gây card lồng card. |
| `captures/.gitkeep` | Không dùng: runtime hiện nằm ở ignored `app/logs/captures/` và tự tạo thư mục khi cần. |

“Không chép” ở bảng trên không đồng nghĩa bỏ tính năng. Đây là các implementation
trùng hoặc vi phạm contract; tính năng tương ứng đã được ánh xạ sang code hiện tại
và được test. Nếu cần lưu nguyên văn source note, lịch sử vẫn tồn tại trên branch
nguồn; tài liệu chuẩn phải nằm trong `docs/` để tránh người dùng nhầm là runtime.

## 4. Gate mới

- modular SQL phải giống tuyệt đối aggregate tracked SQL;
- startup chỉ build `.db` còn thiếu, không sửa aggregate, không ghi đè DB hiện có
  và không in thông báo thành công như lỗi;
- 44 SVG SFTP và hai file license phải còn tồn tại;
- các asset SFTP chính phải được consumer hiện tại sử dụng;
- mọi literal `AppAssets.resource` và mọi QML export phải resolve tới file thật;
- fixture database Switch trước merge phải nâng cấp không mất dữ liệu;
- SFTP Session Log phải có giới hạn 500 entry.
- benchmark highlight 10.000 dòng tiếp tục giữ ngưỡng dưới 8 giây trong full suite.

## 5. Giới hạn còn lại

- Chưa có integration test với SFTP server thật; safety/model/QML contract đã có.
- Asset union được đối chiếu với các branch đang tồn tại ở local/remote refs tại
  thời điểm audit; branch chưa fetch hoặc file untracked của cộng tác viên không
  thể được suy ra từ Git.
- `backend cua kien/` và API cấp dự án không thuộc các commit feature desktop vừa
  rà soát và vẫn có các blocker package/schema riêng trong `CODE_AUDIT.md`.

## 6. Kết quả kiểm chứng cuối

- full suite offscreen: **128/128 đạt**, 15,49 giây;
- QML smoke: không warning, gồm Main, SFTP, Logs, Switch và mọi data workspace;
- Python `compileall`: đạt;
- `uv lock --check`: đạt, 56 package;
- runtime `device_network.db`/`info_collected.db`: `integrity_check = ok`, không
  có foreign-key error; Switch L3 table và SVI unique index tồn tại;
- hợp image asset trên các local/remote branch đang có: **0 file còn thiếu**;
- `git diff --check`, trailing whitespace và conflict-marker scan: đạt.
