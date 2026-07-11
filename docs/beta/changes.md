# So sánh `refactor/fronend-beta` và `frontend-beta`

Ngày đối chiếu: 2026-07-10  
Nhánh gốc: `frontend-beta` tại `9e808c4`  
Nhánh refactor thực tế trong repository: `refactor/fronend-beta` tại `221eee0`

> Lưu ý về tên nhánh: yêu cầu ban đầu ghi `refactor/frontend-beta`, nhưng repository không có ref này. Báo cáo sử dụng nhánh đang tồn tại là `refactor/fronend-beta` (thiếu chữ `t` trong `fronend`).
>
> Phạm vi so sánh là nội dung đã commit giữa hai đầu nhánh. Các thay đổi chưa commit đang có trong worktree, gồm việc chuyển `app/md_by_old/` sang `docs/beta/md_by_old/`, không được tính vào báo cáo này.

## 1. Tổng quan

`refactor/fronend-beta` được phát triển trực tiếp từ `frontend-beta`; merge-base chính là commit đầu nhánh `frontend-beta`. Nhánh refactor đi trước 2 commit và không có commit riêng ở nhánh gốc cần hòa giải:

| Commit | Nội dung chính |
|---|---|
| `14ffa08` | Refactor kiến trúc UI, chuẩn hóa input mạng, sửa contract NAT/window state, thêm test và tài liệu audit |
| `221eee0` | Chỉnh bố cục `DhcpView` để đồng nhất hơn với các màn hình cấu hình/routing |

Quy mô diff:

- 33 file thay đổi.
- 1.153 dòng thêm, 189 dòng xóa.
- 3 file test/harness mới, gồm 6 test mới.
- 2 tài liệu UI mới: `SCHEMA_for_UI.md` và `UI_AUDIT_REPORT.md`.

### Kết luận ngắn

| Trục đánh giá | Mức ảnh hưởng | Kết luận |
|---|---:|---|
| Hiệu suất khởi động | Tích cực, chưa định lượng | Lazy-load làm giảm số view/form được tạo ngay khi mở ứng dụng. Chưa có benchmark thời gian, RSS hoặc số object để khẳng định tỷ lệ cải thiện. |
| Hiệu suất khi dùng lâu | Gần trung tính | View đã mở được cache để giữ state; bộ nhớ sẽ tăng dần và có thể gần mức cũ sau khi người dùng mở toàn bộ màn hình. |
| Chất lượng/correctness | Tích cực rõ rệt | Sửa contract NAT, lưu window state thật, thêm smoke/contract test và giảm logic nhập liệu trùng lặp. |
| UX và tính nhất quán | Tích cực | Hỗ trợ `/24`, `-/24`, placeholder rõ hơn, lưu kích thước cửa sổ và bổ sung header DHCP. |
| Thiết kế hình ảnh | Thay đổi vừa phải | Không đổi theme hay ngôn ngữ thiết kế tổng thể; thay đổi trực quan đáng kể nhất nằm ở header DHCP và nội dung hướng dẫn trong field. |
| Accessibility | Cải thiện bước đầu | Button và text field chuẩn có accessible role/name; keyboard navigation, focus order và selected state vẫn chưa được xử lý đầy đủ. |
| Rủi ro tương thích | Thấp đến vừa | Thời điểm khởi tạo view bị trì hoãn; giá trị shorthand được tự chuyển đổi; chữ ký NAT stub thay đổi để khớp QML hiện tại. |

## 2. Các thay đổi chi tiết

### 2.1. Lazy-load màn hình và tab nặng

File chính:

- `app/UI/qml/content/ContentArea.qml`
- `app/UI/qml/routing/RoutingView.qml`
- `app/UI/qml/dhcp/DhcpView.qml`
- `app/UI/qml/nat/NatView.qml`

Trước refactor, `ContentArea` tạo đồng thời Routing, DHCP, ACL, NAT, Interface, Information, Settings và Database dù phần lớn đang ẩn. Các tab con của Routing, DHCP và NAT cũng được khởi tạo sớm.

