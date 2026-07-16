# Thay đổi chờ xử lý — UI/UX, hiệu năng và thẩm mỹ

Ngày kiểm chứng: **2026-07-16**. Đây là backlog UI/UX của ứng dụng desktop, nên trạng thái được đối chiếu trực tiếp với toàn bộ `app/`; không đánh dấu hoàn thành dựa trên tài liệu cũ. Backend dự án `backend cua kien/`, API, mock và báo cáo vẫn thuộc NetworkTools nhưng được đánh giá ở [`../ARCHITECTURE.md`](../ARCHITECTURE.md) và [`../CODE_AUDIT.md`](../CODE_AUDIT.md), không bị loại khỏi phạm vi dự án chỉ vì không nằm trong backlog UI này.

Ký hiệu: **DONE** đã có trong code; **PARTIAL** có một phần nhưng chưa đạt yêu cầu; **TODO** chưa có; **BLOCKED** phụ thuộc lỗi correctness khác.

## P0 — correctness trước UX

| ID | Trạng thái | Yêu cầu |
|---|---|---|
| CORE-01 | DONE | OSPF/EIGRP đã dùng `t04_router_iface_ospf/eigrp`, resolve `iface_id`, round-trip priority/auth key và đóng connection đúng; 2/2 routing contract đạt. |
| CORE-02 | PARTIAL | Validation form: `ValidationUtils` và normalize shorthand đã có, nhưng DHCP/NAT/Interface không validate semantic đầy đủ và backend chưa chặn dữ liệu mạng sai. |
| CORE-03 | TODO | Chuẩn hóa structured result cho mọi write slot; nhiều slot vẫn trả bool nên UI chỉ có thông báo lỗi chung. |
| CORE-04 | TODO | Dirty-state guard trước reload, đổi host, đổi feature hoặc đóng tab để không mất staged changes. |

## P1 — hiệu năng và responsiveness

| ID | Trạng thái | Yêu cầu/tiêu chí |
|---|---|---|
| PERF-01 | TODO | Chuyển `NetworkMonitor._refresh()` khỏi UI thread; không được gọi lệnh OS đồng bộ mỗi 3 giây trên main thread. Cache SSID và đo latency. |
| PERF-02 | TODO | Routing Info dùng query filter/page và `ListView`; bỏ `allRoutes → visibleRoutes` copy + `Repeater` toàn bộ row. Test với ít nhất 10.000 route. |
| PERF-03 | PARTIAL | Feature/subtab nặng đã dùng asynchronous Loader, cache view đã Ready, hủy incubation không còn active, coalesce chuyển host và hiển thị loader tại icon Device Tab. Còn memory policy/unload view không dirty, giới hạn cache và đo startup/peak RAM. |
| PERF-04 | TODO | Reload activation phải coalesce/debounce và không query lại tất cả subtab; chỉ reload feature/tab đang active hoặc dữ liệu được invalidated. |
| PERF-05 | TODO | Database Browser bổ sung paging/row count/sort; limit 500 hiện tại không có offset hay thứ tự ổn định. |
| PERF-06 | TODO | Tách `SettingsView.qml`, `AclForm.qml`, OSPF/EIGRP form lớn thành section/component có ownership rõ để giảm binding và chi phí bảo trì. |

## P1 — core UI/UX

