# Báo cáo kiểm tra UI/UX và logic giao diện — NetworkTools

Ngày kiểm tra: 2026-07-10  
Phạm vi: `app/UI/`, các context API trong `app/main.py`, `app/core/` có lời gọi trực tiếp từ QML.

## Kết luận điều hành

UI đã có design token tương đối tốt, bộ standard control được dùng rộng và nhiều danh sách đã dùng `ListView`. Kiến trúc không ở trạng thái “phải viết lại”, nhưng đang ở giai đoạn beta không đồng đều: Routing và DHCP có backend đáng kể; Interface có local CRUD qua `DhcpSlotsMixin` nhưng chưa có workflow push riêng; ACL và NAT hiển thị form có vẻ hoàn chỉnh trong khi phần ghi vẫn là stub. Rủi ro lớn nhất hiện tại là **khoảng cách giữa hình thức hoàn thiện và năng lực thực tế**, tiếp theo là capability/navigation không có một source of truth và validation không đồng nhất.

Đánh giá tổng quan:

| Trục | Mức | Nhận xét |
|---|---:|---|
| Visual/theme foundation | 7/10 | Token màu, size, typography, motion đã có và literal màu được kiểm soát tốt. |
| Component consistency | 6/10 | Standard controls dùng rộng; vẫn có component chết/rỗng và tên `BaseCard` gây hiểu nhầm. |
| Feature completeness | 4/10 | Nhiều feature chỉ placeholder; ACL/NAT dùng stub; Interface có local CRUD nhưng chưa hoàn chỉnh end-to-end. |
| UI/backend correctness | 4/10 trước sửa | Có sai contract NAT làm thao tác Add lỗi runtime. |
| Performance architecture | 5/10 | ListView được dùng nhiều, nhưng top-level eager load và nhiều Repeater không giới hạn. |
| Validation/data safety | 4/10 | Có utility tốt ban đầu nhưng adoption thấp; nhiều form chỉ kiểm tra non-empty. |
| Accessibility/i18n | 2/10 | Không có `Accessible.*`, `qsTr()` hoặc test keyboard có hệ thống trước đợt sửa này. |
| Testability | 3/10 | Không có QML test/lint trong project; smoke phải chạy thủ công. |

## Phát hiện theo mức độ

### P0 — Lỗi contract NAT làm nút Add không hoạt động đúng

`NatStaticForm`, `NatDynamicForm`, `NatPatForm`, `NatAclForm` và `NatRouteMapForm` gọi API với chữ ký khác `StubSlotsMixin`. Ví dụ Dynamic truyền thêm ACL name; ACL/Route Map truyền nhiều positional argument trong khi Python nhận một `QVariant`. PyQt không thể dispatch đúng overload, vì vậy người dùng có thể nhận lỗi QML thay vì warning có kiểm soát.

Nhược điểm khi hoạt động:

- Nút được enable và UI trông như đã hỗ trợ, nhưng click không có outcome đáng tin cậy.
- Không thể phân biệt “feature chưa implement” với bug runtime.
- Sai arity chỉ lộ khi tương tác, smoke load mặc định không bắt được.

Hướng xử lý: đồng bộ stub với contract hiện tại để fail có kiểm soát ngay; sau đó hoặc triển khai backend, hoặc khóa form và hiển thị capability banner. Theo dõi bằng `UI-P0-01` và `UI-P0-05`.

### P0 — Window state không persistent

`StatefulWindow.qml` khai báo `windowSettings` bằng `QtObject`. Các property `savedX`, `savedY`, `savedWidth`, `savedHeight`, `isMaximized`, `isFirstLaunch` chỉ sống trong process. Tên file và comment hứa restore/save, nhưng lần chạy mới luôn trở về default.

Nhược điểm: UX không đúng mô tả, đặc biệt trên multi-monitor; code tạo cảm giác đã hoàn thành khiến bug khó được ưu tiên. Hướng xử lý đã chọn: Python `WindowSettings` dùng `QSettings`, vì PyQt wheel hiện tại không nạp được dependency của QtCore QML settings plugin (`UI-P0-02`).

### P0/P1 — Màn hình có backend stub nhưng không thể hiện trạng thái capability

`DatabaseManager` kế thừa `DhcpSlotsMixin` trước `StubSlotsMixin`. Vì vậy Interface và DHCP dùng implementation thật từ `DhcpSlotsMixin`; ACL và toàn bộ NAT mới rơi vào stub, đọc list rỗng và trả `false` ở thao tác ghi. UI ACL/NAT vẫn render form đầy đủ, thường chỉ khóa theo non-empty/current host. Interface có local CRUD nhưng chưa có controller preview/push riêng và capability level chưa được công bố cho UI.

