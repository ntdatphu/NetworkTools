# Đặc tả kỹ thuật các thay đổi chờ xử lý

Tài liệu này triển khai chi tiết các mục ưu tiên trong [`PENDING_CHANGES_UI_UX.md`](PENDING_CHANGES_UI_UX.md). Dòng code có thể thay đổi; file/symbol và acceptance test mới là tham chiếu ổn định.

## CORE-01 — sửa contract OSPF/EIGRP interface — DONE

**Đối chiếu ngày 2026-07-16:** repository đã dùng `t04_router_iface_ospf` và `t04_router_iface_eigrp`, resolve `iface_id`, join lại `interface_name`, lưu OSPF priority/auth key và đóng connection đúng.

**Phạm vi desktop (`app/`):**

- `app/backend/route/ospf/{load,process_compare,process_store}.py`;
- `app/backend/route/eigrp/{load,child_sync,child_writers,process_store}.py`;
- mapping trong `app/network_code/PyCode/share/config.py` làm chuẩn tham khảo;
- test `test_database_routing_contract.py`.

**Đã thực hiện:**

1. Resolve `(host, interface_name)` sang `t02_interface_name.iface_id`; lỗi nếu interface không tồn tại.
2. Insert/update theo `(ospf_id|eigrp_id, iface_id)` và JOIN để load lại `interface_name`.
3. Không tạo bảng legacy/compatibility view.
4. Mọi connection/transaction phải đóng cả khi SQL fail.
5. Bổ sung test update, soft delete, unknown interface và rollback.
6. Lưu/đọc đầy đủ trường canonical OSPF `priority` và `auth_key`.
7. Sửa luôn cột passive-interface OSPF cũ đang làm toàn bộ loader thất bại.

**Bằng chứng hiện tại:** `tests.test_database_routing_contract` đạt 2/2; full suite đạt 118/118 và temp DB cleanup không còn WinError 32.

## CORE-02 — validation end-to-end

**Phạm vi desktop:** `StandardNetworkField`, `ValidationUtils.js`, toàn bộ DHCP/NAT/ACL/Interface/Static/OSPF/EIGRP form và repository tương ứng trong `app/`.

**Contract:**

- component chỉ giới hạn ký tự/normalize;
- form validate semantic và chỉ stage khi hợp lệ;
- Python validate lại bằng `ipaddress`/parser typed trước transaction;
- error trả `{ok, message, severity, field}` thay vì bool khi có thể.

**Ca tối thiểu:** IPv4 octet, leading zero policy, contiguous subnet mask, wildcard, prefix 0–32, network/gateway cùng subnet, start <= end, port 1–65535, AS/process/AD range, interface/ACL name.

**Đạt khi:** invalid input không vào DB kể cả gọi slot trực tiếp; test có valid/invalid boundary.

## PERF-01 — NetworkMonitor không chặn UI

**Hiện trạng:** `QTimer` 3 giây gọi `_refresh()` trên main thread; Wi-Fi probe có subprocess timeout 2 giây.

**Thiết kế:**

- worker thread thực hiện psutil/socket/SSID probe;
- chỉ một probe đang chạy; tick mới bị coalesce;
- cache interface/SSID, refresh SSID khi interface đổi hoặc TTL hết;
- emit result immutable về main thread;
- shutdown worker khi app thoát.

**Đạt khi:** p95 main-thread callback < 16 ms trong probe timeout; không tạo process chồng; test fake slow command không làm event loop đứng.

## PERF-02 — Routing Info virtualized/paged

**Hiện trạng:** `getRoutingInfo()` fetch all, QML giữ hai ListModel và `Repeater` dựng mọi row.

**API đề xuất:**

```text
getRoutingInfoPage(host, filters, offset, limit)
→ {ok, rows, total, facets, collected_at}
```

Query filter protocol/VRF/search ở SQL, có deterministic `ORDER BY`, index phù hợp. QML dùng `ListView`, debounce search và không copy toàn dataset.

**Đạt khi:** 10.000 route vẫn scroll/search responsive, số delegate gần viewport, peak RAM và thời gian load có baseline.

