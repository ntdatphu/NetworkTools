# Đặc tả kỹ thuật các thay đổi chờ xử lý

Tài liệu này triển khai chi tiết các mục ưu tiên trong [`PENDING_CHANGES_UI_UX.md`](PENDING_CHANGES_UI_UX.md). Dòng code có thể thay đổi; file/symbol và acceptance test mới là tham chiếu ổn định.

## CORE-01 — sửa contract OSPF/EIGRP interface — DONE

**Hoàn thành ngày 2026-07-14:** repository desktop đã dùng `t04_router_iface_ospf` và `t04_router_iface_eigrp` gắn `iface_id`; không tạo bảng/view legacy.

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

**Bằng chứng:** 4/4 routing contract test và 19/19 test non-QML đạt; không còn ResourceWarning/WinError 32 trong lượt chạy. OSPF/EIGRP hiện đạt local persistence contract (L2-tested), chưa tự động đạt L3/L4 vì chưa có test push riêng cho hai protocol hoặc thiết bị thật.

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

## UX-01 — command/shortcut registry

Tạo action ở cấp Main/ContentArea, expose `enabled`, `label`, `shortcut`, `trigger()`. View active đăng ký capability Save/Reload/ViewPush/Search. Không đặt cùng global shortcut ở nhiều dialog/view.

Acceptance:

- input focus không bị shortcut destructive chiếm;
- window lock/modal chặn action phù hợp;
- `Ctrl+S` chỉ save khi form valid/dirty;
- `Ctrl+R` dùng lifecycle reload và dirty guard;
- tài liệu `SHORTCUTS.md` sinh/cập nhật từ registry.

## UX-NOTIFY-01 — copy Toast và Notification History

**Trạng thái:** DONE ngày 2026-07-14.

- `CopyButton` là component dùng chung, sao chép nguyên văn message bằng Clipboard UI thuần QML.
- Mỗi Toast có nút Copy cạnh Dismiss; thao tác copy restart auto-close timer để feedback không biến mất ngay.
- Mỗi notification-history row có nút Copy riêng.
- Tooltip đổi thành “Copied”, icon đổi sang check và trạng thái tự reset; nút hỗ trợ focus/keyboard và accessible name.
- Không copy timestamp/type/credential ngầm; chỉ copy nội dung người dùng nhìn thấy.

Acceptance: QML contract test xác minh Clipboard nhận đúng text, feedback bật và Toast/Notification Panel tải không warning.

## UX-ICON-01 — icon cho action button

**Trạng thái:** PARTIAL ngày 2026-07-14.

- Đã kiểm kê toàn bộ 110 `StandardButton` dưới `app/UI/`; 38 nút có icon binding, 72 nút không khai báo icon.
- `Reload` DB dùng `database-reload.svg`; reload running-config backup dùng `backup.svg`.
- `View & Push` và Push xác nhận cùng dùng `push.svg`; Save dùng `save.svg`.
- Add/New và button compact tương tự giữ text-only vì icon làm lặp dấu `+`, tăng chiều rộng và gây lỗi hiển thị. Nút động Add/Save hoặc Update/Save chỉ hiện icon ở trạng thái Save.
- `Get running-config` trong device context menu dùng `backup.svg` dù không thuộc mẫu `StandardButton`.
- Danh sách 72 nút không có icon binding được nhóm theo label và vị trí trong `PENDING_CHANGES_UI_UX.md`; 38 action Add/New/compact trong số đó là text-only có chủ ý.

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

## UX-03 — ConfigTextViewer

Tạo component dùng chung cho `InformationView` và Routing Config:

- TextDocument/TextArea read-only, monospace;
- search next/previous + `Ctrl+F`;
- zoom `Ctrl+wheel`, reset;
- line number/gutter selection;
- Copy All/selection;
- syntax highlighting incremental cho token mạng;
- API `text`, `sourceLabel`, `loading`, `error`, `reloadRequested`.

Không chạy regex toàn tài liệu trên mỗi keystroke/scroll. Test file lớn và theme light/dark.

## UX-04 — password và selection

### PasswordField

Wrapper từ `StandardTextField`, có `passwordVisible`, eye icon, accessible name/state, giữ cursor/focus khi toggle. Áp dụng mọi credential input, gồm PPP password.

### Selection tokens

Thêm `selectionBackground`, `selectionForeground` vào ColorTokens/Theme; kiểm tra contrast trên light/dark và custom accent. Thay mọi selection color rời rạc.

## UX-05 — Activity Bar/Console Serial/Logs/SFTP

### Giai đoạn placeholder hiện tại