Sau refactor:

- Mỗi màn hình cấp feature được bọc bằng `Loader` và chỉ tạo ở lần truy cập đầu tiên.
- Routing chỉ tạo tab Info ban đầu; Static, OSPF và EIGRP được tạo khi người dùng mở tab tương ứng.
- DHCP chỉ tạo Pool ban đầu; Excluded và Helper được tạo khi cần.
- NAT chỉ tạo Static ban đầu; Dynamic, PAT, Interfaces, ACL và Route Map được tạo khi cần.
- View đã được mở không bị unload. Cơ chế “load once, preserve state” giữ dữ liệu form chưa lưu khi đổi tab.

Ảnh hưởng:

- **Hiệu suất:** giảm công việc tạo QML object, binding, model, connection và các lời gọi `Component.onCompleted` không cần thiết lúc khởi động. Đây là cải thiện chắc chắn về kiến trúc, nhưng diff không cung cấp số đo startup/RSS/FPS nên chưa thể ghi nhận phần trăm cải thiện.
- **Độ phản hồi:** lần mở đầu tiên của một feature/tab có thể chậm hơn nhẹ do chi phí khởi tạo được chuyển từ startup sang thời điểm tương tác. Các lần mở sau dùng instance đã cache.
- **Bộ nhớ:** tốt hơn ở phiên chỉ dùng một số feature; lợi ích giảm dần khi người dùng đã mở tất cả view vì chúng được giữ lại.
- **Chất lượng UX:** không mất form đang nhập khi chuyển tab, phù hợp hơn với workflow cấu hình thiết bị.
- **Rủi ro hành vi:** logic reload hoặc side effect trong `Component.onCompleted` giờ chỉ chạy khi view được truy cập, thay vì chạy ngay lúc mở ứng dụng. Consumer bên ngoài nếu từng phụ thuộc vào eager initialization cần được kiểm tra lại.

### 2.2. Component nhập liệu mạng dùng chung

File/component mới:

- `app/UI/components/standard/StandardNetworkField.qml`
- Export mới trong `app/UI/qmldir`.

Utility mới trong `ValidationUtils.js`:

- `prefixToWildcard(prefix)` chuyển prefix sang wildcard mask.
- `parseWildcardInput(text)` hỗ trợ cú pháp `-/n`.
- Logic subnet `/n` trước đây viết riêng trong `StaticRouteRow.qml` được loại bỏ và dùng component chung.

Component mới đang được dùng tại 28 field trong 11 file thuộc Routing, DHCP, ACL, NAT và Interface. Hành vi chính:

- `/24` được chuẩn hóa thành `255.255.255.0` khi kết thúc chỉnh sửa.
- `-/24` được chuẩn hóa thành `0.0.0.255` khi kết thúc chỉnh sửa.
- Static Route không còn yêu cầu người dùng nhập thêm dấu cách sau `/24` để kích hoạt chuyển đổi.
- Label/placeholder được bổ sung ví dụ shorthand tại các field subnet và wildcard.

Ảnh hưởng:

- **Chất lượng:** giảm code trùng lặp và tránh mỗi form diễn giải prefix theo một cách khác nhau. Việc mở rộng hành vi có thể thực hiện ở một component thay vì sửa nhiều form.
- **UX:** nhập mask nhanh hơn và dễ khám phá hơn nhờ label/placeholder; hành vi nhất quán giữa các module.
- **Thiết kế:** không thay đổi đáng kể hình thức control vì `StandardNetworkField` kế thừa `StandardTextField`; thay đổi chủ yếu là nội dung hướng dẫn và hành vi.
- **Hiệu suất:** chi phí regex/chuyển đổi chỉ xảy ra khi kết thúc chỉnh sửa và không đáng kể so với render/backend I/O.
- **Giới hạn quan trọng:** `inputKind: "ipv4"` hiện chưa tự validate hoặc chặn IPv4 sai. Component cũng không thay thế validation ở bước submit. Các form vẫn cần kiểm tra IPv4, subnet, wildcard, port và quan hệ giữa các field trước khi gọi backend.

