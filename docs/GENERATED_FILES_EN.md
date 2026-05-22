# Generated Files

This document lists files/folders generated or copied during build/runtime based on the current source code on the `main` branch.

## Build-time copied/generated

### `NetworkTools` executable

- Type: binary output.
- Created by: CMake target `NetworkTools`.
- Current runtime location pattern:

```text
frontend/build/bin/NetworkTools
```

or an equivalent path depending on the build directory/platform.

### Qt generated/autogen files

- Type: intermediate build files.
- Examples: MOC files, autogen metadata, QML cache/resource artifacts.
- Created by: Qt/CMake.
- Should not be committed to the repository.

### Qt resource/QML module artifacts

- Type: intermediate build artifacts for the `NetworkTools` QML module.
- Source: `QML_FILES` and `RESOURCES` in `frontend/CMakeLists.txt`.
- Should not be committed to the repository.

### `python_app_kenel/`

- Type: post-build copied directory.
- Source:

```text
python app kenel/
```

- Destination:

```text
<TARGET_FILE_DIR:NetworkTools>/python_app_kenel/
```

- Created by: `add_custom_command(... POST_BUILD ...)` in `frontend/CMakeLists.txt`.
- Purpose: contains Python helper/runtime files and SQL schema used for database initialization.

> Note: `kenel` appears to be a typo, but the current source depends on it. Do not rename it without updating CMake and C++ runtime paths.

## Runtime generated files/folders

### `device_network.db`

- Type: SQLite database.
- Location:

```text
<applicationDirPath>/device_network.db
```

- Created when: first app run if the database does not exist.
- Mechanism: `DatabaseConnection.cpp` calls the Python app kernel to run `main.py --init-db` with `sql/main.sql`.

### `python_app_kenel/database_paths.json`

- Type: runtime/helper JSON file.
- May be created by the Python app kernel when path-saving functionality is used.
- Location depends on the Python app kernel working directory.

### SQLite WAL/SHM files

Because the SQL schema enables WAL mode, SQLite may create:

```text
device_network.db-wal
device_network.db-shm
```

These are runtime database files and should not be committed.

### QSettings storage

- Type: configuration storage managed by Qt.
- May include window state, UI state, or preferences.
- Physical location depends on the operating system and Qt settings backend.

## Files/folders that should not be committed

```text
frontend/build/
*.db
*.db-wal
*.db-shm
CMakeFiles/
CMakeCache.txt
cmake_install.cmake
*.user
```

## Files/folders that should be committed

```text
frontend/CMakeLists.txt
frontend/main.cpp
frontend/qml/
frontend/components/
frontend/theme/
frontend/resources/
frontend/src/
python app kenel/main.py
python app kenel/sql/
docs/
report/
README.md
```

## Update Notes

When build/runtime paths change, update this document together with:

- `README.md`
- `docs/PROJECT_SUMMARY.md`
- `docs/PROJECT_STRUCTURE.md`
