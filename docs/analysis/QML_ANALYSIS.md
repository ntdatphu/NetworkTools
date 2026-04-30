# QML ANALYSIS

## Phạm vi
- Phân tích toàn bộ file .qml trong thư mục qml/.
- Loại trừ nội dung liên quan PythonEnvManager.

## qml/app/Main.qml
- Vai trò UI: Cửa sổ chính, điều phối toàn bộ layout và luồng tương tác.
- Components used: StatefulWindow, AppMenuBar, ActivityBar, PanelSideBar, DeviceTabs, FeatureBar, ContentArea, StatusBar, Shortcut.
- Properties và bindings: sidebarVisible; binding tab/device/feature giữa PanelSideBar, DeviceTabs, ContentArea.
- Signals/events: xử lý menu actions, shortcut Ctrl+Alt+T và Ctrl+B, kết nối signal tab/device.
- Tương tác backend: dùng cli.openTerminal(), dbManager cho dữ liệu thiết bị gián tiếp qua sidebar, networkMonitor qua StatusBar.

## qml/app/StatefulWindow.qml
- Vai trò UI: Wrapper ApplicationWindow có lưu trạng thái và vị trí/kích thước cửa sổ.
- Components used: ApplicationWindow, Settings.
- Properties và bindings: normalX/Y/Width/Height, isMaximized, isFirstLaunch.
- Signals/events: onVisibilityChanged, onWidth/HeightChanged để persist state.
- Tương tác backend: Không.

## qml/app/Theme.qml
- Vai trò UI: Singleton theme cho toàn hệ giao diện.
- Components used: QtObject singleton.
- Properties và bindings: color palette, font, spacing, duration animation, themeMode, isDarkMode.
- Signals/events: Không có signal custom, chủ yếu binding reactive.
- Tương tác backend: Không.

## qml/content/ContentArea.qml
- Vai trò UI: Router hiển thị nội dung chính theo appMode và feature đang chọn.
- Components used: WelcomeScreen, RoutingView, DhcpView, LogsAlertsView, SettingsView.
- Properties và bindings: tabCount, activeMainFeature, activeTextFeature, currentHostIp, appMode.
- Signals/events: thay đổi hiển thị theo mode/tab/feature.
- Tương tác backend: Không trực tiếp; nhận dữ liệu qua props từ Main/DeviceTabs.

## qml/content/WelcomeScreen.qml
- Vai trò UI: Màn hình chào khi chưa mở tab thiết bị.
- Components used: Rectangle, Column, Text, Image/Button.
- Properties và bindings: màu/typography theo Theme.
- Signals/events: UI hint và interaction cơ bản.
- Tương tác backend: Không.

## qml/content/LogsAlertsView.qml
- Vai trò UI: Khung Logs/Alerts dạng placeholder.
- Components used: ColumnLayout, Rectangle tab selector, Text.
- Properties và bindings: activeTab.
- Signals/events: click tab để đổi view.
- Tương tác backend: Không.

## qml/content/SettingsView.qml
- Vai trò UI: Khung Settings nhiều mục (Theme, General, Advanced).
- Components used: Layout cơ bản bằng Rectangle/ColumnLayout/MouseArea/Text.
- Properties và bindings: selected setting section, màu theo Theme.
- Signals/events: click menu trái để đổi panel phải.
- Tương tác backend: Không.

## qml/devices/DeviceTabs.qml
- Vai trò UI: Quản lý tab thiết bị, chọn tab active, lưu/khôi phục tab state.
- Components used: ListView, ListModel, Settings, DeviceTabItem.
- Properties và bindings: activeUid, tabCount, currentFMain, currentFText, activeHistory.
- Signals/events: activeTabChanged, tabRestored, openNewDeviceRequested; xử lý open/select/close/reorder tab.
- Tương tác backend: Không trực tiếp (state lưu bằng Settings cục bộ).

## qml/devices/DeviceTabItem.qml
- Vai trò UI: Delegate cho mỗi tab thiết bị.
- Components used: Rectangle, Text, Button, DragHandler, DropArea.
- Properties và bindings: tabTitle, isActive, tabIndex.
- Signals/events: selectRequested, closeRequested, moveRequested.
- Tương tác backend: Không.

