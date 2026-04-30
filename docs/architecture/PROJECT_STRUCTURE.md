# PROJECT STRUCTURE

## Phạm vi tài liệu
- Tài liệu này loại trừ toàn bộ nội dung liên quan PythonEnvManager.
- Không tìm thấy chuỗi đánh dấu "TO BE EXCLUDED FROM FUTURE DOCUMENTATION" trong workspace tại thời điểm tạo tài liệu.

## Cây thư mục tổng quan

- NetworkUI/
  - app_icon.rc
  - CMakeLists.txt
  - data.sql
  - main.cpp
  - .qmlls.ini
  - script/
    - database/
      - init_db.py
    - login/
      - ...
    - requirements.txt
  - qml/
    - app/
      - Main.qml
      - StatefulWindow.qml
      - Theme.qml
    - content/
      - ContentArea.qml
      - WelcomeScreen.qml
      - LogsAlertsView.qml
      - SettingsView.qml
    - devices/
      - DeviceTabs.qml
      - DeviceTabItem.qml
    - dhcp/
      - DhcpView.qml
      - DhcpSubBar.qml
      - DhcpPoolForm.qml
      - DhcpExcludedForm.qml
    - feature/
      - FeatureBar.qml
      - FeatureDropdown.qml
      - MainFeatureItem.qml
      - TextFeatureItem.qml
    - layout/
      - ActivityBar.qml
      - ActivityBarItem.qml
      - AppMenuBar.qml
      - StatusBar.qml
    - routing/
      - RoutingView.qml
      - RoutingSubBar.qml
      - BaseProcessCard.qml
      - static/
        - StaticRoutingForm.qml
        - StaticRouteRow.qml
        - StaticRoutingDefaultCard.qml
        - StaticRoutingRoutesCard.qml
        - StaticRoutingValidationDialog.qml
      - ospf/
        - OspfRoutingForm.qml
        - OspfProcessCard.qml
      - eigrp/
        - EigrpRoutingForm.qml
        - EigrpProcessCard.qml
    - shared/
      - CustomAlert.qml
      - ResizeHandles.qml
    - sidebar/
      - PanelSideBar.qml
      - devices/
        - DeviceSection.qml
        - DeviceItem.qml
        - DeviceContextMenu.qml
      - header_search/
        - SideBarHeader.qml
        - SideBarSearch.qml
        - FilterDropdown.qml
      - new_device/
        - NewDevice.qml
        - DeviceFormInput.qml
        - ProtocolComboBox.qml
    - appnetworkui.qmltypes
  - resources/
    - activitybar/
    - devicetabs/
    - featurebar/
    - icons/
    - sidebar/
    - statusbar/
  - src/
    - AppMenuBar.h
    - NetworkMonitor.h
    - ScriptSyncHelper.h
    - terminalhelper.h
    - VersionScriptHelper.h
    - database/
      - DatabaseManager.h/.cpp
      - DatabaseConnection.h/.cpp
      - DeviceRepository.h/.cpp
      - DhcpPoolRepository.h/.cpp
      - ExcludedAddressRepository.h/.cpp
      - BackupService.h/.cpp
      - SqlUtils.h/.cpp

## Giải thích theo thư mục

## qml/
- Chứa toàn bộ giao diện Qt Quick.
- Tổ chức theo domain UI: layout, sidebar, content, feature, routing, dhcp, shared.
- app/Main.qml là root UI, kết nối các khối chính.

## src/
- Chứa backend C++.
- Trọng tâm là lớp DatabaseManager và các repository xử lý dữ liệu SQLite.
- Các helper hệ thống gồm TerminalHelper, NetworkMonitor, ScriptSyncHelper.

## src/database/
- Tầng truy cập dữ liệu theo hướng repository.
- DatabaseConnection phụ trách mở DB và gọi script Python `script/database/init_db.py` để khởi tạo schema từ `data.sql` ở lần chạy đầu.
- BackupService tạo cây thư mục backup theo danh sách host.

## resources/
- Chứa icon SVG/ICO phục vụ giao diện.
- Được đóng gói qua CMake vào tài nguyên ứng dụng.

## Các file gốc quan trọng

## main.cpp
- Entry point của ứng dụng Qt.
- Khởi tạo QApplication, đồng bộ thư mục script, khởi tạo DB.
- Inject context property cho QML: dbManager, cli, networkMonitor.

## CMakeLists.txt
- Cấu hình build Qt 6 + QML module.
- Đăng ký source C++, QML files và resources.
- Có bước POST_BUILD copy data.sql sang thư mục output.

## data.sql
- Schema khởi tạo cơ sở dữ liệu SQLite.
- Chứa bảng thiết bị, DHCP, routing và các bảng liên quan.

## app_icon.rc
- Resource script cho Windows icon của executable.

## .qmlls.ini
- Cấu hình QML Language Server để IDE resolve import/type.

## qml/appnetworkui.qmltypes
- Metadata type cho module QML NetworkUI.
- Dùng cho tooling, autocomplete, static analysis.

## src/database/DatabaseManager.h/.cpp
- Lớp facade giữa QML và repository.
- Expose các hàm Q_INVOKABLE để QML CRUD thiết bị, DHCP pool, excluded address.

## src/database/DatabaseConnection.h/.cpp
- Tạo và mở file device_network.db trong thư mục chạy app.
- Nếu DB mới, tìm và chạy `script/database/init_db.py` (qua `QProcess`) để tạo DB từ `data.sql`.

## src/ScriptSyncHelper.h
- Đồng bộ thư mục script từ source tree về thư mục chạy app.
- So sánh versionScript.txt để quyết định copy lại.

## src/NetworkMonitor.h
- Theo dõi trạng thái mạng (connected/type/name) và phần trăm RAM, phát tín hiệu thay đổi định kỳ.

## src/terminalhelper.h
- Mở terminal hệ thống và chạy ping host từ thao tác UI.

## src/VersionScriptHelper.h
- Helper copy versionScript.txt.
- Hiện có trong codebase nhưng không thấy được gọi trong luồng khởi động hiện tại.
