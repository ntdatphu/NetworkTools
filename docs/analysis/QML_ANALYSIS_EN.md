# QML ANALYSIS

## Scope
- Analyze all .qml files in the qml/ directory.
- Exclude content related to PythonEnvManager.

## qml/app/Main.qml
- UI role: Main window, orchestrates overall layout and interaction flow.
- Components used: StatefulWindow, AppMenuBar, ActivityBar, PanelSideBar, DeviceTabs, FeatureBar, ContentArea, StatusBar, Shortcut.
- Properties and bindings: sidebarVisible; tab/device/feature bindings among PanelSideBar, DeviceTabs, and ContentArea.
- Signals/events: handles menu actions, Ctrl+Alt+T and Ctrl+B shortcuts, and tab/device signal wiring.
- Backend interaction: uses cli.openTerminal(), uses dbManager indirectly for device data via sidebar, uses networkMonitor via StatusBar.

## qml/app/StatefulWindow.qml
- UI role: ApplicationWindow wrapper with persisted window state and geometry.
- Components used: ApplicationWindow, Settings.
- Properties and bindings: normalX/Y/Width/Height, isMaximized, isFirstLaunch.
- Signals/events: onVisibilityChanged, onWidth/HeightChanged to persist state.
- Backend interaction: None.

## qml/app/Theme.qml
- UI role: Theme singleton for the entire UI system.
- Components used: QtObject singleton.
- Properties and bindings: color palette, font, spacing, animation duration, themeMode, isDarkMode.
- Signals/events: no custom signals, mainly reactive bindings.
- Backend interaction: None.

## qml/content/ContentArea.qml
- UI role: Router that displays main content based on appMode and selected feature.
- Components used: WelcomeScreen, RoutingView, DhcpView, LogsAlertsView, SettingsView.
- Properties and bindings: tabCount, activeMainFeature, activeTextFeature, currentHostIp, appMode.
- Signals/events: view switching by mode/tab/feature.
- Backend interaction: no direct backend call; receives data via props from Main/DeviceTabs.

## qml/content/WelcomeScreen.qml
- UI role: Welcome screen when no device tab is open.
- Components used: Rectangle, Column, Text, Image/Button.
- Properties and bindings: color/typography driven by Theme.
- Signals/events: basic UI hints and interaction.
- Backend interaction: None.

## qml/content/LogsAlertsView.qml
- UI role: Logs/Alerts placeholder view.
- Components used: ColumnLayout, tab selector Rectangle, Text.
- Properties and bindings: activeTab.
- Signals/events: tab click to switch views.
- Backend interaction: None.

## qml/content/SettingsView.qml
- UI role: Settings view with multiple sections (Theme, General, Advanced).
- Components used: basic layout with Rectangle/ColumnLayout/MouseArea/Text.
- Properties and bindings: selected settings section, Theme-based colors.
- Signals/events: left menu click to switch right panel.
- Backend interaction: None.

## qml/devices/DeviceTabs.qml
- UI role: Manages device tabs, active selection, and tab state save/restore.
- Components used: ListView, ListModel, Settings, DeviceTabItem.
- Properties and bindings: activeUid, tabCount, currentFMain, currentFText, activeHistory.
- Signals/events: activeTabChanged, tabRestored, openNewDeviceRequested; handles open/select/close/reorder tab actions.
- Backend interaction: no direct backend interaction (state persisted via local Settings).

## qml/devices/DeviceTabItem.qml
- UI role: Delegate for each device tab.
- Components used: Rectangle, Text, Button, DragHandler, DropArea.
- Properties and bindings: tabTitle, isActive, tabIndex.
- Signals/events: selectRequested, closeRequested, moveRequested.
- Backend interaction: None.

## qml/dhcp/DhcpView.qml
- UI role: Tab container for DHCP functionality.
- Components used: DhcpSubBar, DhcpPoolForm, DhcpExcludedForm.
- Properties and bindings: currentTab, currentHostIp.
- Signals/events: switches Info/Pool/Excluded Address tabs.
- Backend interaction: passes currentHostIp to child forms.

## qml/dhcp/DhcpSubBar.qml
- UI role: DHCP sub-tab bar.
- Components used: Repeater, Rectangle, Text, TapHandler/HoverHandler.
- Properties and bindings: tabs, activeTab.
- Signals/events: tabClicked(tabName).
- Backend interaction: None.