## qml/dhcp/DhcpView.qml
- Vai trò UI: Container tab cho nghiệp vụ DHCP.
- Components used: DhcpSubBar, DhcpPoolForm, DhcpExcludedForm.
- Properties và bindings: currentTab, currentHostIp.
- Signals/events: đổi tab Info/Pool/Excluded Address.
- Tương tác backend: truyền currentHostIp cho form con.

## qml/dhcp/DhcpSubBar.qml
- Vai trò UI: Thanh tab con cho DHCP.
- Components used: Repeater, Rectangle, Text, TapHandler/HoverHandler.
- Properties và bindings: tabs, activeTab.
- Signals/events: tabClicked(tabName).
- Tương tác backend: Không.

## qml/dhcp/DhcpPoolForm.qml
- Vai trò UI: Form nhập DHCP pool và danh sách pool hiện có.
- Components used: SplitView, TextField, ListView, ScrollView, Button.
- Properties và bindings: currentHostIp, poolListModel, nhiều field input.
- Signals/events: reload theo onCurrentHostIpChanged, add/delete pool.
- Tương tác backend: dbManager.getDhcpPools(), dbManager.addDhcpPool(), dbManager.deleteDhcpPool().

## qml/dhcp/DhcpExcludedForm.qml
- Vai trò UI: Form quản lý dải IP excluded.
- Components used: SplitView, TextField, ListView, Button.
- Properties và bindings: currentHostIp, excludedListModel, start/end IP.
- Signals/events: reload theo host, add/delete excluded range.
- Tương tác backend: dbManager.getExcludedAddresses(), dbManager.addExcludedAddress(), dbManager.deleteExcludedAddress().

## qml/feature/FeatureBar.qml
- Vai trò UI: Thanh chọn feature 2 tầng (main feature + text feature).
- Components used: MainFeatureItem, TextFeatureItem, FeatureDropdown, Repeater, ListView.
- Properties và bindings: mainFeatures, textFeatures, activeMain, activeText.
- Signals/events: userChangedFeature(mIdx, tIdx), xử lý chọn feature và dropdown.
- Tương tác backend: Không trực tiếp.

## qml/feature/FeatureDropdown.qml
- Vai trò UI: Dropdown hiển thị feature bị ẩn do thiếu chiều rộng.
- Components used: Rectangle, ListView, delegate item.
- Properties và bindings: hiddenFeatures, visible.
- Signals/events: featureSelected(globalIndex), show/hide.
- Tương tác backend: Không.

## qml/feature/MainFeatureItem.qml
- Vai trò UI: Item icon cho nhóm feature chính.
- Components used: Button, HoverHandler, TapHandler, ToolTip, Timer.
- Properties và bindings: iconSource, tooltipText, isActive, isFlashing.
- Signals/events: clicked(); triggerFlash().
- Tương tác backend: Không.

## qml/feature/TextFeatureItem.qml
- Vai trò UI: Item text cho feature phụ.
- Components used: Text, Rectangle underline, MouseArea/TapHandler.
- Properties và bindings: label, isActive.
- Signals/events: clicked().
- Tương tác backend: Không.

## qml/layout/ActivityBar.qml
- Vai trò UI: Thanh điều hướng dọc kiểu VS Code.
- Components used: ActivityBarItem (repeater), Rectangle divider.
- Properties và bindings: activeIndex, appMode mapping.
- Signals/events: nhận clicked từ item để đổi mode.
- Tương tác backend: Không.

## qml/layout/ActivityBarItem.qml
- Vai trò UI: Nút icon trong ActivityBar.
- Components used: Button, HoverHandler, TapHandler, ToolTip.
- Properties và bindings: iconSource, tooltipText, isActive.
- Signals/events: clicked().
- Tương tác backend: Không.

## qml/layout/AppMenuBar.qml
- Vai trò UI: Native menu bar (File/View/Device/Tools/Help).
- Components used: Qt.labs.platform MenuBar/Menu/MenuItem.
- Properties và bindings: sidebarVisible và trạng thái checked của menu item.
- Signals/events: newDeviceRequested, refreshDevicesRequested, toggleSidebarRequested, openTerminalRequested, showAboutRequested và các action liên quan menu.
- Tương tác backend: Không trực tiếp, phát signal để Main xử lý.