### 2.3. Sửa contract giữa QML và NAT stub

File chính: `app/core/database_stubs.py`.

Chữ ký của 5 slot được đổi để khớp lời gọi positional từ QML:

| Slot | Thay đổi |
|---|---|
| `addNatStaticEntry` | Nhận local/global port thay cho tham số description cũ |
| `addNatDynamicPool` | Bổ sung `acl_name` |
| `addNatPatRule` | Đồng bộ source type/value và đổi `overload` sang kiểu `bool` |
| `addNatAcl` | Đổi từ một `QVariant` payload sang 5 tham số cụ thể |
| `addNatRouteMapEntry` | Đổi từ một `QVariant` payload sang 6 tham số cụ thể, gồm sequence kiểu `int` |

Ảnh hưởng:

- **Correctness:** loại bỏ lỗi dispatch do sai số lượng/kiểu tham số tại biên PyQt/QML. Thao tác chưa được hỗ trợ giờ đi tới `_unsupported_write()` và trả `false` có kiểm soát, thay vì lỗi `TypeError` trước khi UI có thể báo trạng thái.
- **Chất lượng:** contract rõ ràng hơn, dễ kiểm thử và dễ phát hiện lệch chữ ký về sau.
- **Hiệu suất:** không có ảnh hưởng đáng kể.
- **Giới hạn:** đây vẫn là stub; thay đổi không biến NAT thành chức năng ghi dữ liệu thật. Form NAT vẫn có thể trông hoàn chỉnh hơn năng lực backend hiện có.
- **Tương thích:** consumer ngoài repository nếu đang gọi chữ ký stub cũ phải cập nhật. Các lời gọi QML nội bộ hiện tại đã khớp chữ ký mới.

### 2.4. Lưu trạng thái cửa sổ qua nhiều lần chạy

File chính:

- `app/core/runtime.py`
- `app/backend.py`
- `app/main.py`
- `app/UI/qml/app/StatefulWindow.qml`

`WindowSettings` mới dùng `QSettings` để lưu:

- Vị trí `x/y`.
- Kích thước width/height.
- Trạng thái maximized.
- Cờ first launch.

Object được đăng ký vào QML context dưới tên `windowSettings`. `StatefulWindow` vẫn có fallback an toàn khi chạy trong design tooling hoặc môi trường không có context object.

Ảnh hưởng:

- **UX:** cửa sổ mở lại theo kích thước/trạng thái trước đó thay vì luôn quay về mặc định; hữu ích rõ rệt trên màn hình lớn và workflow dùng nhiều cửa sổ.
- **Correctness:** tên và hành vi “StatefulWindow” giờ thống nhất; trước đây settings chỉ là `QtObject` trong RAM và mất khi process kết thúc.
- **Hiệu suất:** có một lượng I/O cấu hình rất nhỏ khi lưu state; `sync()` là đồng bộ nhưng chỉ nằm trong luồng lưu/đánh dấu launch, không phải render loop.
- **Rủi ro:** trạng thái lưu từ cấu hình multi-monitor cũ vẫn phụ thuộc vào logic `validateBounds` hiện có để tránh phục hồi cửa sổ ngoài vùng nhìn thấy.

### 2.5. Accessibility ở standard controls

Thay đổi:

- `StandardButton` có `Accessible.Button`, name lấy từ text hoặc tooltip, description lấy từ tooltip.
- `StandardTextField` có `Accessible.EditableText`, name lấy từ label hoặc placeholder.
- `StandardNetworkField` kế thừa contract accessibility của `StandardTextField`.

Ảnh hưởng:

- **Chất lượng và khả năng tiếp cận:** screen reader có metadata cơ bản tốt hơn mà không cần từng feature tự khai báo lại.
- **Thiết kế hình ảnh/hiệu suất:** không tạo thay đổi nhìn thấy và chi phí runtime không đáng kể.
- **Giới hạn:** chưa có audit focus order, Tab/Enter/Escape, selected/current semantics, focus trap trong dialog hoặc test với screen reader thật.