Nhược điểm:

- Empty state bị hiểu nhầm là “thiết bị chưa có cấu hình”, không phải “backend chưa hỗ trợ”.
- Người dùng nhập nhiều dữ liệu rồi thao tác thất bại.
- Tiến độ UI nhìn cao hơn tiến độ end-to-end thực tế.

Đề xuất: context API cung cấp capability map (`isFeatureAvailable`, reason, read/write levels); view dùng banner/read-only state. Không tự suy ra capability bằng kiểm tra sự tồn tại của method.

### P1 — Eager loading ở cấp feature

`ContentArea.qml` tạo đồng thời 8 view chính. `visible: false` không ngăn object, model, `Component.onCompleted` và connection được tạo. Routing chỉ lazy-load `info_routing`; Static/OSPF/EIGRP vẫn khởi tạo cùng nhau. DHCP và NAT cũng tạo toàn bộ form tab.

Tác động: startup/RSS cao hơn cần thiết; backend reload có thể chạy cho view người dùng chưa mở; thời gian binding và số connection tăng. Đợt này đã xử lý cả top-level và tab con Routing/DHCP/NAT bằng load-on-first-visit + cache, nhờ đó vẫn bảo toàn unsaved state (`UI-P1-01/02`).

### P1 — Báo cáo đầu vào đánh giá quá mức vấn đề virtualization

ACL rule list, NAT, DHCP, Interface, notification, toast, devices và database browser đã dùng `ListView`. `AclRuleRow` hay `SavedListRow` là delegate riêng, không đồng nghĩa mọi row được tạo cùng lúc. Vì vậy không nên thay tất cả bằng `TableView`.

Vấn đề thật nằm ở các `Repeater` gắn với collection có thể lớn: Static routes, OSPF/EIGRP networks/areas/interfaces, routing information. Cần benchmark và thay có chọn lọc (`UI-P1-03/04`).

### P1 — Component thừa và taxonomy chưa rõ

- `BaseButton`: không có consumer; `StandardButton` có mặt trong khoảng 44 file.
- `SectionCard`: file rỗng nhưng được export trong `qmldir`.
- `StandardSideBar`: khoảng 347 dòng, không có consumer; trùng responsibility với `DevicesPanel` đang dùng.
- `StandardValidationDialog`: không có consumer.
- `BaseCard`: không phải card primitive; đây là process-card dùng chung OSPF/EIGRP và chứa model networks/business fields.

Ngược lại, các `AclSubBar`, `DhcpSubBar`, `NatSubBar`, `RoutingSubBar` chỉ cấu hình `tabs/default/disabledTabs` cho `SubBar`; `RoutingPushDialog` chỉ cấu hình controller cho `ViewPushDialog`. Đây là adapter hợp lệ, chi phí bảo trì thấp.

Đề xuất: migration có thời hạn thay vì xóa hàng loạt; đổi `BaseCard` thành `RoutingProcessCardBase`; chỉ thêm table component khi có consumer và contract thật.

### P1 — Validation có nhưng ít được dùng

`ValidationUtils.js` có IPv4/subnet/host/port/routing helpers nhưng chủ yếu chỉ được import ở OSPF/EIGRP process card. Static Route tự viết hàm `/prefix` riêng và yêu cầu trailing space; DHCP/NAT/ACL/Interface phần lớn chỉ kiểm tra chuỗi khác rỗng.

Tác động: invalid IPv4/mask/port đi xuống backend; shortcut không nhất quán; cùng lỗi có message khác nhau. Đợt này tạo `StandardNetworkField` và parser chung cho `/24`, `-/24`; validation đầy đủ còn ở `UI-P0-04`.

### P2 — Thiếu accessibility và localization foundation

Baseline không có `Accessible.*` và không có `qsTr()`. Nhiều control tự vẽ bằng `Rectangle`/handler; tên accessible, role, selected state và focus order chưa được đảm bảo. Chuỗi Anh/Việt trộn lẫn (ví dụ preview/push dialog).

Đề xuất: bắt đầu tại standard controls để lan tỏa; sau đó audit keyboard/dialog/tab/list và chuyển chuỗi sang `qsTr()` theo từng workflow.

### P2 — Responsive table/form còn width cứng

Nhiều list header/cell đặt width 80/110/120/140. Khi sidebar/split pane nhỏ hoặc DPI cao, cột cuối bị co về 0 hoặc elide quá mức. Một số GridLayout đã có breakpoint nhưng chưa có policy chung.