## qml/layout/StatusBar.qml
- Vai trò UI: Thanh trạng thái cuối màn hình, hiển thị message và network status.
- Components used: Rectangle, RowLayout, SequentialAnimation, Text, Image/Button.
- Properties và bindings: message/icon/type, binding network icon/text theo networkMonitor, hiển thị thêm RAM %, ngày (dd/MM/yyyy) và giờ.
- Signals/events: hàm showMessage(msg, type), animation tự fade.
- Tương tác backend: đọc properties từ networkMonitor (isConnected, connectionType, networkName, ramUsagePercent).

## qml/routing/RoutingView.qml
- Vai trò UI: Container tab cho chức năng Routing.
- Components used: RoutingSubBar, StaticRoutingForm, OspfRoutingForm, EigrpRoutingForm.
- Properties và bindings: currentTab, currentHostIp (được truyền từ ContentArea).
- Signals/events: đổi tab Info/Static/OSPF/EIGRP/BGP.
- Tương tác backend: Không trực tiếp.

## qml/routing/RoutingSubBar.qml
- Vai trò UI: Thanh tab con cho Routing.
- Components used: Repeater, Rectangle, Text, TapHandler/HoverHandler.
- Properties và bindings: tabs, activeTab.
- Signals/events: tabClicked(tabName).
- Tương tác backend: Không.

## qml/routing/BaseProcessCard.qml
- Vai trò UI: Template card dùng chung cho OSPF/EIGRP process.
- Components used: ColumnLayout, TextField, ListModel/ListView, controls cho network/metric.
- Properties và bindings: processIndex, showArea, extraControls, processId/routerId/ad/networks.
- Signals/events: removeRequested(), event thêm/xóa network row.
- Tương tác backend: Không.

## qml/routing/static/StaticRoutingForm.qml
- Vai trò UI: Root form cấu hình static route và default route; quản lý logic save/load/validate.
- Components used: `StaticRoutingDefaultCard`, `StaticRoutingRoutesCard`, `StaticRoutingValidationDialog`, ScrollView, ColumnLayout, ListModel.
- Properties và bindings:
  - `routeModel`: ListModel cho các static route.
  - `loadedDefaultRouteText` / `loadedStaticRoutesSignature`: snapshot dữ liệu đã load để so sánh thay đổi thực.
  - `hasPendingLocalChanges`: true khi có thay đổi chưa save.
  - `defaultRouteEnabled`: bật/tắt hiển thị ô nhập default route.
- Hàm logic chính: `hasDefaultChanges`, `hasStaticChanges`, `canSaveDefaultOnly`, `canSaveStaticOnly`, `refreshDirtyFlag`, `cancelDefaultChanges`, `saveDefaultOnly`, `saveStaticOnly`, `loadFromDatabase`.
- Tương tác backend: `dbManager.getStaticRouting`, `dbManager.saveStaticRouting`.

## qml/routing/static/StaticRoutingDefaultCard.qml
- Vai trò UI: Card nhập Default Route. Enter = Save Default, Cancel revert, Save disable khi chưa đổi.
- Properties: `form`, `routeText` (alias), `canSaveDefault`.
- Tương tác backend: thông qua `form`.

## qml/routing/static/StaticRoutingRoutesCard.qml
- Vai trò UI: Card danh sách Static Routes. Save disable khi chưa đổi; Enter trong ô row = Save Static (nếu có thay đổi).
- Properties: `form`, `routeModel`, `canSaveStatic`.
- Tương tác backend: thông qua `form`.

## qml/routing/static/StaticRouteRow.qml
- Vai trò UI: Delegate dòng static route với 4 ô nhập và nút Change/Cancel/Delete.
- Signal quan trọng: `submitRequested` — phát khi Enter trong bất kỳ ô nào.
- Tương tác backend: Không trực tiếp.

## qml/routing/static/StaticRoutingValidationDialog.qml
- Vai trò UI: Dialog modal báo thiếu field bắt buộc khi add/save static route.
- Properties: `form` (đọc `showValidationDialog`, `validationMessage`).
- Tương tác backend: Không.