### 2.6. Điều chỉnh thiết kế `DhcpView`

Commit `221eee0` chỉ thay đổi `DhcpView.qml`. Phần thanh thông tin dạng `RowLayout` đơn giản được thay bằng header cao 58 px với:

- Tiêu đề đậm “DHCP Information”.
- Host IP hoặc trạng thái “No device selected” ở dòng phụ.
- Khoảng lề trái/phải 24 px, spacing theo theme.
- Đường phân cách dưới dùng `Theme.borderColor`.
- Nút View/Push được giữ ở bên phải và giữ nguyên callback reload sau khi push thành công.

Ảnh hưởng:

- **Thiết kế:** phân cấp thị giác rõ hơn, cân bằng hơn với các màn hình cấu hình khác và làm host hiện tại dễ nhận biết.
- **UX:** trạng thái chưa chọn thiết bị rõ ràng hơn; hành động chính vẫn ở vị trí nổi bật.
- **Hiệu suất:** thêm một số item QML nhẹ; tác động rất nhỏ và được bù bởi lazy-load của toàn bộ `DhcpView`/tab con.
- **Phạm vi:** không có thay đổi theme token, typography toàn cục hoặc responsive breakpoint; đây là chỉnh sửa cục bộ, chưa phải redesign toàn hệ thống.

### 2.7. Làm rõ hệ thống component

Các thay đổi này chủ yếu là contract/documentation trong code, không đổi runtime:

- `BaseButton` được đánh dấu legacy; code mới nên dùng `StandardButton`.
- `StandardSideBar` được ghi chú là duplicate chưa có consumer nội bộ và không nên được dùng mới.
- `BaseCard` được làm rõ là process card chứa logic/model OSPF/EIGRP, không phải card primitive để hợp nhất tùy ý.

Ảnh hưởng:

- **Maintainability:** giảm nguy cơ tiếp tục nhân rộng component trùng trách nhiệm hoặc refactor nhầm abstraction.
- **Tương thích:** chưa xóa export/component cũ, nên không gây breaking change ngay cho consumer ngoài module.
- **Thiết kế:** chưa làm thay đổi UI hiển thị; đây là bước chuẩn bị cho migration có kiểm soát.

### 2.8. Test và tài liệu kỹ thuật

File mới:

- `app/tests/qml/NetworkFieldHarness.qml`
- `app/tests/test_qml_smoke.py`
- `app/tests/test_ui_contracts.py`
- `docs/beta/SCHEMA_for_UI.md`
- `docs/beta/UI_AUDIT_REPORT.md`

Coverage mới kiểm tra:

- Main QML module load được và không phát warning.
- 8 feature/mode cấp cao và 13 tab con có thể được lazy-load.
- `/24` và `-/24` cho kết quả chuẩn hóa đúng.
- Window state tồn tại qua instance backend mới.
- Số tham số của 5 NAT add stub khớp lời gọi QML.

Kết quả xác minh tại thời điểm lập báo cáo:

```text
PYTHONUTF8=1 QT_QPA_PLATFORM=offscreen
python -B -m unittest discover -s tests -v

Ran 11 tests in 2.083s
OK
```

Ảnh hưởng:

- **Chất lượng:** tăng khả năng phát hiện regression ở import QML, lazy-load, persistence và contract bridge.
- **Tốc độ phát triển:** lỗi arity hoặc lỗi load module có thể được phát hiện trước khi kiểm thử thủ công toàn bộ giao diện.
- **Giới hạn:** test NAT mới kiểm tra số tham số bằng reflection, chưa bấm nút Add end-to-end hoặc kiểm tra đầy đủ type/value. Chưa có benchmark hiệu suất, visual regression, accessibility automation hay test responsive/DPI.

## 3. Ma trận tác động tổng hợp