Đề xuất: column metadata (`minimum`, `weight`, `priority`), breakpoint split-to-stack và test 900x600 + DPI 150/200%.

### P2 — File lớn gom cả layout, state và controller logic

Các file lớn nhất: `AclForm` 763 dòng, `SettingsView` 723, `info_routing` 646, `BatchNewDevice` 616, `OspfRoutingForm` 592, `EigrpRoutingForm` 524. Kích thước tự nó không phải bug, nhưng các file này cùng quản lý model, validation, backend calls, state và layout, làm regression khó cô lập.

Đề xuất: tách theo responsibility và test seam, không đặt quota dòng cứng.

## Phần giao diện còn thiếu/chưa hoàn thiện

- Feature bar placeholder: VLAN, STP, QoS, SNMP, NTP, AAA, MPLS, VPN, Firewall và Monitor. Index 4 hiện bị lệch: `FeatureBar` gọi là BGP còn `ContentArea` gọi là VRF.
- Routing: BGP bị disabled; Info/Static/OSPF/EIGRP có UI.
- DHCP: Info bị disabled; Pool/Excluded/Helper có UI và backend đáng kể.
- NAT: Info bị disabled; sáu form còn dựa trên stub.
- ACL: năm loại UI nhưng persistence vẫn stub.
- Interface: UI và local CRUD khá đầy đủ qua `DhcpSlotsMixin`; chưa có preview/push riêng, capability banner và validation end-to-end.
- CLI: hiện là action gọi `cli.openTerminal()`, không phải một view trong `ContentArea`.
- Settings: một số group trả “not implemented yet”.
- Activity bar: Topology disabled/coming soon.
- Notification: toast/history đã tồn tại; thiếu log/task console có filter, retention và device/source metadata.

## Đánh giá báo cáo đầu vào

| Nhận định ban đầu | Kết quả kiểm tra |
|---|---|
| Base và Standard bị trùng | Đúng với `BaseButton` (đang chết); không đúng với `BaseCard` vì nó là process form, còn `SectionCard` đang rỗng. |
| Các SubBar bị copy hard-code | Không đúng hiện trạng; chúng là adapter mỏng dùng chung `SubBar`. |
| Dialog bị trùng | Không đúng với Routing push; nó kế thừa `ViewPushDialog`. Validation dialog là use case khác. |
| Thiếu StandardTable | Đúng về contract bảng nâng cao, nhưng đã có reusable saved-list shell và nhiều ListView ảo hóa. |
| Row riêng gây mất virtualization | Không đúng; delegate file riêng vẫn được ListView virtualize. Chỉ Repeater collection lớn là rủi ro. |
| ValidationUtils quá tải | Chưa đúng; file còn nhỏ. Vấn đề hiện tại là adoption/coverage, không phải kích thước. |
| Main khởi tạo mọi module | Đúng ở `ContentArea` và nhiều tab con. |
| Notification phụ thuộc icon cứng | Chưa đủ bằng chứng; toast/history hoạt động. Thiếu structured log console là nhu cầu khác. |
| Cần `/24` và `-/24` | Đúng; `/24` tồn tại cục bộ ở Static Route, `-/24` chưa có chuẩn chung. |

## Hướng đi đề xuất

1. Hoàn tất P0 correctness/capability trước khi mở thêm feature.
2. Lazy-load theo “first visit + cache” để giảm startup mà không mất dữ liệu form.
3. Đưa normalization/validation vào specialized standard controls, sau đó áp dụng theo ma trận field.
4. Dọn dead component bằng deprecation + consumer migration; không xóa adapter domain hợp lệ.
5. Chỉ xây table abstraction sau khi chốt contract từ ba consumer thật và benchmark collection lớn.
6. Dùng capability-driven UI để tiến độ visual không vượt quá tiến độ end-to-end.
7. Bổ sung QML smoke, slot-contract test, keyboard/a11y và visual regression vào Definition of Done.

Roadmap có mã, tiêu chí và trạng thái thực thi nằm trong [SCHEMA_for_UI.md](SCHEMA_for_UI.md). Kế hoạch thiết kế theo họ giao diện và theo từng Feature/SubFeature nằm trong [UI_PATTERN_SYSTEM.md](UI_PATTERN_SYSTEM.md), [FEATURE_UI_DESIGN_PLAN.md](FEATURE_UI_DESIGN_PLAN.md) và [CONTINUATION_ROADMAP.md](CONTINUATION_ROADMAP.md).
