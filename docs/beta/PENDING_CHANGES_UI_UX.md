# Thay đổi chờ xử lý — UI/UX, hiệu năng và thẩm mỹ

Ngày kiểm chứng: **2026-07-14**. Đây là backlog UI/UX của ứng dụng desktop, nên trạng thái được đối chiếu trực tiếp với toàn bộ `app/`; không đánh dấu hoàn thành dựa trên tài liệu cũ. Backend dự án `backend cua kien/`, API, mock và báo cáo vẫn thuộc NetworkTools nhưng được đánh giá ở [`../ARCHITECTURE.md`](../ARCHITECTURE.md) và [`../CODE_AUDIT.md`](../CODE_AUDIT.md), không bị loại khỏi phạm vi dự án chỉ vì không nằm trong backlog UI này.

Ký hiệu: **DONE** đã có trong code; **PARTIAL** có một phần nhưng chưa đạt yêu cầu; **TODO** chưa có; **BLOCKED** phụ thuộc lỗi correctness khác.

## P0 — correctness trước UX

| ID | Trạng thái | Yêu cầu |
|---|---|---|
| CORE-01 | DONE | OSPF/EIGRP interface CRUD đã dùng `t04_router_iface_ospf/eigrp` + `iface_id`; JOIN trả lại `interface_name`, unknown interface rollback. 4/4 routing contract test và toàn bộ 19 test non-QML đạt. |
| CORE-02 | PARTIAL | Validation form: `ValidationUtils` và normalize shorthand đã có, nhưng DHCP/NAT/Interface không validate semantic đầy đủ và backend chưa chặn dữ liệu mạng sai. |
| CORE-03 | TODO | Chuẩn hóa structured result cho mọi write slot; nhiều slot vẫn trả bool nên UI chỉ có thông báo lỗi chung. |
| CORE-04 | TODO | Dirty-state guard trước reload, đổi host, đổi feature hoặc đóng tab để không mất staged changes. |

## P1 — hiệu năng và responsiveness

| ID | Trạng thái | Yêu cầu/tiêu chí |
|---|---|---|
| PERF-01 | TODO | Chuyển `NetworkMonitor._refresh()` khỏi UI thread; không được gọi lệnh OS đồng bộ mỗi 3 giây trên main thread. Cache SSID và đo latency. |
| PERF-02 | TODO | Routing Info dùng query filter/page và `ListView`; bỏ `allRoutes → visibleRoutes` copy + `Repeater` toàn bộ row. Test với ít nhất 10.000 route. |
| PERF-03 | PARTIAL | Lazy-load feature/subtab đã có. Bổ sung memory policy: unload view không dirty hoặc giới hạn cache, đo startup/peak RAM. |
| PERF-04 | TODO | Reload activation phải coalesce/debounce và không query lại tất cả subtab; chỉ reload feature/tab đang active hoặc dữ liệu được invalidated. |
| PERF-05 | TODO | Database Browser bổ sung paging/row count/sort; limit 500 hiện tại không có offset hay thứ tự ổn định. |
| PERF-06 | TODO | Tách `SettingsView.qml`, `AclForm.qml`, OSPF/EIGRP form lớn thành section/component có ownership rõ để giảm binding và chi phí bảo trì. |

## P1 — core UI/UX

