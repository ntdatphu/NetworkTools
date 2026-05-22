# Project Summary

## Purpose

**NetworkTools** is a desktop application for centralized network device management, configuration data storage, and research-oriented experimentation for the student research topic:

> Researching and building a centralized management, configuration automation, and network security monitoring system.

This document describes the current system based on the source code on the `main` branch.

## Overall Architecture

```text
QML UI
  │
  ▼
C++ application/data layer
  │
  ├── DatabaseManager
  ├── DatabaseConnection
  ├── Repository classes
  ├── TerminalHelper
  └── NetworkMonitor
  │
  ▼
SQLite database
  │
  ▼
Python app kernel + SQL schema
```

## Main Components

### 1. Qt/QML Frontend

Directory:

```text
frontend/
```

Responsibilities:

- Provides the desktop UI.
- Organizes screens by module: devices, interface, routing, DHCP, ACL, NAT, logs/alerts, settings.
- Uses the `NetworkTools` QML module.
- Reuses components and theme tokens from `components/` and `theme/`.

### 2. C++ Application Layer

Directory:

```text
frontend/src/
```

Responsibilities:

- Exposes C++ objects to QML.
- Manages SQLite database connection.
- Provides domain repositories.
- Handles terminal-related actions and network monitoring.

Main QML-facing objects:

| Object | Role |
|---|---|
| `dbManager` | Facade for QML to access database/repository logic |
| `cli` | Terminal/CLI helper |
| `networkMonitor` | Basic runtime/network status provider |

### 3. Python App Kernel

Current source directory:

```text
python app kenel/
```

This directory is copied by CMake to the output directory as:

```text
python_app_kenel/
```

Responsibilities:

- Contains `main.py`.
- Contains SQL schema files in `sql/`.
- Initializes a new SQLite database.
- May support other Python-side helper tasks such as device login/connection.

> Note: `kenel` appears to be a typo of `kernel`, but the current source depends on this name. Do not rename it without updating CMake and C++ runtime paths.

### 4. SQLite Database

Runtime database:

```text
<applicationDirPath>/device_network.db
```

When the database does not exist, `DatabaseConnection.cpp` calls the Python app kernel to initialize it from:

```text
<applicationDirPath>/python_app_kenel/sql/main.sql
```

## Startup Flow

1. `frontend/main.cpp` initializes `QApplication`.
2. Application metadata is configured.
3. The app icon is loaded from Qt resources.
4. `DatabaseManager` is created and `initializeDatabase()` is called.
5. `TerminalHelper` and `NetworkMonitor` are created.
6. Context properties are injected into QML:
   - `dbManager`
   - `cli`
   - `networkMonitor`
7. The QML module is loaded:

```cpp
engine.loadFromModule("NetworkTools", "Main");
```

## Database Initialization Flow

1. `DatabaseConnection` determines the database path:

```text
applicationDirPath()/device_network.db
```

2. If the database does not exist, it calls the Python initializer.
3. The Python initializer runs `main.py` with:

```text
--init-db --sql <main.sql> --db <device_network.db>
```

4. After the database is created, Qt opens it using `QSQLITE`.
5. `PRAGMA foreign_keys = ON` is enabled.
6. Some compatibility/migration steps are applied for older databases when needed.

## Main Functional Modules

| Module | General status |
|---|---|
| Devices | UI and data layer exist |
| Interface | UI and repository exist |
| DHCP | UI and data layer exist |
| Routing | Static, OSPF, EIGRP UI and repositories exist |
| ACL | Multiple QML form/rule types exist |
| NAT | Static, Dynamic, PAT, Interface, ACL, Route Map UI exist |
| Logs/Alerts | UI panel exists; monitoring/alert logic needs expansion |
| Settings | UI panel exists |

## Research Scope

For the research report, the project should be framed around four directions:

1. **Centralized management**
   - Manage network devices.
   - Store device-related configuration by host.

2. **Configuration automation**
   - Standardize configuration input forms.
   - Store configuration domains: interface, routing, DHCP, ACL, NAT.
   - Prepare for automated configuration generation/deployment.

3. **Monitoring and alerting**
   - Track connection state.
   - Design logs/alerts.
   - Extend toward anomaly detection.

4. **System evaluation**
   - Compare manual work and system-assisted work.
   - Evaluate input error reduction.
   - Evaluate centralized visibility and state observation.

## Documentation Maintenance Notes

- Source code is the highest-priority source of truth.
- When CMake paths, runtime paths, or the SQL schema change, update:
  - `README.md`
  - `docs/PROJECT_SUMMARY.md`
  - `docs/PROJECT_STRUCTURE.md`
  - `docs/GENERATED_FILES.md`
  - related files in `docs/analysis/`.