| Thay đổi | Hiệu suất | Chất lượng | UX/thiết kế | Rủi ro/đánh đổi |
|---|---|---|---|---|
| Lazy-load feature/tab | Tốt hơn lúc startup và phiên dùng ít feature | Lifecycle rõ hơn | Giữ state form khi chuyển tab | Lần mở đầu có thể chậm; bộ nhớ tăng dần theo số view đã mở |
| `StandardNetworkField` | Gần như trung tính | Giảm logic trùng lặp | Nhập `/24`, `-/24` nhanh và nhất quán | Chưa phải validation submit đầy đủ |
| Sửa NAT slot contract | Trung tính | Loại lỗi dispatch, fail có kiểm soát | Thông báo lỗi có cơ hội hoạt động đúng | Backend NAT vẫn chưa được triển khai |
| `WindowSettings` | I/O nhỏ khi lưu | Persistence đúng contract | Khôi phục window state | Cần tiếp tục QA multi-monitor/DPI |
| Accessibility metadata | Trung tính | Tốt hơn cho standard controls | Không đổi hình ảnh | Coverage keyboard/screen reader còn thiếu |
| Header DHCP | Tác động rất nhỏ | Bố cục rõ trách nhiệm hơn | Phân cấp thị giác tốt hơn | Chỉ là chỉnh cục bộ, chưa giải quyết responsive toàn hệ thống |
| Smoke/contract tests | Không ảnh hưởng runtime production | Giảm regression | Không đổi trực tiếp UI | Chưa có performance/visual/E2E test |

## 4. Những vấn đề chưa được giải quyết

Nhánh refactor cải thiện nền tảng nhưng chưa hoàn tất các hạng mục sau:

1. Chưa có validation đầy đủ trước mọi thao tác ghi; nhiều form vẫn chủ yếu kiểm tra non-empty.
2. ACL và NAT vẫn dùng backend stub; Interface có local CRUD qua `DhcpSlotsMixin` nhưng chưa có workflow preview/push riêng. Cả ba nhóm chưa có capability banner/read-only state thống nhất.
3. Các collection lớn dùng `Repeater` ở Static/OSPF/EIGRP chưa được chuyển có chọn lọc sang `ListView`/`TableView` và chưa benchmark 1.000 row.
4. Chưa có số đo startup time, object count, peak RSS, thời gian mở feature hay FPS; mọi kết luận hiệu suất trong báo cáo này vì vậy là đánh giá kiến trúc, không phải kết quả benchmark.
5. Responsive layout, DPI 150/200%, keyboard/focus, i18n và visual regression vẫn là backlog.
6. Các component chết/rỗng mới chỉ được ghi chú/deprecate, chưa có migration và removal hoàn chỉnh.

## 5. Đánh giá cuối cùng

So với `frontend-beta`, `refactor/fronend-beta` là một bước cải thiện có giá trị về **correctness, lifecycle và nền tảng kiểm thử**, không phải một lần thay đổi lớn về phong cách hình ảnh.

Các lợi ích đáng chú ý nhất là:

- Tránh khởi tạo sớm nhiều view/form không được sử dụng.
- Sửa lỗi contract NAT tại biên QML/Python.
- Lưu trạng thái cửa sổ thật sự qua nhiều lần chạy.
- Chuẩn hóa cách nhập subnet/wildcard trên nhiều feature.
- Thêm test bảo vệ các hành vi mới và tài liệu hóa backlog UI.

Nhánh phù hợp để tiếp tục làm nền cho beta, với điều kiện không diễn giải lazy-load là “đã tối ưu xong” hoặc `StandardNetworkField` là “đã validate đầy đủ”. Bước tiếp theo có giá trị nhất là đo benchmark trước/sau, hoàn thiện validation submit và làm rõ capability của các màn hình còn dùng stub.

Kế hoạch tiếp tục từ các giới hạn trên được tách thành [UI_PATTERN_SYSTEM.md](UI_PATTERN_SYSTEM.md), [FEATURE_UI_DESIGN_PLAN.md](FEATURE_UI_DESIGN_PLAN.md) và [CONTINUATION_ROADMAP.md](CONTINUATION_ROADMAP.md).
