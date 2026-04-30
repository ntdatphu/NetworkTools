# WAITING CONTEXT MENU UPDATE REPORT

## Muc tieu
- Bo sung hanh vi cho right-click tren host co `success = 0` (waiting).
- Them 2 lua chon moi:
  - `Up (Admin)`: doi `success` tu `0` sang `1`, sau do refresh danh sach.
  - `Connec`: in chuoi `connec` ra terminal.

## Files da cap nhat
- `qml/sidebar/devices/DeviceContextMenu.qml`
- `qml/sidebar/PanelSideBar.qml`
- `src/database/DeviceRepository.h`
- `src/database/DeviceRepository.cpp`
- `src/database/DatabaseManager.h`
- `src/database/DatabaseManager.cpp`
- `src/terminalhelper.h`
- `FILE md cua V/PROJECT_SUMMARY.md`
- `FILE md cua V/QML_ANALYSIS.md`

## Thay doi chi tiet

### 1) Context menu cho waiting host
- File: `qml/sidebar/devices/DeviceContextMenu.qml`
- Them 2 signal moi:
  - `upAdminRequested(string ip)`
  - `connecRequested(string ip)`
- Them logic `isWaiting` dua tren `targetStatus`.
- Khi `targetStatus === "waiting"`, menu hien them:
  - `Up (Admin)`
  - `Connec`
- Hanh vi cu van duoc giu:
  - Ping chi cho phep khi `targetStatus === "connected"`.
  - Click ngoai menu thi menu dong.

### 2) Xu ly hanh dong moi tai sidebar
- File: `qml/sidebar/PanelSideBar.qml`
- Noi signal moi tu context menu:
  - `onUpAdminRequested`: goi `dbManager.updateDeviceSuccess(ip, 1)`, sau do `reloadDevices()`.
  - `onConnecRequested`: goi `cli.printConnec()` de in `connec` trong terminal.
- Co thong bao status bar cho ket qua update success.

### 3) API backend cap nhat success
- Files:
  - `src/database/DeviceRepository.h/.cpp`
  - `src/database/DatabaseManager.h/.cpp`
- Them ham cap nhat success theo host:
  - `DeviceRepository::updateDeviceSuccess(const QString &host, int success)`
  - `DatabaseManager::updateDeviceSuccess(const QString &host, int success)` (Q_INVOKABLE)
- SQL su dung:
  - `UPDATE devices SET success = ? WHERE host = ?`

### 4) Terminal helper cho hanh dong Connec
- File: `src/terminalhelper.h`
- Them ham Q_INVOKABLE moi:
  - `printConnec()`
- Tren Windows: mo terminal va chay `echo connec`.

## Tai lieu da dong bo
- `FILE md cua V/PROJECT_SUMMARY.md`
- `FILE md cua V/QML_ANALYSIS.md`

## Ket qua mong doi
- Right-click host waiting (`success = 0`) se co them:
  - `Up (Admin)`
  - `Connec`
- Chon `Up (Admin)`:
  - `success` doi thanh `1`
  - danh sach duoc refresh ngay.
- Chon `Connec`:
  - terminal hien chu `connec`.