## PERF-03 — asynchronous view lifecycle và Device Tab loader — PARTIAL

**Lát cắt triển khai ngày 2026-07-16:**

- `ContentArea.activeViewLoading` tổng hợp trạng thái 8 loader cấp màn hình, loader con của view active và `InformationView.isViewLoading`;
- Main bind trạng thái này vào `DeviceTabs.activeContentLoading`; role chỉ được gắn cho tab active. `DeviceTabItem` dùng `LoadingSpinner` thay icon device đúng cùng kích thước/vị trí, đồng thời hiển thị spinner khi `sessionState === "opening"`;
- `LoadingSpinner` dùng một Canvas vòng cung và chỉ animate phép quay; không repaint mỗi frame, dừng hẳn khi không running;
- loader cấp ContentArea và loader lồng Routing/DHCP/NAT/ACL dùng incubation bất đồng bộ. Loader đã Ready được giữ để bảo toàn state, loader vẫn Loading nhưng không còn active được cancel;
- `activeViewLoadTimer` coalesce nhiều feature selection trong một event-loop turn; `hostApplyTimer` 16 ms coalesce host cuối và nhường một frame để tab/icon phản hồi trước các QML handler đọc DB đồng bộ. Host chỉ truyền xuống outer view và subtab đang active; view cache đang ẩn không query lại;
- ACL không còn dựng đồng thời Rules và Bindings ngay lần mở đầu; hai màn hình được lazy-load riêng rồi cache;
- Information đưa cả command live và syntax highlighter theo chunk vào loading contract.

**Bằng chứng:** runtime test xác nhận spinner thay icon/khôi phục icon, rapid Routing → ACL → DHCP chỉ dựng DHCP, mọi outer/nested loader hoàn thành, Main module tải sạch. Full suite hiện đạt 118/118.

**Còn lại để hoàn tất PERF-03:** đo startup/first-open/peak RAM trên bản chạy thật; đặt memory budget và dirty-aware eviction. Thay đổi này không giải quyết thay PERF-01 NetworkMonitor blocking hoặc PERF-02 Routing Info toàn khối.

## UX-01 — command/shortcut registry

Tạo action ở cấp Main/ContentArea, expose `enabled`, `label`, `shortcut`, `trigger()`. View active đăng ký capability Save/Reload/ViewPush/Search. Không đặt cùng global shortcut ở nhiều dialog/view.

**Trạng thái PARTIAL ngày 2026-07-16:**

- `CommandRegistry.qml` đã là owner duy nhất của `Ctrl+R`, `Ctrl+1`, `Ctrl+2`, `Ctrl+3`, có label/shortcut/enabled/trigger và callback theo context;
- Main chặn command khi `UiState.windowLock` hoặc `TextInput`/`TextEdit` đang focus;
- `ContentArea.reloadCommandEnabled`/`triggerReloadCommand()` hiện hỗ trợ Information read-only: có host, đúng view active, không có command đang chạy;
- Activity Bar expose Devices/Database/Settings activation; Database command chỉ enabled khi external-tools backend khả dụng;
- đã sửa id loader bị gắn nhầm: `dhcpLoader` chứa `DhcpView`, `informationLoader` chứa `InformationView`; contract/runtime test xác minh dispatch `reloadData("shortcut", true)` tới đúng view.

Chưa đăng ký `Ctrl+S`, `Ctrl+Shift+P` hoặc feature navigation. Các command này chỉ được thêm sau khi mỗi view có capability contract `dirty/valid/save/viewPush/requestLeave`, tránh mất staged data hoặc kích hoạt nhầm form khi input đang focus.

Acceptance:

- input focus không bị shortcut destructive chiếm;
- window lock/modal chặn action phù hợp;
- `Ctrl+S` chỉ save khi form valid/dirty;
- `Ctrl+R` dùng lifecycle reload và dirty guard;
- tài liệu `SHORTCUTS.md` sinh/cập nhật từ registry.

## UX-NOTIFY-01 — copy Notification History

