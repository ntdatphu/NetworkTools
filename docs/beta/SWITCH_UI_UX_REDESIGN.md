# Thiết kế lại UX/UI cho Switch workspace

Ngày hoàn tất: **2026-07-17**. Phạm vi triển khai là `app/UI/` và test/tài liệu
liên quan; không thay đổi schema hoặc logic backend. Mục tiêu là đưa Interfaces,
Switching, Security và Monitoring về cùng ngôn ngữ thiết kế với Router nhưng vẫn
tôn trọng tác vụ L2 thay vì sao chép bố cục máy móc.

## 1. Vấn đề được xác minh

- Bốn Feature dùng bố cục khác nhau dù cùng mô hình danh sách → chi tiết.
- Port Security và Storm Control tái sử dụng bảng Interfaces nên cột Mode/VLAN
  không trả lời được policy nào đang bật, mức giới hạn hay action hiện tại.
- Security có Add, cho phép tạo port từ một màn hình lẽ ra chỉ cấu hình policy.
- Inspector lồng nhiều card/viền và biểu diễn trạng thái đọc bằng field disabled;
  thông tin dày, tương phản kém và không có hierarchy rõ.
- Monitoring để counter byte thô, gộp metric và không phân biệt error/discard.
- Loader duy nhất bị hủy/dựng lại khi đổi Feature, làm mất selection/draft và tạo
  cảm giác ứng dụng đứng ở lần mở đầu.
- Một số field đã được lưu nhưng UI chưa expose: BPDU Filter, Loop Guard, trunk
  pruning, Port Security aging và Storm Control action.

## 2. Nguyên tắc thiết kế

1. **Context trước consistency hình thức:** mọi trang dùng chung shell, nhưng cột,
   metric và section phải phản ánh đúng tác vụ hiện tại.
2. **Progressive disclosure:** mặc định đọc key/value; field chỉ xuất hiện sau Add
   hoặc Edit. Không dùng một rừng input disabled để mô tả dữ liệu.
3. **Một surface chi tiết:** inspector có một khung, section bên trong dùng khoảng
   cách/separator; tránh card lồng card.
4. **Trạng thái nhìn thấy ngay:** bốn summary metric cho biết quy mô, trạng thái và
   vấn đề trước khi người dùng đọc từng row.
5. **Action đúng ownership:** Interfaces tạo/sửa port; Security chỉ sửa policy của
   port đã tồn tại; Monitoring chỉ quan sát.
6. **Responsive và bền vững:** table/inspector nằm ngang ở workspace rộng, xếp dọc
   dưới breakpoint chung; header/row dùng primitive và token hiện có.
7. **Không trả giá hiệu năng cho tính thẩm mỹ:** trang được incubation bất đồng bộ,
   cache sau lần mở đầu và chỉ animation khi thật sự loading.

## 3. Kiến trúc giao diện chung

```text
Workspace header
  └─ Summary bar (4 chỉ số theo context)
      └─ Table toolbar (title, count, search)
          ├─ Contextual DataTable
          └─ Inspector pane
              ├─ Empty state / read-only properties
              └─ Add/Edit fields + Cancel/Save
```

Các component mới là `SwitchSummaryBar`, `SwitchTableToolbar`,
`SwitchInspectorPane`, `SwitchInspectorSection` và `SwitchPropertyRow`. Chúng nằm
trên họ `DataTable*`, `WorkspaceHeader`, `EmptyState` và control chuẩn của dự án;
không tạo một design system song song.

## 4. Thiết kế theo Feature

| Feature | Summary chính | Table/Inspector |
|---|---|---|
| Interfaces | Tổng port, link up, access, trunk | Cột Interface/Mode/VLAN Membership/Description/Link; Routed Ports và SVI dùng cùng shell theo role SW3. Inspector tách Identity, Switching và Loop Protection. |
| Switching | Tổng VLAN, active, suspended, access assignments | VLAN có search, state/usage rõ; SVI có trạng thái và IP Routing là toggle cấp workspace. Không hiển thị SubBar một mục. |
| Security | Eligible/protected/sticky/shutdown hoặc action/up | Port Security và Storm Control có schema policy riêng. Không có Add; empty state hướng người dùng sang Interfaces. Inspector expose aging/action và chỉ sửa port hiện hữu. |
| Monitoring | Ports/link/traffic/problems hoặc entries/VLAN/interfaces/dynamic | Counter hiển thị B/KB/MB/GB/TB; inbound/outbound, errors, discards và last flap tách riêng. MAC Table dùng MAC/VLAN/Interface/Type/Learned At. |

Các field persisted trước đây bị bỏ sót đã được đưa vào inspector: trunk
encapsulation/pruning, `bpdufilter`, `loop_guard`, Port Security aging type/time và
Storm Control action.

## 5. Hiệu năng và lifecycle

`SwitchWorkspace` có loader bất đồng bộ riêng cho Ports, Routed Ports, SVI, VLAN,
Port Security, Storm Control, Port Counters và MAC Table. Trang đã Ready được giữ
cache nên chuyển Feature không dựng lại component hoặc làm mất local draft và
selection. Chỉ trang active nhận host/reload; first-load được truyền lên
`isViewLoading` để Device Tab thay icon bằng spinner.

Lựa chọn này ưu tiên độ phản hồi khi đổi Feature. Giới hạn còn lại là chưa có
memory budget/dirty-aware eviction cho cache toàn ứng dụng; nội dung này tiếp tục
thuộc PERF-03 thay vì giải quyết bằng cách âm thầm hủy view.

## 6. Khả năng truy cập và thẩm mỹ

- Search dùng control chuẩn và hỗ trợ focus/keyboard mặc định.
- Action dùng hierarchy Cancel text → Secondary → Primary Save; focus ring dùng
  Accent theo contract chung.
- Status luôn có text/badge, không chỉ phụ thuộc màu.
- Địa chỉ, MAC và counter dùng font monospace đã export qua `Theme.monoFontFamily`.
- Empty state giải thích bước tiếp theo thay vì để một vùng trắng hoặc form mờ.
- Selection bảng giữ nền trung tính và chỉ dùng vạch Accent mảnh.

## 7. Kiểm chứng

- QML smoke dựng sạch toàn bộ trang Switch và Main module, không warning.
- Runtime test kiểm tra layout rộng/hẹp và cache từng Feature sau lần mở đầu.
- Contract test khóa contextual table, progressive disclosure, Security không Add,
  field persisted bị bỏ sót và định dạng Monitoring.
- Kiểm tra trực quan trên một instance phát triển riêng ở light theme cho
  Interfaces, VLAN, Port Security, Port Counters và trạng thái Add/Edit; không Save
  dữ liệu thử và không tác động instance người dùng đang mở.

## 8. Giới hạn còn lại

- Switching vẫn là desired-state local; redesign không tuyên bố đã có push L2.
- Cần thêm visual regression tự động cho nhiều DPI/theme và kiểm tra với dataset
  thiết bị thật dày hơn.
- Memory budget, dirty-aware eviction và benchmark startup/peak RAM của toàn app
  vẫn là backlog hiệu năng riêng.