| ID | Trạng thái | Yêu cầu |
|---|---|---|
| UX-01 | TODO | Command registry toàn cục: `Ctrl+R`, `Ctrl+S`, Activity Bar (`Ctrl+1..`), View & Push (`Ctrl+Shift+P`), enable theo context/focus/dirty state. |
| UX-02 | DONE | `CopyButton` chỉ xuất hiện trong từng item của Notification Center; toast nổi không có Copy. History copy có tooltip/feedback “Copied”, focus bàn phím và QML contract test. |
| UX-03 | DONE | `StandardPasswordField` mặc định che password, eye toggle giữ cursor/focus và có accessible metadata; đã áp dụng New Device, Batch, Add YANG và PPP password. |
| UX-04 | DONE | `Theme.selectionBackground/Foreground` đã dùng thống nhất ở field/spin/editor; foreground được chọn theo WCAG relative-luminance và runtime test đạt tối thiểu 4.5:1 trên light/dark/high-contrast với custom accent. |
| UX-05 | TODO | Feature activation reload: view expose `reloadData(reason)`. Nếu form dirty thì không ghi đè; hiển thị stale-data banner/confirm. |
| UX-06 | PARTIAL | Reconnect đã có; đóng tab đã đóng session. Cần test close-without-session, task đang chạy và reopen không reconnect. |
| UX-07 | DONE | Sidebar section rỗng được ẩn; Connected/Waiting auto-expand; Disconnected không auto-expand. |
| UX-08 | DONE | Settings navigator đã bỏ General/Advanced placeholder, chỉ còn Theme và External Tools. |
| UX-09 | PARTIAL | Icon cho action button: chỉ gắn cho Save/Reload/View & Push/Push/backup có asset chuyên biệt; Add/New, Cancel và button compact tương tự giữ text-only để tránh lỗi bố cục/lặp ký hiệu. Hiện 85/128 `StandardButton` không khai báo icon, được kiểm kê ở mục P2. |
| UX-10 | DONE | Notification Center có chiều cao động 44–400 px, toolbar SVG-only căn giữa, màu severity/DND không phụ thuộc accent, DND mặc định OFF chặn toast nhưng vẫn lưu history, và Status Bar nhấp nháy `dnd.svg` khi có unread. |

## P1 — Information/Observe view

`InformationView.qml` hiện chỉ load live/backup, có Reload và TextArea read-only. Các mục sau đều chưa có:

- [ ] `Ctrl+F`, search bar, next/previous match và match count;
- [ ] `Ctrl + wheel` zoom, giới hạn font size và reset zoom;
- [ ] line number đồng bộ scroll; click gutter chọn/highlight dòng;
- [ ] Copy All, copy selection và feedback;
- [ ] syntax highlighting cho IP/prefix/mask/wildcard, interface, number, yes/no, date-time, permit/deny, inside/outside;
- [ ] xử lý văn bản lớn không block UI; cân nhắc syntax highlighter theo block/viewport;
- [ ] reload khi Information được kích hoạt, nhưng không request trùng khi command đang chạy;
- [ ] empty/loading/error state dùng chung cho F1.

Routing Config đang có TextArea tương tự; nên tái dùng một `ConfigTextViewer` thay vì implement hai lần.

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
| Logs item | PARTIAL | Placeholder `logs.svg` đã hiển thị mờ, disabled và được test. Dự kiến lưu/tra cứu log theo Device; storage, loại sự kiện, retention, redaction và Content Area vẫn TODO. |
| SFTP item | PARTIAL | Placeholder `sftp.svg` đã hiển thị mờ, disabled và được test. Session/host-key/auth/transfer contract và Content Area vẫn TODO. |
| Database placement/name | DONE | Database đã được chuyển vào bottom group ngay trên Settings, tooltip đổi thành “Database”; index/mode cũ được giữ nguyên. |
| CLI feature | PARTIAL | Feature CLI/global shortcut chỉ mở terminal OS. Device context menu có thể mở SSH client qua External Tools. Chưa có terminal tích hợp. |
| Topology | TODO | Item disabled/coming soon. Không hiển thị như capability sẵn có. |

Quy ước placeholder cho ba item mới `Console Serial`, `Logs`, `SFTP`:

- icon tồn tại không đồng nghĩa capability đã triển khai;
- tạm thời vẫn hiển thị với `opacity: 0.35`, `enabled: false`, `isActive: false` và không có `onClicked` gọi `handleItemClick()`, giống trạng thái coming-soon của Topology;
- không cấp `activeIndex`, `appMode`, sidebar route, Content Area loader hoặc shortcut khi còn disabled;
- không bắt buộc thiết kế Content Area trong giai đoạn này;
- chỉ chuyển sang visible/interactive khi contract backend, dữ liệu, lifecycle, error/security và test tương ứng đã được duyệt.