| ID | Trạng thái | Yêu cầu |
|---|---|---|
| UX-01 | PARTIAL | `CommandRegistry` đã sở hữu `Ctrl+R` cho Information và `Ctrl+1/2/3` cho Devices/Database/Settings, chặn khi window lock hoặc ô nhập focus. Còn `Ctrl+S`, View & Push, feature navigation và dirty capability theo từng form. |
| UX-02 | DONE | `CopyButton` chỉ xuất hiện trong từng item của Notification Center; toast nổi không có Copy. History copy có tooltip/feedback “Copied”, focus bàn phím và QML contract test. |
| UX-03 | DONE | `StandardPasswordField` mặc định che password, eye toggle giữ cursor/focus và có accessible metadata; đã áp dụng New Device, Batch, Add YANG và PPP password. |
| UX-04 | DONE | `Theme.selectionBackground/Foreground` đã dùng thống nhất ở field/spin/editor; foreground được chọn theo WCAG relative-luminance và runtime test đạt tối thiểu 4.5:1 trên light/dark/high-contrast với custom accent. |
| UX-05 | TODO | Feature activation reload: view expose `reloadData(reason)`. Nếu form dirty thì không ghi đè; hiển thị stale-data banner/confirm. |
| UX-06 | PARTIAL | Reconnect đã có; đóng tab đã đóng session. Cần test close-without-session, task đang chạy và reopen không reconnect. |
| UX-07 | DONE | Sidebar section rỗng được ẩn; Connected/Waiting auto-expand; Disconnected không auto-expand. |
| UX-08 | DONE | Settings navigator có Theme, External Tools và Tool Catalog; không còn General/Advanced placeholder. |
| UX-09 | PARTIAL | Icon cho action button: chỉ gắn khi có asset chuyên biệt đúng nghĩa. Add/New, Cancel, Logs controls và Tool Catalog utility giữ text-only để tránh lỗi bố cục hoặc dùng icon gần nghĩa. Hiện 119/171 `StandardButton` không khai báo icon, được kiểm kê ở mục P2. |
| UX-10 | DONE | Notification Center có chiều cao động 44–400 px, toolbar SVG-only căn giữa, màu severity/DND không phụ thuộc accent, DND mặc định OFF chặn toast nhưng vẫn lưu history, và Status Bar nhấp nháy `dnd.svg` khi có unread. |

### Command registry — PARTIAL ngày 2026-07-16

- [x] Component registry cấp Main export label/shortcut/enabled/trigger và giữ một nơi sở hữu `Ctrl+R`, `Ctrl+1`, `Ctrl+2`, `Ctrl+3`;
- [x] `Ctrl+R` chỉ enabled khi Information đang active, có host và không chạy reload; dispatch tới đúng `InformationView` với reason `shortcut`;
- [x] Navigation Devices/Database/Settings bị chặn khi `UiState.windowLock` hoặc `TextInput`/`TextEdit` đang focus; Database còn phụ thuộc external-tools backend;
- [x] Sửa mapping `ContentArea`: DHCP dùng `dhcpLoader`, Information dùng `informationLoader`; runtime test khóa đúng component và activation reload;
- [ ] Chưa đăng ký `Ctrl+S`/View & Push hoặc feature navigation cho tới khi view expose capability `dirty`, `valid`, `save`, `viewPush` và leave guard nhất quán.

### Device Tab loader và responsiveness — lát cắt DONE ngày 2026-07-16

- [x] `DeviceTabItem` thay icon thiết bị bằng vòng cung xoay màu Accent ngay cùng vị trí khi session đang mở hoặc Content Area của tab active chưa sẵn sàng; animation chỉ chạy khi `running`, Canvas chỉ vẽ lại khi size/màu/stroke đổi;
- [x] 8 loader cấp `ContentArea` và 17 loader lồng trong Routing/DHCP/NAT/ACL dùng `asynchronous: true`; view đã Ready vẫn được cache để không dựng lại và giữ local form state;
- [x] Chuyển feature liên tiếp trong cùng event-loop turn được coalesce; loader còn `Loading` nhưng đã mất active bị hủy, tránh nhiều form lớn cùng incubation/tranh CPU;
- [x] Chuyển Device Tab áp dụng host sau một frame 16 ms và chỉ áp dụng host cuối cho view/subtab active; view đã cache nhưng đang ẩn không còn query lại, giúp selection/icon render trước rồi mới kích hoạt reload DB cần thiết;
- [x] Trạng thái loading xuyên từ loader ngoài → loader subtab → Information command/highlighter → `DeviceTabs.activeContentLoading`; hoàn tất hoặc hủy đều trả lại icon thiết bị;
- [x] Runtime test khóa việc spinner thay icon đúng lúc, chuyển nhanh chỉ dựng feature cuối và toàn bộ Main/feature loader không có QML warning;
- [ ] PERF-03 vẫn PARTIAL ở cấp tổng thể: cần benchmark startup/first-open/peak RAM bằng bản build thật, memory budget và dirty-aware eviction; PERF-01 NetworkMonitor cùng PERF-02 Routing paging vẫn là các nguồn main-thread load độc lập.

