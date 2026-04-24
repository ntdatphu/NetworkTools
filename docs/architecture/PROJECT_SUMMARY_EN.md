# PROJECT SUMMARY

## Scope
- High-level project overview document, excluding content related to PythonEnvManager.

## 1) Overall architecture (C++ + QML)

The project uses a Qt Quick frontend + C++ backend model:
- QML frontend: UI organized into modules such as layout, sidebar, devices, content, routing, and dhcp.
- C++ backend: provides data/services via QObject context properties and Q_INVOKABLE methods.
- Build system: CMake + Qt6, packaging QML, resources, and C++ into an executable.

Context properties injected from main.cpp:
- dbManager: DatabaseManager class acting as the data-layer facade.
- cli: TerminalHelper class for terminal/ping operations.
- networkMonitor: NetworkMonitor class for real-time network status.

## 2) Main data flow

## Startup flow
1. main.cpp initializes QApplication and application metadata.
2. ScriptSyncHelper syncs the script folder to the app runtime directory.
3. DatabaseManager.initializeDatabase() opens or creates the SQLite DB.
4. For a new DB, DatabaseConnection runs Python script `script/database/init_db.py` (via `QProcess`) to build the DB from `data.sql`.
5. For an existing DB, DatabaseConnection applies minimal schema migration when needed (for example, new entities like devices.yangcfg and the yangcfg table).
6. Injects dbManager, cli, and networkMonitor into QML.
7. Loads NetworkUI QML module with Main.qml.

## UI interaction flow
1. Users interact with Main.qml and child components.
2. Signals from menu/sidebar/tab/feature components orchestrate UI state.
3. When data is needed, QML directly calls dbManager via Q_INVOKABLE.
4. Returned QVariantList/QVariantMap is loaded into ListModel for rendering.
5. StatusBar directly reads networkMonitor properties through reactive bindings.

## Device management flow
1. PanelSideBar calls dbManager.getDevices() to load the list.
2. NewDevice calls add/update and then createFoldersFromDevices().
3. DeviceContextMenu emits edit/delete for all device states; Ping is enabled only for connected devices (`success = 1`), and the menu closes on outside click.

## DHCP flow
1. DhcpPoolForm and DhcpExcludedForm receive currentHostIp.
2. Forms call getDhcpPools/getExcludedAddresses to load data.
3. Add/Delete operations are performed directly through dbManager methods.

## Routing flow
- RoutingView is split into tabs: Static, OSPF, EIGRP.
- StaticRoutingForm orchestrates the full Static/Default route flow: load -> snapshot compare -> separated save.
  - `StaticRoutingDefaultCard`: Default route input UI; Enter = Save Default; Cancel reverts changes; Save button disabled when nothing has changed.
  - `StaticRoutingRoutesCard`: Static routes list UI; Enter in any input field = Save Static (if there are changes); Save button disabled when nothing has changed.
  - `StaticRouteRow`: Single route row delegate; emits `submitRequested` on Enter in any field.
  - `StaticRoutingValidationDialog`: Modal dialog for missing required-field errors.
- OSPF/EIGRP forms manage process-card UI; Push Config remains a placeholder.

## 3) Key modules

## Entry and integration
- main.cpp: entry point, context property injection, QML module loading.
- CMakeLists.txt: Qt/QML/resources build configuration and post-build copy of data.sql.

## Data layer
- DatabaseConnection: manages SQLite connection; for a new DB it calls `script/database/init_db.py` to initialize schema from `data.sql`.
- DatabaseManager: facade for QML CRUD and related business operations.
- DeviceRepository, DhcpPoolRepository, ExcludedAddressRepository: domain-specific SQL queries.
- The schema now also includes a yangcfg table to store Cisco RESTCONF login credentials per host (when supported).
- SqlUtils: helper utilities for binding nullable values in SQL queries.
- BackupService: creates backup folders based on host list.

## System helpers
- TerminalHelper: opens system terminal and pings host (from context menu when device is connected).
- NetworkMonitor: detects network connectivity status and emits change signals.
- ScriptSyncHelper: syncs script folder based on versionScript.txt.
- VersionScriptHelper: helper for copying version file (present in codebase, not currently observed in startup).

## UI modules
- app/: application shell and Theme singleton.
- layout/: menu/activity/status bars.
- sidebar/: search/filter/device list + add/edit dialog.
- devices/: device tabs and per-tab state.
- content/: content router by appMode/feature.
- routing/, dhcp/: feature-specific screens.
- shared/: reusable components (alert, resize handles).

## 4) Interaction overview

## C++ -> QML
- Backend data and functions are exposed through context properties.
- QML directly calls C++ methods via Q_INVOKABLE for CRUD.

## QML -> QML
- Components communicate via signal/handler chains:
  - PanelSideBar -> Main -> DeviceTabs -> ContentArea.
  - FeatureBar -> DeviceTabs -> ContentArea.
  - AppMenuBar -> Main actions.

## State management
- Theme singleton governs consistent style/spacing/colors.
- DeviceTabs uses Settings to persist tab/session state.
- Routing/DHCP forms use local ListModel for displayed list management.

## Short conclusion
- The current architecture is clearly separated into UI and data layers.
- A strong point is direct QML-to-backend calling, enabling fast CRUD development.
- Some advanced feature areas (especially Routing push config) are UI-ready but backend integration is not complete yet.
