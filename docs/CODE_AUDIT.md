# Kiểm chứng mã nguồn và chất lượng toàn dự án

Ngày kiểm chứng ban đầu: **2026-07-14**. Trạng thái UI/QML được đồng bộ lại ngày **2026-07-16**.

## 1. Phạm vi và mức kiểm chứng

### `app/` — rà soát đầy đủ

Toàn bộ file dưới `app/` được đọc/kiểm tra, chỉ loại trừ `app/uv.lock`. Worktree smart merge hiện có 382 file version-control/non-ignored: 104 Python, 165 QML, 50 SVG và 18 file test. Đã thực hiện parse/compile Python, đọc QML/JS/SQL/Jinja/TOML/SVG/config, kiểm tra resource, build schema trong SQLite và chạy test.

### Phần còn lại của dự án — rà soát tích hợp chỉ đọc

Đã kiểm kê toàn bộ file cấp dự án và đọc code/script/schema/manifest/LaTeX/fixture cần thiết trong:

- `backend cua kien/`;
- `api_server.py`;
- `mock/`;
- `latex/`, `report/`;
- các file gốc `README.md`, `app_summary.txt`, `search_report.txt`, `frontend.code-workspace`, `.gitignore`.

Đợt audit ban đầu đối chiếu import, path, entry point, table name, dependency, consumer và vai trò kiến trúc; không chạy worker lên thiết bị thật hoặc build môi trường backend. Lượt triển khai kế hoạch sau đó đã sửa CORE-01 trong `app/backend/route` và test tương ứng; không sửa `backend cua kien/` hay thành phần ngoài `app/`/`docs/`. Fixture JSON lớn được kiểm kê/đối chiếu theo family và contract, không được coi là test thực thi.

## 2. Kết quả kiểm thử desktop

| Nhóm | Kết quả kiểm chứng |
|---|---|
| Routing database contract | 2/2 đạt: OSPF/EIGRP dùng bảng canonical, round-trip/repeat không duplicate và connection cleanup đúng. |
| NAT persistence | 6/6 đạt. |
| Dev-mode worker/dispatcher | 5/5 đạt; worker fail-closed khi không xác minh được `dev`. |
| DHCP/ACL persistence | 6/6 đạt. |
| External Tools/Tool Catalog | Đạt; gồm default association, Xshell/Installed Applications registry, Feature Bar CLI, password block, HTTPS allowlist và không gọi installer. |
| Switching/SFTP/Device Logs | Đạt backend contract + QML smoke; có transaction/role guard, host-key policy, worker lifecycle, batching/limit/retention. |
| UI contract + QML smoke | Đạt trong chế độ offscreen, không QML warning; gồm loader lifecycle, Notification, ConfigTextViewer, External Tools, Tool Catalog, SFTP, Logs, Feature Bar CLI và Main module. |
| Full suite | **118/118 đạt** ngày 2026-07-17; gồm regression cho họ table/Switch workspace, DHCP/NAT và routing network tables; `compileall`, `uv lock --check` và `git diff --check` đạt. |
| QML `UI/Main` smoke | `test_main_module_loads` đạt trong gate hiện tại; không còn là blocker riêng. |
| Schema desktop | 72 bảng cấu hình + 18 bảng collected; integrity/foreign-key check trên DB mới đạt. |

Chưa có test suite ở cấp repository cho `api_server.py`/`backend cua kien/`. Vì contract import hiện lỗi ngay từ cấu trúc đường dẫn, không ghi nhận backend/API là integration-tested.

## 3. P0 — lỗi correctness/tích hợp

### INTEG-01 — backend dự án bị gọi bằng package không tồn tại

`backend cua kien/` là backend của dự án, nhưng:

- `api_server.py` import `backend.PyCode...`;
- `PyCode/sync/*` cũng import `backend.PyCode...`;
- config hard-code `<project>/backend`;
- repository không có thư mục `backend/`.

Kết quả: API/backend không có đường import thống nhất từ cây hiện tại. Đây là lỗi tích hợp, không phải lý do loại backend khỏi kiến trúc dự án.