## P1 — Information/Observe view

**DONE ngày 2026-07-14.** `InformationView` và Routing Config cùng dùng `ConfigTextViewer`:

- [x] Search nằm dưới nội dung; `Ctrl+F` focus/chọn nội dung ô nhập, Enter/Shift+Enter đi tới kết quả sau/trước và có match count. Enter buộc hoàn tất search đang debounce trước khi điều hướng và focus được giữ ở ô nhập qua nhiều lần nhấn;
- [x] Zoom nằm dưới nội dung; `Ctrl + wheel` hoạt động trực tiếp trên vùng text, mặc định 13 px như nội dung chuẩn của ứng dụng, giới hạn 9–40 px và có ba nút `−`, `+`, `Reset`;
- [x] gutter số dòng dùng một `TextArea` read-only có cùng font, rich/plain-text mode, padding và vị trí cuộn với nội dung; không trộn delegate `Text` với rich `TextArea`, không tạo lại delegate hay đo layout bất đồng bộ khi zoom; giữ đúng dòng trống cuối tệp, click gutter chọn dòng và mọi thao tác cuộn dọc được khóa theo nguyên dòng;
- [x] Copy All là `StandardButton` Secondary có `clipboard-copy.svg`, nằm cùng hàng và cùng kiểu với Reload ở Information; Routing Config đặt cùng header. Nút đổi nhãn “Copied” để feedback; selection vẫn copy bằng hành vi chuẩn của TextArea;
- [x] syntax highlighting tự khởi động khi text/theme đổi, dùng màu riêng cho IP, prefix, mask, wildcard, interface, number, yes/no/up/down, date-time, permit, deny, inside, outside và comment; token có chữ được in đậm, palette có biến thể light/dark/high-contrast và không phụ thuộc accent;
- [x] highlighter xử lý từng chunk 250 dòng, không chạy lại khi scroll; benchmark runtime 10.000 dòng đạt, search debounce 180 ms/giới hạn 10.000 kết quả và gutter chỉ dùng một text document thay vì hàng nghìn delegate. Nội dung trên 1.000.000 ký tự tự dùng plain text để giới hạn CPU/RAM;
- [x] reload khi Information được kích hoạt; request cùng host trong 250 ms hoặc khi command đang chạy được coalesce, đổi host giữa task chỉ xếp đúng một reload kế tiếp;
- [x] empty/loading/error state dùng chung trong viewer cho hai bề mặt cấu hình.

Component được export qua `UI/qmldir`; contract/runtime test khóa việc cả hai consumer không quay lại `TextArea` riêng lẻ, kiểm tra rich-text selection/search, light/dark palette, fallback file lớn, benchmark 10.000 dòng và lifecycle reload không chạy trùng.

## P1 — Notification Center và DND

Contract đã triển khai:

- toast nổi chỉ có nội dung, severity icon và nút Dismiss; Copy chỉ nằm trong từng history item của Notification Center;
- notification dùng bảng màu hệ thống cố định: Information xanh dương, Success xanh lá, Warning vàng và Error đỏ; custom accent/status-bar color không được đổi màu severity;
- Center cao tối đa 400 px; khi rỗng chỉ còn toolbar 44 px với nhãn `No New Notifications`, không có body trống; khi có dữ liệu, header là `Notifications`, chiều cao tăng vừa nội dung rồi chuyển sang cuộn;
- toolbar chỉ dùng SVG và icon được neo chính giữa button: DND (`dnd.svg` khi OFF, `bell.svg` khi ON), Clear All (`statusbar/clear.svg`) và Hide (`general/chevron-down.svg`); DND không dùng checked/selected accent nên không chuyển đỏ theo màu người dùng;
- DND là trạng thái phiên, mặc định OFF. Khi ON, notification mới vẫn vào history nhưng không tạo toast; bật DND cũng dọn task toast đang chạy để không để lại loading toast bị treo;
- khi DND ON, Status Bar dùng `dnd.svg`; icon nhấp nháy nếu có unread và dừng ngay khi mở Center. Notification mới tiếp theo sau khi đóng Center sẽ kích hoạt unread/blink lại;
- icon Notification trên Status Bar toggle Center theo trạng thái hiện tại; Center không auto-close trước click handler, vẫn đóng qua chính icon, chevron hoặc Escape;
- mở Center dọn toast đang nổi; trong lúc Center mở, notification mới chỉ vào history. Toast trùng nội dung đang hiện hoặc lặp liên tiếp trong 3 giây không tạo popup mới nhưng vẫn được lưu thành từng history event;
- mọi đường thông báo UI, kể cả Device/CLI External Tool, phải đi qua `statusBar.showMessage()`/`recordNotification()`, không gọi trực tiếp `ToastManager`.

Acceptance đã đạt: `test_notification_center_copy_layout_and_dnd_controls`, `test_main_notification_toggle_clears_and_deduplicates_toasts`, `test_status_bar_dnd_indicator_blinks_only_for_unread` và các `NotificationUxContractTests`.

## P1 — Activity Bar và CLI

| Mục | Trạng thái | Ghi chú |
|---|---|---|
| Console Serial item | PARTIAL | Placeholder đã hiển thị mờ giống Topology với `console_serial.svg`, `enabled: false`, không click/index/mode/Content Area; QML contract test đạt. Runtime port/session vẫn TODO. |
| Logs item | IMPLEMENTED/PARTIAL QA | Workspace đã active; TShark probe/capture/decode ngoài UI thread, batching, 1 giờ/256 MiB/250.000 packet, model 5.000 row và retention 20 session. Còn lab test với driver/traffic thật và redaction policy sâu hơn. |
| SFTP item | IMPLEMENTED/PARTIAL QA | Workspace đã active; host-key SHA-256, local/remote browse, queue/progress/cancel và serialized worker có test. Còn integration test với SFTP server thật. |
| Database placement/name | DONE | Database đã được chuyển vào bottom group ngay trên Settings, tooltip đổi thành “Database”; index/mode cũ được giữ nguyên. |
| CLI feature | PARTIAL | Feature Bar CLI, `Ctrl+Alt+T` và Device context menu đều mở device tương ứng bằng SSH Client đang bật trong External Tools. Chưa có terminal tích hợp. |
| Topology | TODO | Item disabled/coming soon. Không hiển thị như capability sẵn có. |

Quy ước placeholder hiện chỉ áp dụng cho `Console Serial`:

- icon tồn tại không đồng nghĩa capability đã triển khai;
- hiển thị với `opacity: 0.35`, `enabled: false`, `isActive: false` và không có `onClicked` gọi `handleItemClick()`, giống trạng thái coming-soon của Topology;
- không cấp `activeIndex`, `appMode`, sidebar route, Content Area loader hoặc shortcut khi còn disabled;
- chỉ chuyển sang visible/interactive khi contract port/session/lifecycle/error/security và test tương ứng đã được duyệt.

Activity Bar contract được kiểm chứng bởi `test_activity_bar_console_is_reserved_and_logs_sftp_are_active`.

## P1 — Database Browser

- [ ] Parser tên bảng `^t(\d{2})_(.+)$`, map nhóm 01 Core, 02 Interface, 03 DHCP, 04 Routing, 05 Security/NAT, 06 L2, 07 VRF.
- [ ] Tree/collapse UI giống DeviceSection; ẩn nhóm rỗng, giữ selection/filter.
- [ ] Đổi table row từ danh sách phẳng sang item có tên hiển thị + tên SQL phụ.
- [ ] Search giữ context group; hỗ trợ search cột.
- [ ] Paging/sort/row count và cảnh báo giới hạn 500.
- [ ] Bảo vệ cột nhạy cảm hoặc redact password; không cho edit tùy tiện credential.
- [ ] Xác nhận trước edit, hiển thị kiểu dữ liệu/NULL và transaction error rõ ràng.

