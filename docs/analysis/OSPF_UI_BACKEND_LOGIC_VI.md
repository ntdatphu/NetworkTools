# Nguyen ly logic UI va Backend OSPF

## 1. Pham vi va thanh phan
Tai lieu nay tong hop logic OSPF duoc trien khai tren:
- UI QML: OSPF form, process card, validation dialog.
- Backend C++/Qt: `DatabaseManager` va `OspfRoutingRepository` de doc/ghi SQLite.
- Backend Python login parser: parse running-config va nap vao DB.
- Schema du lieu: bang `ospf_processes`, `ospf_networks`.

## 2. Nguyen ly UI OSPF (QML)

### 2.1 Muc tieu man hinh
Man hinh OSPF cho phep:
- Load cau hinh OSPF theo host dang chon.
- Tao/sua/xoa nhieu process OSPF.
- Moi process co danh sach network.
- Kiem tra hop le truoc khi save.
- Theo doi trang thai thay doi chua luu (unsaved changes).

### 2.2 Mo hinh state chinh trong form
Tai `OspfRoutingForm.qml`, cac state cot loi:
- `currentHostIp`: host dang thao tac.
- `isLoading`, `isSaving`: khoa cac thao tac trong luc tai/luu.
- `hasPendingLocalChanges`: co thay doi local so voi du lieu da load.
- `loadedProcessesSignature`: baseline sau lan load thanh cong.
- `processModel`: danh sach process card tren UI.
- `processPayloadByUid`: map payload theo `processUid` de khoi tao delegate on dinh.

Nguyen ly dirty-check:
- Moi card cung cap `signatureData()`.
- Form tong hop toan bo card -> JSON stringify.
- Neu signature hien tai khac baseline -> `hasPendingLocalChanges = true`.

### 2.3 Vong doi du lieu tren UI
1. Khi `currentHostIp` thay doi, form goi `loadFromDatabase()`.
2. Form goi `dbManager.getOspfRouting(host)`.
3. Neu OK, append tung process vao `processModel`.
4. Sau khi render xong, tinh baseline signature va reset dirty flag.

### 2.4 Logic cua process card
Tai `OspfProcessCard.qml`:
- `persisted = originalOspfId > 0` xac dinh process da ton tai trong DB.
- Process persisted mo o che do khoa (`editMode = false`) va can bam "Change" de sua.
- Process moi (`ospf_id = 0`) cho phep edit ngay.

Moi card quan ly:
- Process fields: `process_id`, `router_id`, `ad`, `default_info`, `auto_summary`.
- Network list dong: add/remove row, moi row gom `network`, `wildcard`, `area`.

### 2.5 Rule validate tren UI
Ham `validate(showErrors)` thuc hien:
- `process_id`: bat buoc, so nguyen, trong [1..65535].
- `router_id`: neu co gia tri thi phai la IPv4 hop le.
- `ad`: neu nhap thi phai trong [1..255].
- Moi dong network: khong cho phep thieu bat ky o nao trong 3 o.
- `network` va `wildcard`: phai la IPv4 hop le.
- Moi process phai co it nhat 1 network hop le.

Neu save (strict validation):
- Form goi `showValidation(message)` de hien `OspfValidationDialog`.

### 2.6 Save / Reload / Cancel tren UI
- Save:
  - Build payload bang `snapshotForSave()` cua tung card.
  - Goi `dbManager.saveOspfRouting(host, payload)`.
  - Neu thanh cong: load lai tu DB de dong bo trang thai va baseline.
- Reload:
  - Doc lai DB, bo qua thay doi local.
- Cancel Changes:
  - Tuong duong reload va thong bao da huy thay doi local.

## 3. Hop dong payload UI -> Backend
Moi process gui xuong backend co dang:
- `ospf_id`: 0 neu moi, >0 neu ban ghi cu.
- `process_id`: int.
- `router_id`: string co the rong.
- `ad`: int (hoac co the khong hop le neu o de trong, backend se chuan hoa).
- `default_info`, `auto_summary`: bool.
- `networks`: danh sach `{ network, wildcard, area }`.

## 4. Nguyen ly backend C++ (Repository)

### 4.1 Lay du lieu theo host
`OspfRoutingRepository::getByHost(host)`:
- Kiem tra host va trang thai DB.
- Doc `ospf_processes` theo host voi dieu kien `success != -1`.
- Moi process lai doc danh sach `ospf_networks` theo `ospf_id`, cung loc `success != -1`.
- Tra ve payload gom `ok`, `message`, `processes`.