Placeholder contract được kiểm chứng bởi `QmlSmokeTests.test_activity_bar_reserved_items_stay_visible_and_inert`.

## P1 — Database Browser

- [ ] Parser tên bảng `^t(\d{2})_(.+)$`, map nhóm 01 Core, 02 Interface, 03 DHCP, 04 Routing, 05 Security/NAT, 06 L2, 07 VRF.
- [ ] Tree/collapse UI giống DeviceSection; ẩn nhóm rỗng, giữ selection/filter.
- [ ] Đổi table row từ danh sách phẳng sang item có tên hiển thị + tên SQL phụ.
- [ ] Search giữ context group; hỗ trợ search cột.
- [ ] Paging/sort/row count và cảnh báo giới hạn 500.
- [ ] Bảo vệ cột nhạy cảm hoặc redact password; không cho edit tùy tiện credential.
- [ ] Xác nhận trước edit, hiển thị kiểu dữ liệu/NULL và transaction error rõ ràng.

## P1 — External Tools

- [ ] Auto-detect PuTTY, SecureCRT, Windows Terminal/editor/DB Browser qua registry, PATH và known install locations; không scan toàn disk.
- [ ] Nút Browse bằng native file dialog; validate executable trước Save.
- [ ] Argument template theo tool type và preview command đã redact.
- [ ] Không hỗ trợ `{password}` trên command line; chuyển sang cơ chế an toàn hoặc cảnh báo/block.
- [ ] Hoàn thiện detail/preview pane bên phải đang trống khi có tool.
- [ ] CRUD result/toast thống nhất, confirm delete, keyboard/focus order.

## P2 — DHCP/NAT/ACL dashboards

- [ ] DHCP Info từ `t09_info_dhcp_pool`, binding, conflict, statistics và database; không chỉ hai bảng đầu.
- [ ] NAT Info từ t11: summary, pools, static/dynamic, active translations, statistics, collection state.
- [ ] ACL Info từ t10: ACL/rule/interface binding và collection state.
- [ ] Mỗi dashboard có collected timestamp, stale indicator, empty/error/loading, filter và virtualized table.
- [ ] Chỉ enable tab khi backend read path tồn tại và có test; không để disabled tab trỏ placeholder lâu dài.

## P2 — consistency và thẩm mỹ

- [x] `StandardSpinBox` đã dùng left padding 12 như TextField.
- [x] Phần lớn action button dùng `StandardButton`; 43/128 instance có icon binding. Nút xoá OSPF Network dùng `RemoveIconButton` chuẩn.
- [x] Gắn consumer đúng nghĩa cho `backup.svg`, `database-reload.svg`, `push.svg`, `save.svg`; cả View & Push và Push xác nhận đều dùng `push.svg`.
- [x] Cả 26 action Cancel dùng Text style, đứng đầu action group khi có action xác nhận cùng hàng: không box/icon, font weight bình thường và underline khi hover/focus. Bao gồm 12 `Cancel Changes`, 13 `Cancel`/Cancel-Close View và `Cancel Deletes`; `StandardButton` có focus ring Accent khi Tab.
- [ ] Thêm visual regression test cho icon+text alignment, trạng thái disabled, theme light/dark và nút có label dài.
- [ ] Chuẩn hóa split width theo family/breakpoint, không ép Interface/ACL về 320 px nếu content không phù hợp.
- [ ] Xoá `BaseCard` duplicate và `BaseButton` không consumer; cập nhật `qmldir`.
- [x] `OspfNetworksSection` đã dùng `RemoveIconButton` với `resources/general/close.svg`; không còn tham chiếu `resources/devicetabs/close.svg` bị thiếu.
- [ ] Gắn consumer hoặc loại `database_search.svg` và `database-push.svg`; hai asset này hiện chưa có action phù hợp được kiểm chứng.
- [ ] Chuẩn hóa English UI copy, capitalization, dấu gạch và thuật ngữ Database/Open DB/CLI.
- [ ] Accessibility: focus ring, tab order, screen-reader label, hit target, contrast, reduced motion.