**Trạng thái:** DONE ngày 2026-07-14.

- `CopyButton` là component dùng chung, sao chép nguyên văn message bằng Clipboard UI thuần QML.
- Toast nổi không có Copy; đây là bề mặt đọc nhanh và Dismiss.
- Mỗi notification-history row trong Notification Center có nút Copy riêng.
- Tooltip đổi thành “Copied”, icon đổi sang check và trạng thái tự reset; nút hỗ trợ focus/keyboard và accessible name.
- Không copy timestamp/type/credential ngầm; chỉ copy nội dung người dùng nhìn thấy.

Acceptance: QML contract test xác minh Clipboard nhận đúng text, Toast không tạo `toastCopyButton`, và Notification Center tải không warning.

## UX-NOTIFY-02 — Notification Center, severity color và DND

**Trạng thái:** DONE ngày 2026-07-14.

- `StatusIcon` dùng notification severity token cố định, tách khỏi user accent: info xanh dương, success xanh lá, warning vàng, error đỏ; mỗi loại có background riêng cho light/dark/high-contrast.
- Center dùng chiều cao động: khi rỗng chỉ còn toolbar 44 px; có item thì tăng theo `ListView.contentHeight`, trần 400 px và cuộn khi vượt trần.
- Khi rỗng, header đổi thành `No New Notifications`; không render body/empty-message riêng bên dưới.
- Header dùng ba `StandardButton` type Icon, không có text: DND, Clear All, Hide. Asset lần lượt là `dnd.svg`/`bell.svg`, `clear.svg`, `chevron-down.svg`; icon-only content được neo chính giữa.
- DND không dùng trạng thái `checked`/`selected`, vì trạng thái này kéo màu user accent vào button; icon giữ màu neutral ở cả ON/OFF.
- DND mặc định OFF và ở phạm vi phiên. OFF hiển thị `dnd.svg` trong Center để biểu đạt action bật; ON hiển thị `bell.svg` để biểu đạt action tắt.
- Khi DND ON, notification vẫn được insert vào history/unread nhưng toast bị chặn. Status Bar chuyển sang `dnd.svg`, nhấp nháy khi unread và dừng khi Center được mở.
- Icon Notification trên Status Bar là toggle rõ ràng: click khi đóng thì mở, click lại khi đang mở thì đóng. Popup không còn auto-close trên outside press trước handler; vẫn đóng bằng toggle, chevron hoặc Escape.
- Mở Notification Center dọn toàn bộ toast đang nổi và vô hiệu uid task toast đã bị dọn; notification mới khi Center còn mở chỉ vào history, không tạo popup chồng bên dưới.
- Toast cùng nội dung đang hiện hoặc lặp lại liên tiếp trong 3 giây bị suppress ở lớp popup; mỗi sự kiện vẫn được insert riêng vào Notification History. Task toast được loại trừ vì được cập nhật theo uid.
- `DevicesPanel` không gọi `ToastManager` trực tiếp; toàn bộ notification đi qua Main để DND và history có hiệu lực nhất quán.

Acceptance: QML smoke test kiểm tra chiều cao rỗng/tối đa, toggle DND/Center, dọn toast khi mở, suppress popup trùng nhưng giữ history, không có Copy trong toast và icon/blink Status Bar; source contract test khóa asset, color token và toàn bộ luồng notification.

## UX-ICON-01 — icon cho action button

**Trạng thái:** PARTIAL ngày 2026-07-14.