## qml/routing/ospf/OspfRoutingForm.qml
- Vai trò UI: Quản lý danh sách OSPF process.
- Components used: ScrollView, Repeater, OspfProcessCard, footer actions.
- Properties và bindings: processModel, title.
- Signals/events: add process, remove process, Push Config (placeholder).
- Tương tác backend: Không trực tiếp.

## qml/routing/ospf/OspfProcessCard.qml
- Vai trò UI: Card OSPF kế thừa BaseProcessCard.
- Components used: BaseProcessCard + control bổ sung của OSPF.
- Properties và bindings: showArea=true, extraControls cho options OSPF.
- Signals/events: kế thừa removeRequested và event input từ base.
- Tương tác backend: Không.

## qml/routing/eigrp/EigrpRoutingForm.qml
- Vai trò UI: Quản lý danh sách EIGRP process.
- Components used: ScrollView, Repeater, EigrpProcessCard, footer actions.
- Properties và bindings: processModel, title.
- Signals/events: add/remove process, Push Config (placeholder).
- Tương tác backend: Không trực tiếp.

## qml/routing/eigrp/EigrpProcessCard.qml
- Vai trò UI: Card EIGRP kế thừa BaseProcessCard.
- Components used: BaseProcessCard + options Default/Auto-Summary.
- Properties và bindings: showArea=false, extraControls riêng EIGRP.
- Signals/events: kế thừa removeRequested và input events.
- Tương tác backend: Không.

## qml/shared/CustomAlert.qml
- Vai trò UI: Cửa sổ cảnh báo/confirm dạng custom.
- Components used: Window, ColumnLayout, Rectangle, Text, Button, DragHandler.
- Properties và bindings: titleText, messageText, isError, active.
- Signals/events: accepted(), openAlert().
- Tương tác backend: Không.

## qml/shared/ResizeHandles.qml
- Vai trò UI: Bộ handles resize cửa sổ theo mọi cạnh/góc.
- Components used: DragHandler, HoverHandler cho 8 vùng.
- Properties và bindings: cursorShape theo cạnh/góc.
- Signals/events: gọi root.startSystemResize(edge) khi kéo.
- Tương tác backend: Không.

## qml/sidebar/PanelSideBar.qml
- Vai trò UI: Sidebar quản lý danh sách thiết bị theo trạng thái.
- Components used: SideBarHeader, SideBarSearch, FilterDropdown, DeviceSection, DeviceContextMenu, NewDevice, CustomAlert.
- Properties và bindings: allDevices, selectedSection/index, showIp, hasActiveTabs; filter/search bindings. Sidebar không còn tự giảm opacity khi đóng hết tab.
- Signals/events: deviceSelected(ip, name), deviceDeleted(ip), edit/delete/ping context menu; với host waiting có them `Up (Admin)` + `Connec`, với host connected có thêm `Down (Admin)` + `Add Yangcfg`.
- Tương tác backend: dbManager.getDevices(), dbManager.getDeviceByHost(), dbManager.deleteDevice(), dbManager.updateDeviceSuccess(), dbManager.addYangcfg(); gọi cli.pingHost() khi ping và cli.printConnec() cho hành động connec.

## qml/sidebar/devices/DeviceSection.qml
- Vai trò UI: Nhóm thiết bị collapsible theo trạng thái.
- Components used: Repeater + DeviceItem.
- Properties và bindings: sectionTitle, expanded, devices, selectedIndex, showIp.
- Signals/events: deviceClicked(index), deviceRightClicked(ip, status, mx, my).
- Tương tác backend: Không trực tiếp.

## qml/sidebar/devices/DeviceItem.qml
- Vai trò UI: Dòng item thiết bị trong sidebar.
- Components used: Rectangle, Text, TapHandler, HoverHandler, ToolTip.
- Properties và bindings: deviceName, deviceIp, status, isSelected, showIp.
- Signals/events: clicked(), rightClicked(ip, mx, my).
- Tương tác backend: Không.