### 4.2 Save theo host: transaction + diff
`saveByHost(host, processes)` chay trong transaction:

1. Validate toan bo payload:
- `process_id` trong [1..65535].
- Khong trung `process_id` trong cung payload.
- `router_id` neu co thi la IPv4.
- `ad` neu ngoai [1..255] thi fallback ve 110 (khong fail).
- Moi process phai co >=1 network hop le.

2. Doc active processes hien tai (`success != -1`) de so sanh.

3. Xu ly tung process payload:
- Neu process cu ton tai va khong doi `process_id/router_id/ad`:
  - Chi update options (`default_info`, `auto_summary`) va cot `action`.
  - Diff danh sach networks theo key `network|wildcard|area`:
    - Key moi: insert row moi (`success = 0`).
    - Key mat di: soft delete bang `success = -1`.
- Neu process moi hoac process cu bi doi core fields:
  - Soft delete process cu + toan bo network cu (`success = -1`).
  - Insert process moi (`action = 3`, `success = 0`) va insert lai networks.

4. Process active nao khong con trong payload:
- Soft delete process do va networks lien quan (`success = -1`).

5. Commit transaction. Neu loi bat ky buoc nao -> rollback.

### 4.3 Y nghia cot `action`
Bitmask trong `ospf_processes.action`:
- Bit 2 (`2`): default_info thay doi.
- Bit 1 (`1`): auto_summary thay doi.
- Gia tri `3` thuong dung khi insert process moi (ca hai flag duoc danh dau can xu ly).

### 4.4 Y nghia cot `success`
- `0`: du lieu active/chua dong bo xong theo luong xu ly ben tren.
- `-1`: soft-deleted (khong con duoc load len UI).

Repository su dung `success != -1` de coi la ban ghi dang ton tai logic.

### 4.5 Ham clear theo host
`clearByHost(host)`:
- Tim process active cua host.
- Danh dau toan bo networks lien quan = `-1`.
- Danh dau toan bo processes cua host = `-1`.
- Commit/rollback theo transaction.

## 5. Backend Python parser/login (bo sung)

### 5.1 Parser running-config
`script/login/parser/routing_parser.py`:
- Tim block `router ospf <process_id>`.
- Trich cac dong `network A.B.C.D W.X.Y.Z area N`.
- Tao payload route type `ospf` voi:
  - `process_id` lay tu config.
  - `router_id = None`, `ad = None`.
  - `default_info = 0`, `auto_summary = 0` (mac dinh).

### 5.2 Ghi vao DB
`script/login/services/routing_service.py`:
- Goi `clear_routing_for_host(host)` truoc (xoa cung static/eigrp/ospf theo host).
- Insert process OSPF roi insert networks.

Y nghia:
- Luong Python chu yeu phuc vu dong bo du lieu parse tu thiet bi vao DB.
- Luong UI C++ QML la luong chinh de chinh sua chi tiet OSPF tren app.

## 6. Schema du lieu OSPF
Trong `data.sql`:
- `ospf_processes`:
  - `ospf_id`, `host`, `process_id`, `router_id`, `ad`, `default_info`, `auto_summary`, `action`, `success`.
- `ospf_networks`:
  - `id`, `ospf_id`, `network`, `wildcard`, `area`, `success`.

Quan he:
- 1 process OSPF co nhieu networks.
- FK `ospf_networks.ospf_id -> ospf_processes.ospf_id`.

## 7. Luong end-to-end tom tat
1. User chon host -> UI load OSPF tu DB.
2. User sua process/network tren card.
3. UI theo doi dirty state bang signature JSON.
4. User Save -> UI validate nghiem ngat.
5. Backend save theo transaction va diff process/network.
6. Backend soft-delete ban ghi bi xoa (`success = -1`), insert/mark ban ghi moi.
7. UI reload lai DB de dong bo trang thai hien thi.

## 8. Dac diem kien truc quan trong
- UI validation + backend validation cung ton tai de dam bao an toan du lieu 2 lop.
- Soft-delete thay vi hard-delete giup theo doi bien dong va tuong thich luong dong bo.
- Diff theo key network han che ghi de khi process khong doi core fields.
- Save thanh cong luon reload lai DB de tranh state lech giua UI va du lieu that.