## qml/dhcp/DhcpPoolForm.qml
- UI role: Form for DHCP pool input and existing pool list.
- Components used: SplitView, TextField, ListView, ScrollView, Button.
- Properties and bindings: currentHostIp, poolListModel, multiple input fields.
- Signals/events: reload on onCurrentHostIpChanged, add/delete pool.
- Backend interaction: dbManager.getDhcpPools(), dbManager.addDhcpPool(), dbManager.deleteDhcpPool().

## qml/dhcp/DhcpExcludedForm.qml
- UI role: Form for excluded IP range management.
- Components used: SplitView, TextField, ListView, Button.
- Properties and bindings: currentHostIp, excludedListModel, start/end IP.
- Signals/events: reload by host, add/delete excluded range.
- Backend interaction: dbManager.getExcludedAddresses(), dbManager.addExcludedAddress(), dbManager.deleteExcludedAddress().

## qml/feature/FeatureBar.qml
- UI role: Two-layer feature selector bar (main feature + text feature).
- Components used: MainFeatureItem, TextFeatureItem, FeatureDropdown, Repeater, ListView.
- Properties and bindings: mainFeatures, textFeatures, activeMain, activeText.
- Signals/events: userChangedFeature(mIdx, tIdx), handles feature selection and dropdown behavior.
- Backend interaction: No direct backend interaction.

## qml/feature/FeatureDropdown.qml
- UI role: Dropdown that shows hidden features when width is insufficient.
- Components used: Rectangle, ListView, item delegate.
- Properties and bindings: hiddenFeatures, visible.
- Signals/events: featureSelected(globalIndex), show/hide.
- Backend interaction: None.

## qml/feature/MainFeatureItem.qml
- UI role: Icon item for the main feature group.
- Components used: Button, HoverHandler, TapHandler, ToolTip, Timer.
- Properties and bindings: iconSource, tooltipText, isActive, isFlashing.
- Signals/events: clicked(); triggerFlash().
- Backend interaction: None.

## qml/feature/TextFeatureItem.qml
- UI role: Text item for secondary features.
- Components used: Text, underline Rectangle, MouseArea/TapHandler.
- Properties and bindings: label, isActive.
- Signals/events: clicked().
- Backend interaction: None.

## qml/layout/ActivityBar.qml
- UI role: VS Code-style vertical navigation bar.
- Components used: ActivityBarItem (repeater), divider Rectangle.
- Properties and bindings: activeIndex, appMode mapping.
- Signals/events: receives clicked from item to switch mode.
- Backend interaction: None.

## qml/layout/ActivityBarItem.qml
- UI role: Icon button in ActivityBar.
- Components used: Button, HoverHandler, TapHandler, ToolTip.
- Properties and bindings: iconSource, tooltipText, isActive.
- Signals/events: clicked().
- Backend interaction: None.

## qml/layout/AppMenuBar.qml
- UI role: Native menu bar (File/View/Device/Tools/Help).
- Components used: Qt.labs.platform MenuBar/Menu/MenuItem.
- Properties and bindings: sidebarVisible and checked states of menu items.
- Signals/events: newDeviceRequested, refreshDevicesRequested, toggleSidebarRequested, openTerminalRequested, showAboutRequested, and related menu actions.
- Backend interaction: no direct backend call; emits signals for Main to handle.

## qml/layout/StatusBar.qml
- UI role: Bottom status bar displaying messages and network status.
- Components used: Rectangle, RowLayout, SequentialAnimation, Text, Image/Button.
- Properties and bindings: message/icon/type, network icon/text binding via networkMonitor.
- Signals/events: showMessage(msg, type) function, auto-fade animation.
- Backend interaction: reads properties from networkMonitor (isConnected, connectionType, networkName).

## qml/routing/RoutingView.qml
- UI role: Tab container for Routing features.
- Components used: RoutingSubBar, StaticRoutingForm, OspfRoutingForm, EigrpRoutingForm.
- Properties and bindings: currentTab.
- Signals/events: switches Info/Static/OSPF/EIGRP/BGP tabs.
- Backend interaction: No direct backend interaction.

## qml/routing/RoutingSubBar.qml
- UI role: Routing sub-tab bar.
- Components used: Repeater, Rectangle, Text, TapHandler/HoverHandler.
- Properties and bindings: tabs, activeTab.
- Signals/events: tabClicked(tabName).
- Backend interaction: None.