### INTEG-02 — schema backend và map table lệch hoàn toàn

`backend cua kien/sql/*.sql` tạo 74 bảng không prefix. `DB_TABLES` map 42 tên `tNN_*`; **0/42** tên đó tồn tại trong schema backend. 40 tên gần tương ứng nằm ở schema desktop, còn hai tên OSPF/EIGRP interface là legacy và cũng không có trong schema desktop canonical.

Dispatcher có thể mở nhầm DB, tạo DB rỗng hoặc fail `no such table`. Cần chọn schema authority và integration test trước khi push thiết bị.

### INTEG-03 — builder/setup backend trỏ sai

- `backend cua kien/build_db.py` đọc `backend cua kien/main.sql`, nhưng file thật nằm ở `backend cua kien/sql/main.sql`;
- script xóa DB cũ trước khi biết SQL input có đọc được không;
- thông báo “27 bảng” không khớp 74 bảng;
- setup script tìm `script/check_packages_imports.py`, trong khi checker ở gốc backend;
- `mock/nqv/build_sql.*` yêu cầu hai thư mục nguồn không tồn tại.

Không tài liệu hóa các script này như đường build đã hoạt động.

### INTEG-04 — dependency/entry point chưa tái lập

`packages.txt` có thư viện mạng/template nhưng thiếu `python-dotenv`; `api_server.py` còn cần `fastapi` và `uvicorn`. Không có lockfile/pyproject backend hoặc entry point package chuẩn. Setup script dùng package không pin chặt phiên bản, nên môi trường khó tái lập.

### APP-CORE-01 — OSPF/EIGRP desktop — đã khắc phục

Repository đã dùng `t04_router_iface_ospf/eigrp`, join/resolve `iface_id`, archive
child row trên bảng chuẩn và đóng connection đúng. Routing contract 2/2 đạt.

### APP-CORE-02 — validation chưa end-to-end

`StandardNetworkField` chỉ normalize shorthand; nhiều form/repository chỉ kiểm tra khác rỗng/trim. IPv4, mask, wildcard, range và quan hệ subnet chưa được backend validate nhất quán.

## 4. P1 — bảo mật, hiệu năng và độ tin cậy

### Toàn dự án

1. **Credential plaintext:** desktop và backend đọc/lưu password trực tiếp trong SQLite/inventory; fixture/AI dataset có password mẫu; backup có thể chứa secret.
2. **Transport verification bị tắt:** nhiều RESTCONF request dùng `verify=False`; NETCONF dùng `hostkey_verify=False`.
3. **API chưa có security contract:** không auth/authorization, typed request đầy đủ, rate limit, idempotency, task status/cancel hoặc audit trail. Response success hiện không phản ánh kết quả push.
4. **Đường dẫn và file output phụ thuộc CWD:** report/Tmp/topology/sniffer dùng relative path; `format_md.py` hard-code `e:/NetworkTools/backend/...`; chạy song song có thể ghi đè.
5. **Timeout không nhất quán:** nhiều `requests.*` trong worker không đặt timeout, có thể treo tác vụ.
6. **AI push rủi ro cao:** output model chỉ được regex/JSON parse rồi có thể push đồng thời tới 15 thiết bị; chưa có command policy, per-device diff/approval hoặc rollback.
7. **Packet/Telnet tools nhạy cảm:** packet capture và clear-text credential extraction phải có scope lab/ủy quyền, privilege và retention rõ ràng.
8. **Hai nguồn báo cáo:** `latex/` và `report/` có thể lệch nội dung; `report/` còn placeholder, `latex/` cũng có nhiều khung chưa điền.

### Desktop `app/`

1. `NetworkMonitor._refresh()` chạy trên UI thread mỗi 3 giây và có subprocess timeout 2 giây.
2. Routing Info fetch toàn bộ, copy `allRoutes → visibleRoutes`, dùng `Repeater` cho mọi row.
3. Loader feature/subtab đã chuyển sang incubation bất đồng bộ, hủy lượt Loading không còn active, coalesce feature/host switch, chỉ reload view/subtab active và có Device Tab spinner; view Ready vẫn cache. Chưa có memory budget, dirty-aware eviction hoặc benchmark startup/peak RAM trên bản chạy thật; reload/invalidation/dirty-state policy toàn cục vẫn thiếu.
4. Password vẫn có thể lộ qua DB Browser và các đường dữ liệu khác. Riêng External Tools đã block `{password}` ở Save/launch, preview redacted và không còn đọc password để tạo argv.