## qml/sidebar/devices/DeviceContextMenu.qml
- Vai trò UI: Context menu khi right-click thiết bị.
- Components used: Rectangle, Column, item menu custom.
- Properties và bindings: targetIp, targetStatus, visible, vị trí openAt.
- Signals/events: editRequested(ip), pingRequested(ip), deleteRequested(ip), upAdminRequested(ip), downAdminRequested(ip), connecRequested(ip), addYangcfgRequested(ip).
- Quy tắc tương tác: Ping chỉ bật khi targetStatus là connected (`success = 1`); nếu targetStatus là waiting (`success = 0`) thì hiển thị thêm `Up (Admin)` và `Connec`; nếu targetStatus là connected thì hiển thị thêm `Down (Admin)` và `Add Yangcfg`; click ngoài menu sẽ tự đóng.
- Ghi chú: Các mục có hậu tố `(Admin)` là tính năng dành cho developer trong quá trình phát triển/kiểm thử.
- Tương tác backend: Không trực tiếp (parent xử lý signal).

## qml/sidebar/new_device/AddYangcfg.qml
- Vai trò UI: Form thêm credential vào bảng `yangcfg` cho host đã chọn.
- Components used: Window, DeviceFormInput, CustomAlert, Shortcut.
- Properties và bindings: hostIp read-only, username/password fields, theme nhất quán với NewDevice.
- Signals/events: yangcfgAdded(hostIp), Enter/Escape shortcuts, validate + submit.
- Tương tác backend: gọi `dbManager.addYangcfg(host, username, password, success)`.

## qml/sidebar/header_search/SideBarHeader.qml
- Vai trò UI: Header phần Devices với nút Filter/Refresh/Add.
- Components used: Rectangle, Button, ToolTip.
- Properties và bindings: isFilterActive.
- Signals/events: filterClicked(), refreshClicked(), addClicked().
- Tương tác backend: Không trực tiếp.

## qml/sidebar/header_search/SideBarSearch.qml
- Vai trò UI: Ô tìm kiếm thiết bị.
- Components used: Rectangle, TextInput, icon/button.
- Properties và bindings: alias text, border đổi theo focus.
- Signals/events: textChanged từ TextInput.
- Tương tác backend: Không trực tiếp.

## qml/sidebar/header_search/FilterDropdown.qml
- Vai trò UI: Dropdown filter theo status/type thiết bị.
- Components used: Rectangle, ListView, custom checkbox rows.
- Properties và bindings: activeStatusFilters, activeTypeFilters.
- Signals/events: filtersChanged(), toggle().
- Tương tác backend: Không.

## qml/sidebar/new_device/NewDevice.qml
- Vai trò UI: Window thêm/sửa thiết bị.
- Components used: Window, DeviceFormInput, ProtocolComboBox, CustomAlert, Shortcut.
- Properties và bindings: isEditMode, editDeviceData, fields name/host/port/user/pass.
- Signals/events: deviceAdded(data), deviceEdited(originalIp, data), Enter/Escape shortcuts.
- Tương tác backend: dbManager.addDevice(), dbManager.updateDevice(), dbManager.createFoldersFromDevices().

## qml/sidebar/new_device/DeviceFormInput.qml
- Vai trò UI: Component input tái sử dụng có label.
- Components used: RowLayout, Text, TextField.
- Properties và bindings: labelText, text alias, placeholder, echoMode, readOnly, validator.
- Signals/events: kế thừa sự kiện TextField.
- Tương tác backend: Không.

## qml/sidebar/new_device/ProtocolComboBox.qml
- Vai trò UI: Combo chọn protocol và tự động gợi ý port.
- Components used: ComboBox.
- Properties và bindings: isEditMode, model protocols.
- Signals/events: portAutoChanged(port), onCurrentTextChanged.
- Tương tác backend: Không.

## Tổng hợp tương tác backend trong QML
- dbManager: dùng mạnh ở PanelSideBar, NewDevice, DhcpPoolForm, DhcpExcludedForm.
- cli: dùng trong Main và PanelSideBar (open terminal, ping host).
- networkMonitor: dùng trong StatusBar để phản ánh trạng thái mạng.
- Các nhóm Routing hiện chủ yếu là form/state UI, chưa push xuống backend trong phiên bản hiện tại.