## qml/routing/BaseProcessCard.qml
- UI role: Shared process card template for OSPF/EIGRP.
- Components used: ColumnLayout, TextField, ListModel/ListView, controls for network/metric.
- Properties and bindings: processIndex, showArea, extraControls, processId/routerId/ad/networks.
- Signals/events: removeRequested(), add/remove network row events.
- Backend interaction: None.

## qml/routing/static/StaticRoutingForm.qml
- UI role: Root form orchestrating Static/Default route configuration, save/load/validate logic.
- Components used: `StaticRoutingDefaultCard`, `StaticRoutingRoutesCard`, `StaticRoutingValidationDialog`, ScrollView, ColumnLayout, ListModel.
- Properties and bindings:
  - `routeModel`: ListModel for static routes.
  - `loadedDefaultRouteText` / `loadedStaticRoutesSignature`: loaded-data snapshots for change detection.
  - `hasPendingLocalChanges`: true when unsaved changes exist (driven by `refreshDirtyFlag()`).
  - `defaultRouteEnabled`: toggles default route input visibility.
- Key functions: `hasDefaultChanges`, `hasStaticChanges`, `canSaveDefaultOnly`, `canSaveStaticOnly`, `refreshDirtyFlag`, `cancelDefaultChanges`, `saveDefaultOnly`, `saveStaticOnly`, `loadFromDatabase`.
- Backend interaction: `dbManager.getStaticRouting(host)`, `dbManager.saveStaticRouting(host, defaultRoute, routes)`.

## qml/routing/static/StaticRoutingDefaultCard.qml
- UI role: Default route input card. Enter = Save Default; Cancel reverts; Save disabled when unchanged.
- Properties: `form`, `routeText` (alias), `canSaveDefault`.
- Backend interaction: via `form`.

## qml/routing/static/StaticRoutingRoutesCard.qml
- UI role: Static routes list card. Save disabled when unchanged; Enter in any row field triggers Save Static.
- Properties: `form`, `routeModel`, `canSaveStatic`.
- Backend interaction: via `form`.

## qml/routing/static/StaticRouteRow.qml
- UI role: Single static route row delegate with 4 input fields and Change/Cancel/Delete buttons.
- Key signal: `submitRequested` — emitted on Enter in any field.
- Backend interaction: None (delegate only).

## qml/routing/static/StaticRoutingValidationDialog.qml
- UI role: Modal dialog for missing required-field errors on add/save.
- Properties: `form` (reads `showValidationDialog`, `validationMessage`).
- Backend interaction: None.

## qml/routing/ospf/OspfRoutingForm.qml
- UI role: Manages OSPF process list.
- Components used: ScrollView, Repeater, OspfProcessCard, footer actions.
- Properties and bindings: processModel, title.
- Signals/events: add process, remove process, Push Config (placeholder).
- Backend interaction: No direct backend interaction.

## qml/routing/ospf/OspfProcessCard.qml
- UI role: OSPF card inheriting BaseProcessCard.
- Components used: BaseProcessCard + OSPF-specific additional controls.
- Properties and bindings: showArea=true, OSPF option-specific extraControls.
- Signals/events: inherits removeRequested and base input events.
- Backend interaction: None.

## qml/routing/eigrp/EigrpRoutingForm.qml
- UI role: Manages EIGRP process list.
- Components used: ScrollView, Repeater, EigrpProcessCard, footer actions.
- Properties and bindings: processModel, title.
- Signals/events: add/remove process, Push Config (placeholder).
- Backend interaction: No direct backend interaction.

## qml/routing/eigrp/EigrpProcessCard.qml
- UI role: EIGRP card inheriting BaseProcessCard.
- Components used: BaseProcessCard + Default/Auto-Summary options.
- Properties and bindings: showArea=false, EIGRP-specific extraControls.
- Signals/events: inherits removeRequested and input events.
- Backend interaction: None.

## qml/shared/CustomAlert.qml
- UI role: Custom alert/confirm window.
- Components used: Window, ColumnLayout, Rectangle, Text, Button, DragHandler.
- Properties and bindings: titleText, messageText, isError, active.
- Signals/events: accepted(), openAlert().
- Backend interaction: None.

## qml/shared/ResizeHandles.qml
- UI role: Resize handles for all window edges/corners.
- Components used: DragHandler, HoverHandler for 8 regions.
- Properties and bindings: cursorShape by edge/corner.
- Signals/events: calls root.startSystemResize(edge) on drag.
- Backend interaction: None.