## P1 — External Tools

**Lát cắt implementation DONE ngày 2026-07-16; quality follow-up còn PARTIAL.** External Tools đã chuyển sang master-detail responsive và được render review ở 1200×760/800×760. Discovery chỉ đọc nguồn Windows liên quan, không quét toàn ổ và không tự lưu/chọn candidate:

- [x] Kiểm kê task flow tạo/chọn/chỉnh sửa/bật-tắt/validate/preview/xóa; danh sách có search, filter All/SSH/Terminal/Database, section Configured/Detected, enabled/default/source state và empty state;
- [x] Master-detail dùng `SplitView`, tự xếp dọc dưới breakpoint 920 px; detail chia Basic information, Executable và Launch preview/Arguments progressive disclosure;
- [x] Header/editor biểu đạt New/Detected/Configured/Dirty/Saved/Error; Delete tách khỏi Save, có confirm; detected candidate được review rồi mới cho `Add Tool` và không tự ghi DB;
- [x] Auto-detect PuTTY, Xshell, MobaXterm, Tera Term, SecureCRT, Windows Terminal, PowerShell, Command Prompt, DB Browser for SQLite và SQLiteStudio qua App Paths, PATH/App Execution Alias, Installed Applications registry, default association và known install locations; mỗi candidate có source/confidence/default-for, candidate trùng được gộp;
- [x] Native `FileDialog`, validate `.exe/.com/.bat/.cmd`, helper message theo field và command preview với `{ip}`/`{username}`/`{db}`;
- [x] `{password}` bị block ở cả Save và launch legacy; preview chỉ hiện `[BLOCKED]`, không đọc password để tạo argv;
- [x] Có nút mở Windows Default Apps để người dùng tự quản lý association; NetworkTools không ghi registry/default app;
- [x] External Tools và Tool Catalog có test cho Xshell App Paths, Installed Applications registry, Feature Bar CLI, HTTPS allowlist, không gọi installer và QML load.
- [x] Candidate Detected chưa cấu hình dùng màu chữ/icon/badge trung tính `textSecondary/textDisabled`, chỉ dùng Accent cho focus/selection để giảm cạnh tranh thị giác.
- [x] Tool Catalog hiển thị Configured/Installed/Not installed; app thiếu dùng `textDisabled`/opacity thấp, chỉ mở vendor URL sau click và không chạy `winget`.

Còn lại: visual regression tự động cho light/dark/high-contrast, nhiều DPI và focus traversal đầy đủ; cân nhắc tách file QML lớn thành component con sau khi interaction contract ổn định.

## P2 — DHCP/NAT/ACL dashboards

- [ ] DHCP Info từ `t09_info_dhcp_pool`, binding, conflict, statistics và database; không chỉ hai bảng đầu.
- [ ] NAT Info từ t11: summary, pools, static/dynamic, active translations, statistics, collection state.
- [ ] ACL Info từ t10: ACL/rule/interface binding và collection state.
- [ ] Mỗi dashboard có collected timestamp, stale indicator, empty/error/loading, filter và virtualized table.
- [ ] Chỉ enable tab khi backend read path tồn tại và có test; không để disabled tab trỏ placeholder lâu dài.

## P2 — consistency và thẩm mỹ