### Kiểm kê `StandardButton` chưa có icon

Phạm vi kiểm kê là toàn bộ file QML dưới `app/UI/`; `ContextMenuItem`, Activity Bar item và component không phải `StandardButton` không nằm trong mẫu số. Kết quả hiện tại: **128 nút, 43 có icon binding, 85 không khai báo icon**. Binding động chỉ hiện icon khi action mang nghĩa Save. Contract test giữ các con số này đồng bộ với code; khi thêm/bớt nút phải cập nhật bảng và test cùng thay đổi.

| Label/nhóm | Số lượng | Vị trí | Asset/hướng xử lý còn thiếu |
|---|---:|---|---|
| Add/New (`Add Locally`, `+ Add*`, `New`, `Add Row/All`, DHCP Pool Add/Apply) | 33 | DHCP/NAT, ACL, OSPF/EIGRP/Static, Batch New Device, base cards, External Tools | **Chủ ý text-only.** Không gắn `add.svg`: label đã diễn đạt hành động và nhiều label đã có dấu `+`; icon gây lặp ký hiệu và lỗi bố cục như trường hợp Add Rule/New. |
| `View`, `Edit`, `Delete`, `Close` compact | 5 | Database Browser (2), External Tools, Static Route row, View & Push dialog | Giữ text-only theo layout hiện tại; chỉ xem xét lại sau visual test ở kích thước thực. |
| `Cancel Changes` | 12 | DHCP (3), NAT (6), OSPF, EIGRP, ACL Bindings | **Chủ ý text-only:** `type: "Text"`, đứng đầu action group, font weight bình thường và underline khi hover/focus; không dùng icon/box vì đây là rollback staged data. |
| `Cancel` / Cancel-Close View | 13 | Dialog New Device/Batch/Add YANG, DHCP Pool editor, NAT editor (6), Static Route row/default, ACL editor | **Chủ ý text-only:** cùng Text style; đứng trước Apply/Add/Delete/action xác nhận trong cùng nhóm. |
| `Cancel Deletes` | 1 | ACL pending-delete footer | **Chủ ý text-only:** đứng trước Save, giữ nguyên rollback pending deletes. |
| `Clear` | 6 | Interface, Batch New Device, OSPF/EIGRP Networks, Routing Info, Static Default | Cần icon clear/erase riêng và xác nhận action nào destructive. |
| `Clear Rules` | 1 | ACL form | Cần icon clear-rules; không dùng Delete một row để biểu đạt xoá cả tập. |
| `Apply` | 2 | OSPF Distance, OSPF Tuning | Cần icon apply/confirm. |
| `Change` | 1 | Static Route row | Cần quyết định dùng edit hay apply sau khi thống nhất copy/action state. |
| `Import`, `Get Sample` | 2 | Batch New Device | Cần icon import và download/template riêng. |
| `Reset` | 1 | Settings | Cần icon restore/reset; không dùng reload DB. |
| `Overview`, `Routes`, `Config` | 3 | Routing Info segmented navigation | Có thể giữ text-only; cần chốt policy icon cho segmented navigation trước khi gắn. |
| `modelData` family selector | 1 | Interface port-family selector | Dynamic text-only; chỉ gắn icon nếu có bộ icon đầy đủ cho mọi family. |

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
- [ ] Sửa QML Main smoke test và thêm performance/visual/keyboard tests để các cải tiến UI không hồi quy.

## Definition of Done

Một mục chỉ chuyển DONE khi:

1. code runtime đã có, không chỉ asset/schema;
2. có test tự động hoặc quy trình kiểm chứng tái lập;
3. không tạo QML warning/resource missing;
4. có empty/loading/error và keyboard/focus phù hợp;
5. tài liệu capability/shortcut/usage được cập nhật cùng thay đổi.
