# Kiến trúc nhánh beta/refactor

Ngày cập nhật: 2026-07-14.

Tài liệu kiến trúc toàn dự án nằm tại [`../ARCHITECTURE.md`](../ARCHITECTURE.md). File này **chỉ** ghi nguyên tắc refactor beta cho ứng dụng desktop trong `app/`; nó không mô tả hoặc thay thế backend dự án ở `backend cua kien/`.

## 1. Ranh giới module

```text
QML view/component
  → core QObject/Slot bridge
    → app/backend repository/transaction
      → canonical SQLite schema

View & Push
  → core/view_push controller
    → app/network_code dispatcher/worker
      → dev report hoặc connector thật
```

- QML không viết SQL và không import Python trực tiếp.
- Slot mỏng; normalize/CRUD desktop nằm trong `app/backend/`.
- Worker không tự suy ra database theo current working directory.
- Trong phạm vi runtime desktop, schema chỉ lấy từ `app/database/schema/` và `app/database/info_collected/`. Đây không phải kết luận rằng schema riêng của `backend cua kien/` nằm ngoài dự án.
- Legacy snapshots không được dùng để “sửa nhanh” mismatch runtime.

## 2. Completion levels

| Mức | Điều kiện |
|---|---|
| L0 | Không có implementation usable. |
| L1 | Schema canonical có và build/integrity đạt. |
| L2-code | Có QML + repository local CRUD, review tĩnh khớp schema. |
| L2-tested | Có persistence/contract test đạt trên schema canonical. |
| L3 | Có dev-mode test cho preview/push và vòng đời pending. |
| L4 | Đã test trên lab/device thật, có bằng chứng môi trường. |

Không gộp L2-code, L2-tested và L3. OSPF/EIGRP hiện có local persistence contract đạt trên bảng canonical nên được ghi L2-tested; chưa ghi L3 vì chưa có test preview/push riêng cho hai protocol.

## 3. Interface families

- F1 Observe/Info: cần empty/loading/error, refresh timestamp, virtualized list.
- F2 Entity: split form/list, staged changes, Save/Cancel, dirty guard.
- F3 Policy: ordered rules, rule validation và confirm delete.
- F4 Process: ProcessCard/pinned header/section, normalize payload và transaction cha/con.
- F5 Guided Setup: dialog có validation/focus/keyboard.
- F6 Operations: terminal/DB browser/task log.
- F7 Settings: category navigator + persistent backend.

## 4. Component/lifecycle rules

1. Export component qua `UI/qmldir` chỉ khi có consumer hoặc public compatibility rõ ràng.
2. Không copy component để rename như `BaseCard`/`ProcessCard`; dùng wrapper alias tối thiểu hoặc migration dứt điểm.
3. Heavy view lazy-load ở lần đầu nhưng phải có `reloadData(reason)` và dirty-state policy.
4. Dữ liệu lớn dùng `ListView`/pagination, không dùng `Repeater` để dựng toàn bộ row.
5. Network/OS probe và SSH/DB task dài không chạy trên UI thread.
6. Validation phải có cả form và backend; input component không phải security boundary.

## 5. Contract quan trọng

### Device session

`DeviceTabs.closeTab()` gọi `cli.closeDeviceSession(host)`. Backend đóng connector và reset DB về Waiting. Cần test rõ trường hợp tab không có session, session đang chạy task và reopen tab.

### Routing interface tables

Canonical:

- `t04_router_iface_ospf` dùng `iface_id`;
- `t04_router_iface_eigrp` dùng `iface_id`.

Mọi repository loader/writer/comparator phải JOIN `t02_interface_name`. Không tạo lại `t04_ospf_interface_settings` hoặc `t04_eigrp_interface_settings` chỉ để test cũ qua.

### Background task

Mỗi task có key, không cho trùng, emit start/progress/finish và phải đóng thread/worker. Test cần kiểm tra cancel/quit và không giữ SQLite handle sau lỗi.

## 6. Nguồn theo dõi

- Trạng thái capability: [`schema.md`](schema.md).
- Backlog UI/UX cơ bản: [`PENDING_CHANGES_UI_UX.md`](PENDING_CHANGES_UI_UX.md).
- Đặc tả issue: [`CHANGES_PENDING.md`](CHANGES_PENDING.md).
- Bằng chứng audit/test: [`../CODE_AUDIT.md`](../CODE_AUDIT.md).
