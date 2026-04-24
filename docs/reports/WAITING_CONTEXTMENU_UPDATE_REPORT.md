# WAITING CONTEXT MENU UPDATE REPORT

## Muc tieu
- Bo sung hanh vi cho right-click tren host co `success = 0` (waiting).
- Them 2 lua chon moi:
  - `Up (Admin)`: doi `success` tu `0` sang `1`, sau do refresh danh sach.
  - `Connec`: chay login thuc te theo host duoc chon (SSH/TELNET theo `method` trong DB).

## Files da cap nhat
- `qml/sidebar/devices/DeviceContextMenu.qml`
- `qml/sidebar/PanelSideBar.qml`
- `src/database/DeviceRepository.h`
- `src/database/DeviceRepository.cpp`
- `src/database/DatabaseManager.h`
- `src/database/DatabaseManager.cpp`
- `src/terminalhelper.h`
- `script/login/connect_selected.py`
- `script/login/db_client.py`
- `script/login/protocols/ssh_adapter.py`
- `script/login/protocols/telnet_adapter.py`

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
  - `onConnecRequested`: goi `cli.connectHostAndSync(ip)` de chay script Python login theo host.
- Co thong bao status bar cho ket qua update success.
- Co thong bao tien trinh:
  - Bat dau: `Connecting <ip>...`
  - Ket thuc: thong bao ngan gon success/fail.
- Co khoa chong bam lap khi dang chay connect task.

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
  - `connectHostAndSync(const QString &host)`
- Ham nay:
  - goi script `script/login/connect_selected.py`
  - truyen vao DB path + host duoc chon
  - parse JSON output de tra message ngan gon cho status bar

### 5) Script Python connect host chi dinh
- File: `script/login/connect_selected.py`
- Luat xu ly:
  - Chi lay ban ghi khop host duoc chon.
  - Mac dinh chi xu ly host co `success = 0`.
  - Chi login `SSH` hoac `TELNET`.
  - Login thanh cong: `success = 1`, cap nhat `os`, `role`.
  - Login that bai: giu `success = 0`.
- Role duoc suy ra tu CLI:
  - co route, khong vlan => `rou`
  - co vlan, khong route => `sw2`
  - co ca route va vlan => `sw3`

### 6) Bo sung detect VLAN fallback
- Files:
  - `script/login/protocols/ssh_adapter.py`
  - `script/login/protocols/telnet_adapter.py`
- Thu `show vlan` truoc, neu rong thi thu tiep `show vl`.

## Ket qua mong doi
- Right-click host waiting (`success = 0`) se co them:
  - `Up (Admin)`
  - `Connec`
- Chon `Up (Admin)`:
  - `success` doi thanh `1`
  - danh sach duoc refresh ngay.
- Chon `Connec`:
  - status bar hien `Connecting <ip>...`
  - script Python login theo host duoc chon
  - ket qua duoc cap nhat vao DB (`success/os/role`)
  - danh sach duoc refresh sau khi xong.
