## Kế hoạch đã hoàn thành

Tôi đã soạn file Markdown để đặt tại:

```text
app/bang_ke_hach_cua_viet/KE_HOACH_REFACTOR_PANELSIDEBAR_MULTI_DEVICE_SESSION.md
```

[Download kế hoạch refactor PanelSideBar và multi-device session](sandbox:/mnt/data/KE_HOACH_REFACTOR_PANELSIDEBAR_MULTI_DEVICE_SESSION.md)

### Các vấn đề chính đã xác định

**1. Nguyên nhân chạy nhầm host**

`DevicesPanel.qml` đang lưu thiết bị được chọn bằng `selectedSection + selectedIndex`, sau đó tìm lại thiết bị từ các mảng đã lọc. Khi search, reload hoặc host chuyển trạng thái giữa Waiting/Connected/Disconnected, index cũ có thể trỏ sang host khác.

`DeviceSection.qml` cũng chỉ phát `deviceClicked(index)` thay vì phát trực tiếp IP/host, làm cho parent phải tra cứu lại bằng index không ổn định.

**2. UI đang chặn chạy nhiều thiết bị**

Các biến `isConnectRunning`, `pendingConnectIp`, `isRunningConfigRunning` và `pendingRunningConfigIp` chỉ quản lý được một host toàn cục. Khi một thiết bị đang chạy, QML chủ động chặn thiết bị khác.

**3. Backend cơ bản đã hỗ trợ task khác host chạy đồng thời**

`AsyncTaskCoordinator` tạo task riêng theo `task_key`; các key Connect và running-config đã chứa host. Vì vậy có thể mở rộng thành batch nhiều host mà không phải viết lại toàn bộ hệ thống task. Tuy nhiên cần thêm giới hạn concurrency thay vì tạo số lượng `QThread` không kiểm soát.

**4. Session registry đã giữ được nhiều host, nhưng Connect hiện đóng kết nối ngay**

Registry hiện lưu connector trong dictionary theo host nên đã có nền tảng duy trì nhiều đăng nhập cùng lúc.

Tuy nhiên, `connectHostAndSync()` vẫn tạo connector tạm và gọi `disconnect()` trong `finally`, nên thao tác Connect hiện chỉ kiểm tra, lấy cấu hình rồi đăng xuất.

Ngoài ra, `DeviceTabs.qml` đang đóng session khi đóng tab. Kế hoạch mới tách riêng vòng đời tab và vòng đời đăng nhập: đóng tab không còn đồng nghĩa Disconnect.

### Thứ tự ưu tiên

* **P0:** Đổi toàn bộ selection từ index sang host/IP để sửa dứt điểm lỗi chạy nhầm thiết bị.
* **P1:** Nâng cấp `DeviceSessionRegistry` với session state và khóa thao tác riêng cho từng host.
* **P2:** Thêm multi-selection, Batch Connect và Batch Get running-config với concurrency mặc định 5 host.
* **P3:** Thêm progress từng host, cancel batch, reconnect policy và dọn các property compatibility cũ.

File hiện mới được soạn để đưa vào `app/`; chưa có thay đổi hoặc commit nào được ghi lên repository GitHub.
