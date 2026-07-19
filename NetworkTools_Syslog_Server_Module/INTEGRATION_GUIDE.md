# Hướng dẫn tích hợp bundle Syslog Server

Bundle này chứa các file module mới. Hãy tích hợp trên một branch riêng và chạy test hồi quy trước khi merge.

## 1. Chép file

Chép toàn bộ thư mục `app/` trong bundle đè theo cấu trúc repository. Các file trong bundle đều là file mới; không chủ ý thay thế module cũ.

## 2. Build database

File `app/database/info_collected/12_info_syslog.sql` được builder hiện tại tự ghép. Với DB thử nghiệm:

```bash
cd app
python database/build_databases.py
```

Backup `info_collected.db` trước. Builder hiện tại rebuild database, không phải migration runner.

## 3. Nối backend vào `app/main.py`

Thêm import:

```python
from backend.syslog_server import SyslogManager
```

Sau khi tạo các manager hiện có:

```python
syslog_manager = SyslogManager()
app.aboutToQuit.connect(syslog_manager.shutdown)
```

Đăng ký hai context properties:

```python
context.setContextProperty("syslogManager", syslog_manager)
context.setContextProperty("syslogSettings", syslog_manager.settings)
```

Sau khi QML load, nếu muốn auto-start:

```python
if syslog_manager.settings.enabledOnStartup:
    syslog_manager.startServer()
```

## 4. Đăng ký QML trong `app/UI/qmldir`

```text
SyslogWorkspace 1.0 qml/syslog/SyslogWorkspace.qml
SyslogControlBar 1.0 qml/syslog/SyslogControlBar.qml
SyslogFilterBar 1.0 qml/syslog/SyslogFilterBar.qml
SyslogLogTable 1.0 qml/syslog/SyslogLogTable.qml
SyslogLogRow 1.0 qml/syslog/SyslogLogRow.qml
SyslogMessageDetails 1.0 qml/syslog/SyslogMessageDetails.qml
SyslogServerSettings 1.0 qml/syslog/SyslogServerSettings.qml
SyslogDevicesPanel 1.0 qml/panels/SyslogDevicesPanel.qml
SyslogDeviceItem 1.0 qml/sidebar/syslog/SyslogDeviceItem.qml
SyslogDeviceContextMenu 1.0 qml/sidebar/syslog/SyslogDeviceContextMenu.qml
```

## 5. Thêm Activity Bar item

Trong top group của `ActivityBar.qml`, thêm item mới với index không trùng index hiện có:

```qml
ActivityBarItem {
    iconSource: AppAssets.resource("resources/activitybar/syslog.svg")
    tooltipText: "Syslog Server"
    isActive: activityBar.appMode === "syslog"
    onClicked: activityBar.handleItemClick(3, "syslog")
}
```

Nên chuyển logic `isActive` của các item về kiểm tra `appMode` để tránh phụ thuộc index.

## 6. Thêm Syslog panel vào `PanelSideBar.qml`

Thêm signal:

```qml
signal syslogHostSelected(string host)
```

Trong `currentIndex`, ánh xạ `syslog` tới index mới. Thêm child:

```qml
SyslogDevicesPanel {
    Layout.fillWidth: true
    Layout.fillHeight: true
    onHostSelected: host => panelSideBar.syslogHostSelected(host)
}
```

## 7. Chọn workspace trong `Main.qml`

Ẩn ba thành phần Device khi ở Syslog:

```qml
DeviceTabs { visible: root.isDeviceMode && tabCount > 0 }
FeatureBar { visible: root.isDeviceMode && deviceTabs.tabCount > 0 }
ContentArea { visible: activityBar.appMode !== "syslog" }
```

Đặt `ContentArea` và `SyslogWorkspace` trong một `StackLayout` hoặc Item cùng anchors. Ví dụ phần Syslog:

```qml
SyslogWorkspace {
    id: syslogWorkspace
    Layout.fillWidth: true
    Layout.fillHeight: true
    visible: activityBar.appMode === "syslog"
}
```

Kết nối host chọn từ panel:

```qml
PanelSideBar {
    onSyslogHostSelected: host => syslogWorkspace.selectedHost = host
}
```

Không sửa `DeviceContextMenu.qml`; Syslog đã có menu riêng đúng hai action.

## 8. Thêm Settings

Trong `SettingsPanel.qml`, thêm:

```qml
{ "key": "syslog_server", "title": "Syslog Server", "desc": "TCP/UDP listener, server IP, port and retention" }
```

Trong `SettingsView.qml`, thêm nhánh hiển thị:

```qml
SyslogServerSettings {
    anchors.fill: parent
    visible: settingsView.activeSettingKey === "syslog_server"
}
```

Điều chỉnh điều kiện placeholder để không phủ lên form mới.

## 9. Chạy kiểm tra

```bash
cd app
python -m compileall backend/syslog_server
pytest -q tests/syslog
pytest -q tests/test_qml_smoke.py
```

Kiểm tra thủ công UDP:

```bash
echo '<189>%SYS-5-CONFIG_I: Test from localhost' | nc -u 127.0.0.1 5514
```

## 10. Giới hạn bản đầu

- TCP dùng newline framing; octet-counted RFC 6587 chưa được triển khai.
- Command builder nhắm Cisco IOS/IOS-XE.
- Source IP chưa map được được lưu với `device_host = source_ip` để không mất log.
- Retention chạy khi listener khởi động; lịch chạy lại mỗi 24 giờ nên bổ sung trước production.
- Cần kiểm tra cú pháp `logging host ... transport ... port ...` trên đúng IOS image đang dùng.
