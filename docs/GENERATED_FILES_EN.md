# GENERATED FILES

## Scope
- List of files/folders created at build-time or runtime.
- Excludes components related to PythonEnvManager.

## 1) Build-time generated/copied

## appNetworkUI executable
- Type: binary output.
- Purpose: main runnable application file.
- Created when: during build from the CMake target appNetworkUI.

## data.sql (copied output version)
- Type: file copied after build.
- Purpose: provides schema for runtime DB initialization in the app runtime directory.
- Created when: POST_BUILD copy_if_different step in CMakeLists.txt.

## Qt MOC/Autogen files
- Type: intermediate build files (moc_*.cpp, autogen metadata).
- Purpose: supports meta-object features for QObject, signal/slot, and Q_INVOKABLE.
- Created when: automatically by Qt/CMake on each build.

## 2) Runtime generated files/folders

## device_network.db
- Type: SQLite database file.
- Location: applicationDirPath()/device_network.db.
- Purpose: stores all device, DHCP, and related domain data.
- Created when: on first run if DB does not exist, in DatabaseConnection.initializeDatabase().

## backup/
- Type: root backup folder.
- Location: applicationDirPath()/backup.
- Purpose: contains per-host subfolders for future backup data.
- Created when: when DatabaseManager.createFoldersFromDevices() is called (usually after adding a device).

## backup/<host>/
- Type: per-host folder.
- Location: applicationDirPath()/backup/<host>.
- Purpose: partitions backup data by device host.
- Created when: BackupService.createFoldersFromHosts().

## script/ (target folder next to executable)
- Type: runtime-synced folder.
- Location: applicationDirPath()/script.
- Purpose: stores runtime scripts synced from source script folder.
- Created when: at startup by ScriptSyncHelper.syncScriptFolder() in main.cpp.

## script/versionScript.txt (inside target folder)
- Type: script bundle version file.
- Purpose: compares version to determine whether script folder must be recopied.
- Created when: appears after ScriptSyncHelper successfully copies script folder.

## 3) Runtime state/config files (Qt framework)

## QSettings storage
- Type: configuration file managed by Qt by Organization/Application name.
- Purpose: stores window state (StatefulWindow) and device tab state (DeviceTabs).
- Created when: at runtime, when settings are first written.
- Note: physical file path depends on OS and QSettings backend.

## 4) Items not confirmed as created in current flow

## versionScript.txt at app root dir
- There is helper support for copying a standalone version file (VersionScriptHelper).
- However, no direct call to this helper is observed in the current startup flow.
- Therefore, this document records it as supported capability, not as a file guaranteed to be created in current runtime.

## Quick summary
- Build-time confirmed: executable, copied data.sql, Qt autogen files.
- Runtime confirmed: device_network.db, backup/, backup/<host>/, script/ (when sync succeeds), QSettings data.