- Đã kiểm kê toàn bộ 170 `StandardButton` dưới `app/UI/`; 52 nút có icon binding, 118 nút không khai báo icon. Switching đã dùng `SubBar` chung thay cho hàng button tự dựng. Bảy nút mới ở Logs/Tool Catalog giữ text-only do chưa có asset chuyên biệt đúng nghĩa. `ConfigTextViewer` có hai nút điều hướng chevron và ba điều khiển zoom text/glyph; hai consumer có Copy All dùng `clipboard-copy.svg`. Nút xoá OSPF Network dùng `RemoveIconButton` chuẩn và không nằm trong mẫu số.
- `Reload` DB dùng `database-reload.svg`; reload running-config backup dùng `backup.svg`.
- `View & Push` và Push xác nhận cùng dùng `push.svg`; Save dùng `save.svg`.
- Add/New và button compact tương tự giữ text-only vì icon làm lặp dấu `+`, tăng chiều rộng và gây lỗi hiển thị. Nút động Add/Save hoặc Update/Save chỉ hiện icon ở trạng thái Save.
- Cả 31 action Cancel đã dùng `StandardButton type: "Text"`: 13 `Cancel Changes` và 18 biến thể `Cancel`/Cancel-Close View/Cancel Deletes. Chúng không có nền/khung thường, dùng font weight bình thường, underline khi hover/focus và đứng trước action xác nhận trong cùng nhóm. Add YANG đã bỏ `Rectangle` tự vẽ để dùng component chuẩn.
- Mọi `StandardButton` nhận `Qt.StrongFocus`; khi Tab tạo `visualFocus`, component vẽ focus ring mảnh bằng `Theme.accentColor`.
- `Get running-config` trong device context menu dùng `backup.svg` dù không thuộc mẫu `StandardButton`.
- Danh sách 118 nút không có icon binding được nhóm theo label và vị trí trong `PENDING_CHANGES_UI_UX.md`; Add/New/compact, Logs/Tool Catalog utility và toàn bộ Cancel là các nhóm text-only có chủ ý.

Acceptance còn lại:

- thêm asset riêng cho discard/cancel/clear/apply/import/sample/reset thay vì tái dùng icon gần nghĩa; không tự động áp dụng asset mới lên button compact;
- quyết định segmented navigation và dynamic family selector có giữ text-only hay không;
- visual test icon+text ở light/dark, disabled/loading, label dài và DPI scale;
- contract test phải cập nhật cùng inventory khi thêm hoặc xoá `StandardButton`.

## UX-02 — reload activation và dirty guard

Mỗi feature/subview expose `reloadData(reason)`, `hasDirtyState` và `requestLeave()`. Khi activate:

- clean → reload active data;
- dirty + nguồn không đổi → giữ form;
- dirty + backend invalidated → banner Reload/Keep/Compare;
- task đang chạy → không start trùng.

Phát invalidation sau save/sync/push thay vì reload tất cả loader con.

## UX-03 — ConfigTextViewer — DONE

Đã tạo component dùng chung cho `InformationView` và Routing Config ngày 2026-07-14:

- TextArea read-only, monospace, selection token dùng chung;
- toolbar Search/Zoom nằm dưới nội dung; search debounce 180 ms, giới hạn 10.000 match, `Ctrl+F` focus ô nhập, Enter/Shift+Enter điều hướng và match count. Enter đồng bộ kết quả nếu debounce chưa chạy và không chuyển focus khỏi ô search;
- zoom `Ctrl+wheel` bắt trực tiếp trên TextArea, mặc định 13 px theo token nội dung chuẩn, giới hạn 9–40 px và có ba nút `−`, `+`, `Reset`;
- gutter số dòng dùng một `TextArea` read-only đồng bộ font, rich/plain-text mode, padding và vị trí cuộn với `TextArea` nội dung; cách này bỏ khác biệt baseline giữa delegate `Text` và rich text, không tái tạo delegate hay đo layout bất đồng bộ khi zoom; click gutter vẫn chọn dòng, còn bánh xe chuột, touchpad, thanh cuộn và reveal kết quả tìm kiếm đều khóa theo nguyên dòng;
- Copy All dùng `StandardButton` Secondary ở header, cùng hàng/kiểu với Reload và có feedback “Copied”; selection dùng copy chuẩn của TextArea;
- syntax highlighting tự khởi động khi text/theme đổi, có 13 token màu riêng cho IP, prefix, mask, wildcard, interface, number, boolean/up/down, date-time, permit, deny, inside, outside và comment; token có chữ được in đậm; palette light/dark/high-contrast export qua Theme, xử lý theo chunk 250 dòng và không chạy regex khi scroll;
- nội dung trên 1.000.000 ký tự tự fallback về plain text nhằm chặn tăng CPU/RAM không kiểm soát;
- API trạng thái `text`, `sourceLabel`, `loading`, `errorText`, `emptyText`.

