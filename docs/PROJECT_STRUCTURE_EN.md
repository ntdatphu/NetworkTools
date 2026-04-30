# PROJECT STRUCTURE

## Documentation scope
- This document excludes all content related to PythonEnvManager.
- The marker string "TO BE EXCLUDED FROM FUTURE DOCUMENTATION" was not found in the workspace at the time this document was created.

## Overall folder tree

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

## Folder explanations

## qml/
- Contains the entire Qt Quick user interface.
- Organized by UI domains: layout, sidebar, content, feature, routing, dhcp, shared.
- app/Main.qml is the root UI and connects the major UI blocks.

## src/
- Contains the C++ backend.
- The core is DatabaseManager and repositories that handle SQLite data.
- System helpers include TerminalHelper, NetworkMonitor, and ScriptSyncHelper.

## src/database/
- Data access layer following the repository pattern.
- DatabaseConnection opens the DB and calls Python script `script/database/init_db.py` to initialize schema from `data.sql` on first run.
- BackupService creates the backup folder tree based on host list.

## resources/
- Contains SVG/ICO icons used by the UI.
- Packaged into application resources via CMake.

## Key root files

## main.cpp
- Entry point of the Qt application.
- Initializes QApplication, syncs script folder, and initializes the DB.
- Injects QML context properties: dbManager, cli, networkMonitor.

## CMakeLists.txt
- Build configuration for Qt 6 + QML module.
- Registers C++ sources, QML files, and resources.
- Includes a POST_BUILD step to copy data.sql to the output directory.

## data.sql
- SQLite database initialization schema.
- Contains tables for devices, DHCP, routing, and related domains.

## app_icon.rc
- Windows resource script for executable icon.

## .qmlls.ini
- QML Language Server configuration for import/type resolution in IDE.

## qml/appnetworkui.qmltypes
- Type metadata for the NetworkUI QML module.
- Used for tooling, autocomplete, and static analysis.

## src/database/DatabaseManager.h/.cpp
- Facade layer between QML and repositories.
- Exposes Q_INVOKABLE methods for QML CRUD on devices, DHCP pools, and excluded addresses.

## src/database/DatabaseConnection.h/.cpp
- Creates and opens device_network.db in the app runtime directory.
- For a new DB, locates and runs `script/database/init_db.py` (via `QProcess`) to build DB from `data.sql`.

## src/ScriptSyncHelper.h
- Syncs script folder from source tree to app runtime directory.
- Compares versionScript.txt to decide whether to copy again.

## src/NetworkMonitor.h
- Monitors network state (connected/type/name) and emits periodic change signals.

## src/terminalhelper.h
- Opens system terminal and runs host ping from UI actions.

## src/VersionScriptHelper.h
- Helper for copying versionScript.txt.
- Present in the codebase, but not observed in the current startup flow.
