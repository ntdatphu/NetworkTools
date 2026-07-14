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

- Đã kiểm kê toàn bộ 128 `StandardButton` dưới `app/UI/`; 43 nút có icon binding, 85 nút không khai báo icon. Nút xoá OSPF Network dùng `RemoveIconButton` chuẩn và không nằm trong mẫu số.
- `Reload` DB dùng `database-reload.svg`; reload running-config backup dùng `backup.svg`.
- `View & Push` và Push xác nhận cùng dùng `push.svg`; Save dùng `save.svg`.
- Add/New và button compact tương tự giữ text-only vì icon làm lặp dấu `+`, tăng chiều rộng và gây lỗi hiển thị. Nút động Add/Save hoặc Update/Save chỉ hiện icon ở trạng thái Save.
- Cả 26 action Cancel đã dùng `StandardButton type: "Text"`: 12 `Cancel Changes`, 13 `Cancel`/Cancel-Close View và một `Cancel Deletes`. Chúng không có nền/khung thường, dùng font weight bình thường, underline khi hover/focus và đứng trước action xác nhận trong cùng nhóm. Add YANG đã bỏ `Rectangle` tự vẽ để dùng component chuẩn.
- Mọi `StandardButton` nhận `Qt.StrongFocus`; khi Tab tạo `visualFocus`, component vẽ focus ring mảnh bằng `Theme.accentColor`.
- `Get running-config` trong device context menu dùng `backup.svg` dù không thuộc mẫu `StandardButton`.
- Danh sách 85 nút không có icon binding được nhóm theo label và vị trí trong `PENDING_CHANGES_UI_UX.md`; Add/New/compact và toàn bộ Cancel là các nhóm text-only có chủ ý.

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

**DONE ngày 2026-07-14.** `StandardPasswordField` có `passwordVisible` mặc định OFF, eye/eye-closed action, accessible name/state và giữ cursor/focus khi toggle. Đã thay toàn bộ bốn credential input hiện có: New Device, Batch, Add YANG và PPP password. Runtime smoke test kiểm tra cả hai trạng thái mask/reveal và contract test chặn quay lại `echoMode` rời rạc.

### Selection tokens

**DONE ngày 2026-07-14.** `selectionBackground`/`selectionForeground` đã được export qua ColorTokens/Theme và thay selection color rời rạc ở field, spin box, Information/Route Info, View & Push và Database Browser editor. Foreground tự chọn đen/trắng theo WCAG relative-luminance; runtime test bao phủ bốn theme mode và các custom accent tối, sáng, trung tính, vàng, xanh với contrast tối thiểu 4.5:1.

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
- **DONE 2026-07-14:** `OspfNetworksSection` dùng `RemoveIconButton`/`resources/general/close.svg`, không còn tham chiếu asset `resources/devicetabs/close.svg` bị thiếu;
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