Information reload khi activation qua `ContentArea`; cửa sổ coalesce 250 ms loại request trùng cùng host, command đang chạy không bị start lần hai, còn đổi host trong lúc task chạy xếp đúng một reload sau khi task cũ kết thúc. Contract/runtime test xác minh hai consumer dùng component chung, search/zoom/line selection trên rich text, palette light/dark, fallback file lớn, benchmark 10.000 dòng và activation lifecycle; module không có warning.

## UX-04 — password và selection

### PasswordField

**DONE ngày 2026-07-14.** `StandardPasswordField` có `passwordVisible` mặc định OFF, eye/eye-closed action, accessible name/state và giữ cursor/focus khi toggle. Đã thay toàn bộ bốn credential input hiện có: New Device, Batch, Add YANG và PPP password. Runtime smoke test kiểm tra cả hai trạng thái mask/reveal và contract test chặn quay lại `echoMode` rời rạc.

### Selection tokens

**DONE ngày 2026-07-14.** `selectionBackground`/`selectionForeground` đã được export qua ColorTokens/Theme và thay selection color rời rạc ở field, spin box, Information/Route Info, View & Push và Database Browser editor. Foreground tự chọn đen/trắng theo WCAG relative-luminance; runtime test bao phủ bốn theme mode và các custom accent tối, sáng, trung tính, vàng, xanh với contrast tối thiểu 4.5:1.

## UX-05 — Activity Bar/Console Serial/Logs/SFTP

### Trạng thái hiện tại

1. Di chuyển Database vào bottom group ngay trên Settings, tooltip “Database”.
2. `Logs` và `SFTP` đã có workspace độc lập, active index/mode và runtime contract; không còn là placeholder.
3. `Console Serial` tiếp tục hiển thị mờ giống Topology với `opacity: 0.35`, `enabled: false`, `isActive: false`.
4. Asset không được xem là implementation hoặc lý do nâng capability level.
5. CLI hiện tại mở SSH Client do người dùng cấu hình, không phải console tích hợp.

### Điều kiện trước khi cho hiện/kích hoạt

- **Console Serial:** có contract list port, open/close, read/write worker, baud/parity/data/stop bits, reconnect, ownership session và log/redaction.
- **Logs:** đã có packet-summary session theo device, SQLite, display filter, batching, safety limit và retention. Còn lab benchmark với traffic thật, privilege/driver matrix và redaction payload sâu hơn.
- **SFTP:** đã có host-key verification, in-memory authentication options, remote/local path policy, queue, progress/cancel và delete guard. Còn integration server test/retry/overwrite policy hoàn chỉnh.

Acceptance hiện tại: QML smoke chứng minh Console Serial inert, Logs/SFTP active và hai workspace tải không warning.

**Trạng thái:** Console Serial PARTIAL placeholder; Logs và SFTP IMPLEMENTED/PARTIAL QA.

## UX-06 — Database table groups

Backend trả metadata thay vì list string:

```json
{"group_code":"04","group_name":"Routing","tables":["t04_static_routes"]}
```

Unknown/nonmatching table vào “Other”. Sidebar dùng section collapse, filter vẫn giữ group, selection không mất khi reload. Bổ sung paging/sort và redact credential columns.

## UX-07 — External Tools

**Trạng thái ngày 2026-07-16:** IMPLEMENTED/PARTIAL QA. `ExternalToolsSettings.qml` đã chuyển sang master-detail responsive: pane trái search/filter + Configured/Detected, pane phải có Basic/Executable/Launch preview và Arguments progressive disclosure; chiều rộng dưới 920 px xếp dọc. New/Detected/Configured/Dirty/Error có trạng thái riêng; Delete confirm; detected candidate không tự lưu.