### Backend `backend cua kien/`

1. Dispatcher dùng nhiều `fetchall()`/payload toàn khối; chưa pagination/backpressure.
2. FastAPI `BackgroundTasks` không phải durable queue; restart làm mất trạng thái tác vụ.
3. File report/output cố định dễ race/overwrite khi nhiều request chạy.
4. Topology quét tuần tự, dùng list `pop(0)` và network probe blocking.
5. Login xóa device khỏi DB khi probe fail, có thể biến lỗi mạng tạm thời thành mất dữ liệu.
6. `interface/main.py` có hai khối `if __name__ == "__main__"`, khiến dispatcher được gọi hai lần khi chạy script trực tiếp.

## 5. P2 — UX, thẩm mỹ và bảo trì desktop

1. ~~Information chưa search/zoom/line number/copy-all/syntax highlight~~ — đã hoàn tất ngày 2026-07-14 bằng `ConfigTextViewer` dùng chung với Routing Config, có highlighter theo chunk/fallback file lớn và activation reload coalesce.
2. Copy chỉ nằm trong Notification History qua `CopyButton`; toast nổi không có Copy. Notification Center đã có chiều cao động, toolbar SVG-only, severity color cố định và DND/unread contract với QML test.
3. Command registry mới đạt PARTIAL: đã sở hữu `Ctrl+R` cho Information và `Ctrl+1/2/3` cho Devices/Database/Settings, có window-lock/input-focus guard; `Ctrl+S`, feature navigation, View & Push và dirty capability còn thiếu.
4. ~~Theme chưa có token selection foreground/background dùng thống nhất~~ — đã có `selectionBackground`/`selectionForeground`, runtime test contrast tối thiểu 4.5:1 qua theme và custom accent.
5. ~~Password field chưa có eye toggle dùng chung; PPP password chưa password mode~~ — đã thay bằng `StandardPasswordField` tại bốn credential input và có mask/reveal runtime test.
6. Database nằm ngay trên Settings. Console Serial vẫn mờ/disabled giống Topology; Logs và SFTP đã có workspace độc lập. Logs có SQLite session, batching, safety limit và retention; SFTP có host-key confirmation, queue/progress/cancel và serialized worker.
7. Database tables chưa grouping/paging/redaction.
8. ~~External Tools chưa auto-detect/Browse/preset/preview~~ — đã có master-detail responsive và Tool Catalog read-only. App thiếu hiển thị xám; catalog chỉ mở vendor URL, không cài hoặc đổi Windows defaults. Còn visual regression theme/DPI/accessibility đầy đủ và tách component lớn.
9. DHCP/NAT Info disabled/placeholder; ACL Info chưa có dashboard.
10. ~~`BaseCard` gần trùng `ProcessCard`, `BaseButton` không có consumer~~ — đã loại khỏi filesystem và `qmldir` ngày 2026-07-14; contract test khóa `ProcessCard` là export F4 duy nhất.
11. ~~`OspfNetworksSection.qml` tham chiếu icon close không tồn tại~~ — đã sửa ngày 2026-07-14 bằng `RemoveIconButton`/`resources/general/close.svg`; một số SVG mới vẫn chưa có consumer.
12. Split pane cần chuẩn hóa theo family/breakpoint, không ép một kích thước cho mọi màn hình.

Chi tiết acceptance criteria nằm trong [beta/CHANGES_PENDING.md](beta/CHANGES_PENDING.md).

## 6. Trạng thái capability toàn dự án

