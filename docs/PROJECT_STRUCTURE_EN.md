# Project Structure

This document describes the current `NetworkTools` repository structure based on the actual source code on the `main` branch.

> Note: older documentation that mentions `NetworkUI/`, `data.sql`, or `script/database/init_db.py` no longer reflects the current repository structure.

## Standard Folder Tree

```text
NetworkTools/
├── frontend/
│   ├── CMakeLists.txt
│   ├── main.cpp
│   ├── app_icon.rc
│   ├── qml/
│   ├── components/
│   ├── theme/
│   ├── resources/
│   └── src/
│
├── python app kenel/
│   ├── main.py
│   ├── sql/
│   └── ...
│
├── docs/
│   ├── README.md
│   ├── PROJECT_SUMMARY.md
│   ├── PROJECT_STRUCTURE.md
│   ├── GENERATED_FILES.md
│   ├── ROUTING_BACKEND_PLAN_VI.md
│   ├── analysis/
│   └── research/
│
├── mock/
├── report/
└── README.md
```

## `frontend/`

The `frontend/` directory contains the main desktop application.

### Important Root Files

| File/directory | Role |
|---|---|
| `frontend/CMakeLists.txt` | Qt/CMake build configuration, QML module registration, C++ sources, resources |
| `frontend/main.cpp` | Qt application entry point |
| `frontend/app_icon.rc` | Windows application icon resource |
| `frontend/qml/` | Application screens and feature views |
| `frontend/components/` | Reusable QML components |
| `frontend/theme/` | Theme singleton, UI state, and design tokens |
| `frontend/resources/` | Icons and UI assets bundled into Qt resources |
| `frontend/src/` | C++ application/data layer |

### QML Module

The application declares the QML module:

```cmake
qt_add_qml_module(NetworkTools
    URI NetworkTools
    ...
)
```

QML files in `qml/`, `components/`, and `theme/` are explicitly listed in `frontend/CMakeLists.txt`. When adding, deleting, or moving QML files, update `QML_FILES` accordingly.

### Main QML Groups

| Group | Purpose |
|---|---|
| `qml/app/` | Main window and window state |
| `qml/panels/` | Devices, logs/alerts, settings panels |
| `qml/layout/` | Activity bar and status bar |
| `qml/sidebar/` | Device sidebar, add/edit device, YANG config |
| `qml/devices/` | Device tabs |
| `qml/content/` | Main content routing |
| `qml/interface/` | Interface configuration UI |
| `qml/routing/` | Static, OSPF, EIGRP |
| `qml/dhcp/` | DHCP pools and excluded addresses |
| `qml/acl/` | ACL views/forms/rules |
| `qml/nat/` | NAT static/dynamic/PAT/interface/ACL/route-map |
| `qml/shared/` | Toast, notifications, resize handles, alerts |

## `frontend/src/`

This directory contains the C++ layer that connects QML with data and system tasks.

| Group | Role |
|---|---|
| `src/database/` | Database manager, connection, repositories |
| `src/database/routing/` | Routing repositories |
| `src/database/nat/` | NAT and route-map repositories |
| `src/TerminalHelper.*` | Terminal/CLI helper |
| `src/NetworkMonitor.*` | Basic network/RAM status monitoring |

## `python app kenel/`

This directory is the current Python runtime/helper directory.

`frontend/CMakeLists.txt` copies it to the output directory as:

```text
python_app_kenel/
```

The name `kenel` appears to be a typo of `kernel`, but the current source depends on it. Do not rename it without updating:

- `frontend/CMakeLists.txt`
- `frontend/src/database/DatabaseConnection.cpp`
- any related build/runtime scripts or documentation

## `docs/`

Documentation follows this standardized structure:

```text
docs/
├── README.md
├── PROJECT_SUMMARY.md
├── PROJECT_STRUCTURE.md
├── GENERATED_FILES.md
├── ROUTING_BACKEND_PLAN_VI.md
├── PROJECT_SUMMARY_EN.md
├── PROJECT_STRUCTURE_EN.md
├── GENERATED_FILES_EN.md
├── ROUTING_BACKEND_PLAN_EN.md
├── analysis/
│   ├── QML_ANALYSIS.md
│   └── DATA_SQL_ANALYSIS.md
└── research/
    ├── RESEARCH_SCOPE.md
    ├── TEST_SCENARIOS.md
    └── EVALUATION_CRITERIA.md
```

## Sensitive Paths

Do not move or rename these paths unless the source/build logic is updated:

| Path | Reason |
|---|---|
| `frontend/` | Main Qt/CMake project |
| `frontend/CMakeLists.txt` | Explicitly lists sources, QML files, and resources |
| `frontend/qml/` | Declared in `qt_add_qml_module` |
| `frontend/components/` | Declared in `qt_add_qml_module` |
| `frontend/theme/` | Contains QML singletons and tokens |
| `frontend/resources/` | Used by QML/C++ resource paths |
| `python app kenel/` | Copied by CMake to output |
| `python app kenel/main.py` | Called when initializing a new database |
| `python app kenel/sql/main.sql` | Runtime database schema |

## Rules for Adding New Files

- New QML file: update `frontend/CMakeLists.txt` under `QML_FILES`.
- New resource: update `RESOURCES` in `frontend/CMakeLists.txt`.
- New C++ source/header: update `SOURCES` in `frontend/CMakeLists.txt`.
- New SQL table/schema: update files in `python app kenel/sql/` and ensure `main.sql` reflects the runtime schema.
- New research documentation: place it under `docs/research/`.
