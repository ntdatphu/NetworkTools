cmake_minimum_required(VERSION 3.16)

project(NetworkTools VERSION 0.1 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS
    Quick
    Network
    Sql
    QuickEffects
    LabsPlatform
    Widgets
)

qt_standard_project_setup(REQUIRES 6.8)

# Singleton Theme
set_source_files_properties(theme/Theme.qml
    PROPERTIES QT_QML_SINGLETON_TYPE TRUE
)

qt_add_executable(NetworkTools
    main.cpp
)
set(QT_QML_GENERATE_QMLLS_INI ON)

qt_add_qml_module(NetworkTools
    URI NetworkTools

    QML_FILES
        # ── theme ───────────────────────────────────────────────
        theme/Theme.qml

        # ── components ──────────────────────────────────────────
        # Base Components
        components/base/BaseCard.qml
        components/base/BaseButton.qml
        components/base/IconButton.qml
        components/base/SectionCard.qml

        # Standard Components
        components/standard/StandardCheckBox.qml
        components/standard/StandardComboBox.qml
        components/standard/StandardSpinBox.qml
        components/standard/StandardTextField.qml
        components/standard/StandardValidationDialog.qml
        components/standard/StandardDropdown.qml
        components/standard/StandardButton.qml
        components/standard/StandardBadge.qml
        components/standard/StandardSideBar.qml

        # Layout Components
        components/layout/FormLayout.qml
        components/layout/SubBar.qml

        # ── Utils ───────────────────────────────────────────────
        components/utils/ValidationUtils.js

        # ── 00_app ──────────────────────────────────────────────
        qml/app/Main.qml
        qml/app/StatefulWindow.qml

        # ── 10_shared ───────────────────────────────────────────
        qml/shared/CustomAlert.qml
        qml/shared/ResizeHandles.qml
        qml/shared/ToastManager.qml
        qml/shared/NotificationPanel.qml

        # ── 15_panels ───────────────────────────────────────────
        qml/panels/DevicesPanel.qml
        qml/panels/LogsAlertsPanel.qml
        qml/panels/PanelSideBar.qml
        qml/panels/SettingsPanel.qml

        # ── 20_layout ───────────────────────────────────────────
        qml/layout/ActivityBar.qml
        qml/layout/ActivityBarItem.qml
        qml/layout/StatusBar.qml

        # ── 25_features ─────────────────────────────────────────
        qml/feature/FeatureBar.qml
        qml/feature/MainFeatureItem.qml
        qml/feature/TextFeatureItem.qml
        qml/feature/FeatureDropdown.qml

        # ── 30_sidebar ──────────────────────────────────────────
        # Header And Search
        qml/sidebar/header_search/SideBarHeader.qml
        qml/sidebar/header_search/SideBarSearch.qml

        # Device
        qml/sidebar/devices/DeviceItem.qml
        qml/sidebar/devices/DeviceSection.qml
        qml/sidebar/devices/DeviceContextMenu.qml

        # NewDevice
        qml/sidebar/new_device/NewDevice.qml
        qml/sidebar/new_device/BatchNewDevice.qml
        qml/sidebar/new_device/AddYangcfg.qml
        qml/sidebar/new_device/DeviceFormInput.qml
        qml/sidebar/new_device/ProtocolComboBox.qml

        # ── 40_devices ──────────────────────────────────────────
        qml/devices/DeviceTabs.qml
        qml/devices/DeviceTabItem.qml

        # ── 50_content ──────────────────────────────────────────
        qml/content/ContentArea.qml
        qml/content/WelcomeScreen.qml
        qml/content/LogsAlertsView.qml
        qml/content/SettingsView.qml

        # ── 60_routing ──────────────────────────────────────────
        qml/routing/RoutingView.qml
        qml/routing/RoutingSubBar.qml

        # ── 70_dhcp ─────────────────────────────────────────────
        qml/dhcp/DhcpSubBar.qml
        qml/dhcp/DhcpPoolForm.qml
        qml/dhcp/DhcpExcludedForm.qml
        qml/dhcp/DhcpView.qml

        # ─ 80_acl ───────────────────────────────────────────────
        qml/acl/AclSubBar.qml
        qml/acl/AclRuleRow.qml
        qml/acl/AclRuleInputStandard.qml
        qml/acl/AclRuleInputExtended.qml
        qml/acl/AclRuleInputDynamic.qml
        qml/acl/AclRuleInputReflexive.qml
        qml/acl/AclRuleInputMac.qml
        qml/acl/AclForm.qml
        qml/acl/AclView.qml

        # ─ 90_nat ───────────────────────────────────────────────
        qml/nat/NatSubBar.qml
        qml/nat/NatView.qml
        qml/nat/NatStaticForm.qml
        qml/nat/NatDynamicForm.qml
        qml/nat/NatPatForm.qml
        qml/nat/NatInterfaceForm.qml
        qml/nat/NatAclForm.qml

        # Static
        qml/routing/static/StaticRouteRow.qml
        qml/routing/static/StaticRoutingForm.qml
        qml/routing/static/StaticRoutingDefaultCard.qml
        qml/routing/static/StaticRoutingRoutesCard.qml

        # OSPF
        qml/routing/ospf/OspfProcessCard.qml
        qml/routing/ospf/OspfRoutingForm.qml

        # EIGRP
        qml/routing/eigrp/EigrpProcessCard.qml
        qml/routing/eigrp/EigrpRoutingForm.qml

    RESOURCES
        # Icons
        resources/icons/logo.svg
        resources/icons/logo.png

        # Activity Bar
        resources/activitybar/dashboard.svg
        resources/activitybar/devices.svg
        resources/activitybar/topology.svg
        resources/activitybar/logs-alerts.svg
        resources/activitybar/python.svg
        resources/activitybar/settings.svg

        # Device Tabs
        resources/devicetabs/close.svg

        # Feature Bar
        resources/featurebar/info.svg
        resources/featurebar/terminal.svg
        resources/featurebar/interface.svg

        # Side Bar
        resources/sidebar/add.svg
        resources/sidebar/filter.svg
        resources/sidebar/refresh.svg
        resources/sidebar/search.svg
        resources/sidebar/edit.svg
        resources/sidebar/delete.svg
        resources/sidebar/dot.svg
        resources/sidebar/router.svg
        resources/sidebar/switch.svg

        # Status Bar
        resources/statusbar/check.svg
        resources/statusbar/error.svg
        resources/statusbar/info.svg
        resources/statusbar/ready.svg
        resources/statusbar/warning.svg
        resources/statusbar/net-wifi.svg
        resources/statusbar/net-ethernet.svg
        resources/statusbar/net-disconnected.svg
        # Notifications
        resources/statusbar/bell.svg
        resources/statusbar/bell-slash.svg
        resources/statusbar/bell-dot.svg
    SOURCES
        src/database/DatabaseManager.h
        src/database/DatabaseManager.cpp
        src/database/DatabaseConnection.cpp
        src/database/SqlUtils.cpp
        src/database/DeviceRepository.cpp
        src/database/DhcpPoolRepository.cpp
        src/database/ExcludedAddressRepository.cpp
        src/database/routing/OspfRoutingRepository.h
        src/database/routing/OspfRoutingRepository.cpp
        src/database/routing/EigrpRoutingRepository.h
        src/database/routing/EigrpRoutingRepository.cpp
        src/database/routing/RoutingStaticRepository.h
        src/database/nat/NatRepository.h
        src/database/nat/NatRepository.cpp
        src/database/nat/NatAclRepository.h
        src/database/nat/NatAclRepository.cpp
        src/database/routing/RoutingStaticRepository.cpp
        src/database/BackupService.cpp
        src/TerminalHelper.h
        src/TerminalHelper.cpp
        src/NetworkMonitor.h
)

set_target_properties(NetworkTools PROPERTIES
    MACOSX_BUNDLE_BUNDLE_VERSION       ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)

target_link_libraries(NetworkTools PRIVATE
    Qt6::Quick
    Qt6::Network
    Qt6::Sql
    Qt6::QuickEffects
    Qt6::Widgets
    Qt6::LabsPlatform
)

include(GNUInstallDirs)
install(TARGETS NetworkTools
    BUNDLE  DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

target_sources(NetworkTools PRIVATE app_icon.rc)

set(SOURCE_PYTHON_KERNEL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../python app kenel")
set(DEST_PYTHON_KERNEL_DIR "$<TARGET_FILE_DIR:NetworkTools>/python_app_kenel")

add_custom_command(TARGET NetworkTools POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        "${SOURCE_PYTHON_KERNEL_DIR}"
        "${DEST_PYTHON_KERNEL_DIR}"
    COMMENT "Syncing Python app kernel to output directory..."
)