- [x] `StandardSpinBox` đã dùng left padding 12 như TextField.
- [x] Phần lớn action button dùng `StandardButton`; 52/171 instance có icon binding. Nút xoá OSPF Network dùng `RemoveIconButton` chuẩn.
- [x] Gắn consumer đúng nghĩa cho `backup.svg`, `database-reload.svg`, `push.svg`, `save.svg`; cả View & Push và Push xác nhận đều dùng `push.svg`.
- [x] Cả 31 action Cancel dùng Text style, đứng trước action xác nhận cùng hàng: không box/icon, font weight bình thường và underline khi hover/focus. Bao gồm 13 `Cancel Changes` và 18 biến thể `Cancel`/Cancel-Close View/Cancel Deletes; `StandardButton` có focus ring Accent khi Tab.
- [ ] Thêm visual regression test cho icon+text alignment, trạng thái disabled, theme light/dark và nút có label dài.
- [ ] Chuẩn hóa split width theo family/breakpoint, không ép Interface/ACL về 320 px nếu content không phù hợp.
- [x] Xoá `BaseCard` duplicate và `BaseButton` không consumer; cập nhật `qmldir` và thêm contract test chống tái export/consumer.
- [x] `OspfNetworksSection` đã dùng `RemoveIconButton` với `resources/general/close.svg`; không còn tham chiếu `resources/devicetabs/close.svg` bị thiếu.
- [ ] Gắn consumer hoặc loại `database_search.svg` và `database-push.svg`; hai asset này hiện chưa có action phù hợp được kiểm chứng.
- [ ] Chuẩn hóa English UI copy, capitalization, dấu gạch và thuật ngữ Database/Open DB/CLI.
- [ ] Accessibility: focus ring, tab order, screen-reader label, hit target, contrast, reduced motion.

### Kiểm kê `StandardButton` chưa có icon

Phạm vi kiểm kê là toàn bộ file QML dưới `app/UI/`; `ContextMenuItem`, Activity Bar item và component không phải `StandardButton` không nằm trong mẫu số. Kết quả hiện tại: **171 nút, 52 có icon binding, 119 không khai báo icon**. Bảy nút tăng thêm thuộc Logs/Tool Catalog và giữ text-only do chưa có asset chuyên biệt đúng nghĩa. `ConfigTextViewer` có hai nút chevron, ba nút zoom glyph/text; hai consumer thêm Copy All dùng `clipboard-copy.svg`. Binding động chỉ hiện icon khi action mang nghĩa Save. Contract test giữ các con số này đồng bộ với code; khi thêm/bớt nút phải cập nhật bảng và test cùng thay đổi.