| Capability | Mức có thể khẳng định |
|---|---|
| Desktop shell/device CRUD/settings | Có code runtime; test một phần. |
| Desktop Static/DHCP dev View & Push | Có test dispatcher/worker dev-mode. |
| Desktop OSPF/EIGRP | Canonical local persistence contract đạt; L2-tested. |
| Desktop Switching | SW2/SW3 desired-state local có transaction/role guard; chưa push thiết bị. |
| Desktop SFTP | Workspace và safety contract đạt; chưa chứng minh transfer với lab server thật. |
| Desktop Device Logs | Capture/inspect/session bounded có test; chưa chứng minh driver/traffic lab thật. |
| Desktop ACL/NAT/Interface | Local CRUD ở các mức khác nhau; thiếu View & Push hoàn chỉnh. |
| Backend Routing/Interface/DHCP/NAT/ACL | Có dispatcher, worker và template; chưa import/schema/integration-tested trong cây hiện tại. |
| Backend Login/Sync/Save | Có code cho nhiều protocol; chưa có test/lab evidence trong repository. |
| Backend L2/Topology/Security | Có implementation riêng lẻ; chưa nối API/desktop và chưa có quality gate. |
| AI Config | Có dataset generator/Ollama client/console push; cần security/validation gate trước sử dụng. |
| FastAPI | Có route declarations; chưa khởi động được nguyên trạng và chưa production-ready. |
| Mock fixtures | Có nhiều payload/config mẫu; không phải bằng chứng capability. |
| Báo cáo | Có hai cây LaTeX; `latex/` là pipeline được README chỉ định, nội dung còn phải cập nhật. |

## 7. Ưu tiên khắc phục

1. Chốt package/path của backend mà không làm mất nhãn vai trò `cua kien`.
2. Chốt schema authority, migration/version và sửa `DB_TABLES`.
3. Sửa builder/setup/dependency; tạo backend/API smoke test không cần thiết bị thật.
4. Thêm API task model, auth, timeout, error/status và fake-device integration test.
5. Tiếp tục validation end-to-end; CORE-01 OSPF/EIGRP desktop đã hoàn thành.
6. Xử lý secret/TLS/backup/payload AI trước khi mở rộng push thật.
7. Thực hiện các mục performance/UI trong `beta/PENDING_CHANGES_UI_UX.md`.
8. Đồng bộ `latex/`/`report/` với bằng chứng test trước khi công bố.

## 8. Sai lệch còn nằm trong file ngoài phạm vi chỉnh sửa

Các file sau thuộc dự án nhưng không được sửa trong đợt này:

- `README.md` ghi Python 3.10+ trong khi `app/pyproject.toml` yêu cầu >=3.11, và chưa phân biệt `app/backend/` với `backend cua kien/`;
- `frontend.code-workspace` chỉ mở `app/` và `docs/`, dễ làm người đọc nhầm đó là toàn project;
- `.gitignore` còn pattern `backend/PyCode/AI_Config/`, không khớp tên thư mục backend thật;
- `latex/appendix/appendix_a_huong_dan_cai_dat.tex` dùng ví dụ `uv run main.py` thay vì quy trình desktop đã kiểm chứng, còn nhiều chương báo cáo là nội dung khung;
- `report/` là nguồn báo cáo thứ hai nhưng chưa có chỉ dẫn quan hệ/phát hành so với `latex/`.

Các sai lệch này được ghi nhận ở đây để không bị “sửa ngầm” bằng cách mô tả sai trong `docs/`.

## 9. Quy tắc cập nhật tài liệu

- “Có schema”, “có fixture”, “có template”, “có UI”, “local CRUD đã test”, “dev-mode đã test”, “API gọi được” và “push thật đã kiểm chứng” là các mức độc lập.
- Một thư mục là thành phần dự án dù chưa được tiến trình desktop import trực tiếp.
- `app/backend/` và `backend cua kien/` phải luôn được gọi đúng vai trò để tránh nhầm lẫn.
- Claim backend/API phải có smoke/integration test; claim thiết bị thật phải có môi trường và bằng chứng lab.
- Tài liệu UI beta cố ý chỉ theo dõi `app/`; kiến trúc và audit cấp dự án nằm ở tài liệu này và [ARCHITECTURE.md](ARCHITECTURE.md).