`ExternalToolsManager` nhận diện bounded theo Windows App Paths, PATH/App Execution Alias, Installed Applications/`InstallLocation`, association người dùng cho SSH/SQLite, default terminal và known install locations. Catalog SSH hiện gồm PuTTY, Xshell, MobaXterm, Tera Term và SecureCRT; Xshell dùng `-url ssh://{ip}`, MobaXterm dùng `-newtab "ssh {ip}"`, Tera Term dùng `{ip} /ssh /2`. Candidate được deduplicate, gắn `source`, `confidence`, `defaultFor`, `isAmbiguous`, `alreadyConfigured`; không quét toàn ổ và không sửa registry. UI có native Browse, inline executable validation, preset `{ip}`/`{username}`/`{db}`, command preview redacted và lối mở `ms-settings:defaultapps` để quyền chọn default vẫn thuộc người dùng.

`{password}` bị từ chối khi Save và trước khi tạo process cho cấu hình legacy; bridge không còn đọc password để build argv. Mọi binding text dùng `safeText()` để tránh `.trim()` trên giá trị chưa khởi tạo; runtime smoke phát trực tiếp signal `activated` của Tool type. 8 manager test + 1 QML smoke + 6 source-contract test đạt (15/15), gồm mapping GUID chính thức, Xshell, Installed Applications registry và Feature Bar CLI mở Xshell cho IP của active device. Candidate chưa cấu hình đã được giảm tương phản bằng token xám; render review bố cục 1200×760/800×760 và danh sách Detected đạt. Còn lại: regression ảnh tự động light/dark/high-contrast, DPI matrix, focus traversal/screen-reader audit đầy đủ và tách component để giảm kích thước file.

## UX-08 — DHCP/NAT/ACL Info

Repository read-only phải dùng `INFO_COLLECTED_DB`, filter theo host, trả collected timestamp và collection state. Dashboard dùng F1 empty/loading/error, stale threshold, virtualized table và manual reload. Enable tab chỉ khi backend + QML + test đã có.

DHCP phase đầu tối thiểu pool/binding nhưng model phải chừa conflict/statistics. NAT phase đầu summary/translation/statistics. ACL phase đầu ACL/rules/interface bindings.

## QUALITY-01 — component/resource cleanup

- **DONE 2026-07-14:** xóa `BaseCard` và `BaseButton` sau grep 0 consumer, cập nhật `qmldir`; contract test xác nhận file/export/consumer legacy không quay lại;
- generic hóa phần trùng OSPF/EIGRP theo composition, không tạo “god component”;
- **DONE 2026-07-14:** `OspfNetworksSection` dùng `RemoveIconButton`/`resources/general/close.svg`, không còn tham chiếu asset `resources/devicetabs/close.svg` bị thiếu;
- asset mới phải có consumer/test hoặc được loại khỏi change set;
- thêm script kiểm tra resource path và `qmldir` export trong CI.

## QUALITY-02 — test gate

Baseline bắt buộc trước merge:

```powershell
python -m unittest discover -s app/tests -v
```

**Trạng thái ngày 2026-07-17:** full discovery đạt **118/118**. Routing canonical, Switching/table family (gồm DHCP/NAT và OSPF/EIGRP Networks), SFTP, Device Logs, Tool Catalog, External Tools, UI contract và QML smoke đều xanh; `compileall`, `uv lock --check` và `git diff --check` đạt. Chưa có đủ test cho reload dirty-state, visual/DPI regression, NetworkMonitor latency, Routing paging, SFTP server thật và TShark driver/traffic thật.

## SECURITY-01 — credential handling

- DB lưu secret reference, secret ở OS keyring/credential manager;
- migration/redaction cho password cũ;
- không trả password trong generic device/list API;
- DB browser ẩn/cấm edit secret columns mặc định;
- không đưa password vào argv, log, toast, backup metadata;
- sample/demo không chứa credential dùng được;
- policy permission/retention cho running-config backup.

Đây là quality gate trước khi gọi dự án production-ready, dù không chặn nghiên cứu local/dev-mode.