1. Di chuyển Database vào bottom group ngay trên Settings, tooltip “Database”.
2. Dành kế hoạch cho ba item mới: `Console Serial`, `Logs`, `SFTP`; các asset tương ứng `console_serial.svg`, `logs.svg`, `sftp.svg` đã tồn tại.
3. Cả ba item phải hiển thị mờ giống Topology với `opacity: 0.35`, `enabled: false`, `isActive: false`; không có click handler, không đổi `activeIndex`/`appMode` và không được command registry gán shortcut.
4. Chưa bắt buộc tạo sidebar route hoặc Content Area cho ba item. Không tạo placeholder page/Loader chỉ để làm item trông như đã có tính năng.
5. Asset không được xem là implementation hoặc lý do nâng capability level.
6. Topology tiếp tục là capability coming-soon không điều hướng; ba item mới dùng cùng contract hiển thị nhưng không thể kích hoạt.
7. CLI hiện tại vẫn ghi rõ “Open OS Terminal” hoặc “Open SSH Client”, tránh gọi là console tích hợp.

### Điều kiện trước khi cho hiện/kích hoạt

- **Console Serial:** có contract list port, open/close, read/write worker, baud/parity/data/stop bits, reconnect, ownership session và log/redaction.
- **Logs:** xác định log dành cho Device nào được lưu (kết nối, sync, command, View & Push hoặc lỗi), schema/storage, timestamp/severity/source, filter theo device, rotation/retention, redaction credential và concurrency; có API đọc theo trang trước khi thiết kế view dữ liệu lớn.
- **SFTP:** xác định session ownership, host-key verification, authentication/secret handling, remote/local path policy, upload/download queue, progress/cancel/retry, overwrite confirmation và audit log.

Acceptance cho giai đoạn placeholder: QML smoke/contract test chứng minh ba item hiển thị mờ nhưng không nhận click/shortcut, không tạo loader và không làm thay đổi index hiện có của Dashboard/Database/Settings.

**Trạng thái placeholder:** DONE ngày 2026-07-14 trong `app/UI/qml/layout/ActivityBar.qml`; test cô lập đạt. Trạng thái capability Console Serial/Logs/SFTP vẫn PARTIAL vì chưa có Content Area hoặc runtime contract.

## UX-06 — Database table groups

Backend trả metadata thay vì list string:

```json
{"group_code":"04","group_name":"Routing","tables":["t04_static_routes"]}
```

Unknown/nonmatching table vào “Other”. Sidebar dùng section collapse, filter vẫn giữ group, selection không mất khi reload. Bổ sung paging/sort và redact credential columns.

## UX-07 — External Tools

- detect theo registry/PATH/known paths, có source/confidence;
- native Browse và validate executable;
- argument presets theo PuTTY/SecureCRT/Terminal/DB Browser;
- preview redacted;
- deprecate/block `{password}`;
- confirm delete và fill detail pane.

Không tự chọn executable đầu tiên làm default nếu có nhiều candidate; yêu cầu người dùng xác nhận.

## UX-08 — DHCP/NAT/ACL Info

Repository read-only phải dùng `INFO_COLLECTED_DB`, filter theo host, trả collected timestamp và collection state. Dashboard dùng F1 empty/loading/error, stale threshold, virtualized table và manual reload. Enable tab chỉ khi backend + QML + test đã có.

DHCP phase đầu tối thiểu pool/binding nhưng model phải chừa conflict/statistics. NAT phase đầu summary/translation/statistics. ACL phase đầu ACL/rules/interface bindings.

## QUALITY-01 — component/resource cleanup

- xoá `BaseCard` và `BaseButton` sau grep 0 consumer; cập nhật `qmldir`;
- generic hóa phần trùng OSPF/EIGRP theo composition, không tạo “god component”;
- sửa asset `resources/devicetabs/close.svg` bị thiếu;
- asset mới phải có consumer/test hoặc được loại khỏi change set;
- thêm script kiểm tra resource path và `qmldir` export trong CI.

## QUALITY-02 — test gate

Baseline bắt buộc trước merge:

```powershell
python -m unittest discover -s app/tests -v
```

QML fixture phải build temp DB hoặc inject fake manager, dùng offscreen, đóng mọi root window, stop timer/thread và không ghi `external_tools.db` vào workspace. Thêm test cho shortcut, reload dirty-state, resource existence, network monitor latency và routing page.

## SECURITY-01 — credential handling

- DB lưu secret reference, secret ở OS keyring/credential manager;
- migration/redaction cho password cũ;
- không trả password trong generic device/list API;
- DB browser ẩn/cấm edit secret columns mặc định;
- không đưa password vào argv, log, toast, backup metadata;
- sample/demo không chứa credential dùng được;
- policy permission/retention cho running-config backup.

Đây là quality gate trước khi gọi dự án production-ready, dù không chặn nghiên cứu local/dev-mode.