| Label/nhóm | Số lượng | Vị trí | Asset/hướng xử lý còn thiếu |
|---|---:|---|---|
| Add/New (`Add Locally`, `+ Add*`, `New Tool`, `Add Row/All`, DHCP Pool Add/Apply) | 32 | DHCP/NAT, ACL, OSPF/EIGRP/Static, Batch New Device, base cards, External Tools | **Chủ ý text-only.** Không gắn `add.svg`: label đã diễn đạt hành động và nhiều label đã có dấu `+`; icon gây lặp ký hiệu và lỗi bố cục như trường hợp Add Rule/New. |
| `View`, `Edit`, `Delete`, `Remove`, `Close` compact/destructive | 10 | Database Browser, External Tools, Static Route, View & Push và dialog | Giữ text-only theo layout hiện tại; Delete/Remove dùng style Danger và confirm nơi xóa cấu hình. |
| `Cancel Changes` | 13 | DHCP (3), NAT (6), OSPF, EIGRP, ACL Bindings, External Tools | **Chủ ý text-only:** `type: "Text"`, đứng trước action xác nhận, font weight bình thường và underline khi hover/focus; không dùng icon/box vì đây là rollback staged data. |
| `Cancel` / Cancel-Close View | 14 | Dialog New Device/Batch/Add YANG/External Tools, DHCP Pool editor, NAT editor (6), Static Route row/default, ACL editor | **Chủ ý text-only:** cùng Text style; đứng trước Apply/Add/Delete/action xác nhận trong cùng nhóm. |
| `Cancel Deletes` | 1 | ACL pending-delete footer | **Chủ ý text-only:** đứng trước Save, giữ nguyên rollback pending deletes. |
| `Clear` | 6 | Interface, Batch New Device, OSPF/EIGRP Networks, Routing Info, Static Default | Cần icon clear/erase riêng và xác nhận action nào destructive. |
| `Clear Rules` | 1 | ACL form | Cần icon clear-rules; không dùng Delete một row để biểu đạt xoá cả tập. |
| `Apply` | 2 | OSPF Distance, OSPF Tuning | Cần icon apply/confirm. |
| `Change` | 1 | Static Route row | Cần quyết định dùng edit hay apply sau khi thống nhất copy/action state. |
| `Import`, `Get Sample` | 2 | Batch New Device | Cần icon import và download/template riêng. |
| `Reset` | 2 | Settings, ConfigTextViewer | Settings còn cần icon restore/reset; Reset của viewer chủ ý dùng chữ theo cụm điều khiển zoom, không dùng reload DB. |
| Zoom `+` / `−` | 2 | ConfigTextViewer | Chủ ý dùng glyph trực tiếp, có tooltip và trạng thái disabled ở giới hạn 9–40 px; không thay bằng asset gần nghĩa. |
| `Overview`, `Routes`, `Config` | 3 | Routing Info segmented navigation | Có thể giữ text-only; cần chốt policy icon cho segmented navigation trước khi gắn. |
| `modelData` family selector | 1 | Interface port-family selector | Dynamic text-only; chỉ gắn icon nếu có bộ icon đầy đủ cho mọi family. |
| External Tools utility (`Windows defaults`, `Browse`, `Show/Hide advanced`, `Use recommended`) | 4 | External Tools | Chủ ý text-only để giữ progressive disclosure và tránh biểu tượng gần nghĩa; `Scan Windows` đã có icon refresh riêng. |
| Logs capture (`Scan`, `Start/Stop Capture`, `Pause/Resume View`, `Clear View`, `Apply Filter`) | 5 | Device Logs | Chưa có asset capture/pause/filter-apply đúng hệ icon hiện tại; giữ text-only, không tái dùng refresh/close gần nghĩa. |
| Tool Catalog (`Refresh Detection`, `Official Page`) | 2 | Settings → Tool Catalog | Chưa có asset detect/external-link chuyên biệt; giữ text-only và ghi nhận để bổ sung asset sau. |

Các ánh xạ đã triển khai:

- `Reload` đọc DB dùng `database-reload.svg`; riêng Information reload running-config backup dùng `backup.svg`.
- `View & Push` và nút Push xác nhận trong preview đều dùng `push.svg`; không dùng `database-push.svg`.
- mọi action có nhãn Save dùng `save.svg`; nút động Add/Update chỉ hiện icon khi chuyển sang trạng thái có nhãn Save.
- Add/New và các button compact liệt kê trong bảng giữ text-only; `Get running-config` trong device context menu dùng `backup.svg`.

## P1 — security/quality ảnh hưởng UX

- [ ] Chuyển credential khỏi SQLite plaintext sang OS secret store/keyring; DB chỉ lưu secret reference.
- [ ] Redact password trong form preview/log/toast/DB browser/import error.
- [ ] Xoá credential demo `cisco123` khỏi executable sample hoặc thay bằng placeholder không dùng được.
- [ ] Không để backup running-config chứa secret mà không có permission/retention policy.
- [x] Full suite desktop đạt 110/110 ngày 2026-07-16; QML smoke không warning, gồm loader lifecycle, SFTP, Device Logs, Tool Catalog, Feature Bar CLI và External Tools.
- [ ] Bổ sung visual regression/DPI, shortcut registry, reload dirty-state, NetworkMonitor latency và Routing paging performance test để bao phủ các backlog chưa triển khai.

## Definition of Done

Một mục chỉ chuyển DONE khi:

1. code runtime đã có, không chỉ asset/schema;
2. có test tự động hoặc quy trình kiểm chứng tái lập;
3. không tạo QML warning/resource missing;
4. có empty/loading/error và keyboard/focus phù hợp;
5. tài liệu capability/shortcut/usage được cập nhật cùng thay đổi.