## qml/sidebar/PanelSideBar.qml
- UI role: Sidebar managing device list by status.
- Components used: SideBarHeader, SideBarSearch, FilterDropdown, DeviceSection, DeviceContextMenu, NewDevice, CustomAlert.
- Properties and bindings: allDevices, selectedSection/index, showIp, hasActiveTabs; filter/search bindings.
- Signals/events: deviceSelected(ip, name), deviceDeleted(ip), edit/delete/ping context menu; ping is enabled only for connected status.
- Backend interaction: dbManager.getDevices(), dbManager.getDeviceByHost(), dbManager.deleteDevice(); calls cli.pingHost() only when ping is enabled by the menu.

## qml/sidebar/devices/DeviceSection.qml
- UI role: Collapsible device group by status.
- Components used: Repeater + DeviceItem.
- Properties and bindings: sectionTitle, expanded, devices, selectedIndex, showIp.
- Signals/events: deviceClicked(index), deviceRightClicked(ip, status, mx, my).
- Backend interaction: No direct backend interaction.

## qml/sidebar/devices/DeviceItem.qml
- UI role: Device row item in sidebar.
- Components used: Rectangle, Text, TapHandler, HoverHandler, ToolTip.
- Properties and bindings: deviceName, deviceIp, status, isSelected, showIp.
- Signals/events: clicked(), rightClicked(ip, mx, my).
- Backend interaction: None.

## qml/sidebar/devices/DeviceContextMenu.qml
- UI role: Context menu on device right-click.
- Components used: Rectangle, Column, custom menu items.
- Properties and bindings: targetIp, targetStatus, visible, openAt position.
- Signals/events: editRequested(ip), pingRequested(ip), deleteRequested(ip).
- Interaction rules: Ping is enabled only when targetStatus is connected (`success = 1`); clicking outside the menu closes it.
- Backend interaction: no direct backend interaction (handled by parent signal handlers).

## qml/sidebar/header_search/SideBarHeader.qml
- UI role: Devices header with Filter/Refresh/Add buttons.
- Components used: Rectangle, Button, ToolTip.
- Properties and bindings: isFilterActive.
- Signals/events: filterClicked(), refreshClicked(), addClicked().
- Backend interaction: No direct backend interaction.

## qml/sidebar/header_search/SideBarSearch.qml
- UI role: Device search input.
- Components used: Rectangle, TextInput, icon/button.
- Properties and bindings: text alias, focus-based border changes.
- Signals/events: textChanged from TextInput.
- Backend interaction: No direct backend interaction.

## qml/sidebar/header_search/FilterDropdown.qml
- UI role: Filter dropdown by device status/type.
- Components used: Rectangle, ListView, custom checkbox rows.
- Properties and bindings: activeStatusFilters, activeTypeFilters.
- Signals/events: filtersChanged(), toggle().
- Backend interaction: None.

## qml/sidebar/new_device/NewDevice.qml
- UI role: Add/Edit device window.
- Components used: Window, DeviceFormInput, ProtocolComboBox, CustomAlert, Shortcut.
- Properties and bindings: isEditMode, editDeviceData, name/host/port/user/pass fields.
- Signals/events: deviceAdded(data), deviceEdited(originalIp, data), Enter/Escape shortcuts.
- Backend interaction: dbManager.addDevice(), dbManager.updateDevice(), dbManager.createFoldersFromDevices().

## qml/sidebar/new_device/DeviceFormInput.qml
- UI role: Reusable labeled input component.
- Components used: RowLayout, Text, TextField.
- Properties and bindings: labelText, text alias, placeholder, echoMode, readOnly, validator.
- Signals/events: inherits TextField events.
- Backend interaction: None.

## qml/sidebar/new_device/ProtocolComboBox.qml
- UI role: Protocol selector combo with automatic port suggestion.
- Components used: ComboBox.
- Properties and bindings: isEditMode, protocols model.
- Signals/events: portAutoChanged(port), onCurrentTextChanged.
- Backend interaction: None.

## Summary of backend interactions in QML
- dbManager: heavily used in PanelSideBar, NewDevice, DhcpPoolForm, DhcpExcludedForm.
- cli: used in Main and PanelSideBar (open terminal, ping host).
- networkMonitor: used in StatusBar to reflect network status.
- Routing groups currently mostly manage form/UI state and do not yet push to backend in the current version.
