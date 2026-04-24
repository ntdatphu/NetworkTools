# PHUONG AN XAY DUNG BACKEND VA GIAO DIEN ROUTING (UX TOT NHAT)

## 1. Muc tieu
- Hoan thien backend cho Routing gom Static, OSPF, EIGRP tren nen schema da co.
- Nang cap giao dien QML Routing de dat trai nghiem nguoi dung nhanh, ro trang thai, it loi thao tac.
- Dam bao dong bo du lieu theo host thiet bi, tai lai dung state khi chuyen tab/chuyen host.
- Khong sua code trong tai lieu nay, chi de xuat implementation plan.

### 1.1 Trang thai cap nhat (04/2026)
- Da implement backend + UI cho phan Static/Default:
  - DatabaseManager da co API getStaticRouting/saveStaticRouting/clearStaticRouting.
  - Them RoutingStaticRepository de luu/tai truc tiep theo host trong static_default_routes + static_routes.
  - StaticRoutingForm da tach ro khu vuc Default Route va Static Routes, ho tro them/xoa/sua va auto-load theo host.
- OSPF va EIGRP giu nguyen hien trang, chua thay doi trong dot nay.

## 2. Hien trang tong hop

### 2.1 Hien trang UI/QML
- RoutingView chi dang dieu huong tab, chua nhan currentHostIp tu ContentArea.
- StaticRoutingForm, OspfRoutingForm, EigrpRoutingForm da co form + Push Config, nhung chua goi dbManager luu du lieu.
- BaseProcessCard da co cac field chinh, nhung state checkbox (Default/Auto-Summary) chua expose ro rang de serialize.
- Chua co loading state, dirty state, save state, retry state rieng cho Routing.

### 2.2 Hien trang backend
- DatabaseManager moi co Device/DHCP/Excluded APIs.
- Chua co Routing repositories va Routing Q_INVOKABLE APIs.
- Pattern hien tai on dinh: DatabaseManager facade -> Repository theo domain -> QSqlQuery.

### 2.3 Hien trang schema
- Da co day du bang cho Routing:
  - ROUTING_DB (parent theo host + route_type cho OSPF/EIGRP)
  - static_default_routes, static_routes (bang doc lap theo host)
  - ospf_processes, ospf_networks
  - eigrp_processes, eigrp_networks
- FK va cascade da tot cho lifecycle theo host.

## 3. Dinh huong trai nghiem tot nhat (UX goals)
- Nguoi dung luon biet dang o host nao va dang chinh protocol nao.
- Input sai duoc canh bao som tai form, khong doi den luc Push.
- Push Config co phan hoi ro rang: dang luu, thanh cong, that bai, co the retry.
- Chuyen host/tab khong mat du lieu da luu; du lieu duoc load nhanh va dung.
- Han che thao tac thua: disable nut Push khi khong co thay doi hoac du lieu khong hop le.

## 4. Phuong an backend

### 4.1 Them repositories moi
- RoutingStaticRepository
- RoutingOspfRepository
- RoutingEigrpRepository

Moi repository can co:
- saveByHost(host, payload)
- getByHost(host)
- clearByHost(host)

### 4.2 Mo rong DatabaseManager
- Them con tro repository Routing va khoi tao trong initializeDatabase().
- Expose Q_INVOKABLE methods:
  - getStaticRouting(host)
  - saveStaticRouting(host, defaultRoute, routes)
  - getOspfRouting(host)
  - saveOspfRouting(host, processes)
  - getEigrpRouting(host)
  - saveEigrpRouting(host, processes)
  - clearRoutingByType(host, routeType)

### 4.3 Chien luoc persistence
- Ap dung replace-on-save trong transaction:
  - Static/Default: xoa va insert lai truc tiep theo host trong static_default_routes/static_routes
  - OSPF/EIGRP: upsert ROUTING_DB theo (host, route_type), sau do xoa/insert bang con theo routing_id
- Ly do:
  - UI Push Config dang theo huong gui full-state.
  - Don gian hoa logic, de debug, tranh stale data.

### 4.4 Validation backend bat buoc
- host khong rong.
- route_type dung tap gia tri cho phep.
- process_id, as_number, ad dung range.
- network fields bat buoc khong rong.
- rollback neu loi giua chung.

## 5. Phuong an cap nhat QML Routing

### 5.1 RoutingView + ContentArea
- Them property currentHostIp trong RoutingView.
- Truyen currentHostIp tu ContentArea vao RoutingView.
- Khi host thay doi, trigger load data theo tab dang active.

### 5.2 StaticRoutingForm
- Them currentHostIp, isLoading, isSaving, isDirty, lastError.
- Them loadStaticRouting() va serializeStaticPayload().
- Push Config flow:
  - validate local
  - set isSaving=true
  - goi dbManager.saveStaticRouting
  - set isDirty=false neu thanh cong
  - show status thong qua StatusBar + thong diep field-level neu fail
- Them canh bao khi roi form neu co isDirty.

### 5.3 OspfRoutingForm
- Them currentHostIp, isLoading, isSaving, isDirty.
- Tao ham serializeOspfProcesses() doc data tu tung OspfProcessCard.
- Tao ham hydrateOspfProcesses(data) de bind du lieu khi load.
- Push Config ho tro:
  - disable khi process rong hoac invalid
  - hiem thi tong so process/networks duoc luu thanh cong.

### 5.4 EigrpRoutingForm
- Giong OSPF ve co che state/loading/saving/dirty.
- Serialize day du as_number, router_id, auto_summary, passive_default, networks.
- Hien thi validation inline cho as_number va network row.

### 5.5 BaseProcessCard va card con
- Expose them readonly aliases cho:
  - defaultChecked
  - autoSummaryChecked
- Chuan hoa du lieu network row de de serialize:
  - { network, wildcard, area } cho OSPF
  - { network, wildcard, interface_name } cho EIGRP
- Bo sung signal dataChanged() de form cha cap nhat isDirty.

## 6. UX pattern chi tiet de dat trai nghiem tot nhat

### 6.1 Trang thai can co
- Empty state: huong dan ro khi chua co process/route.
- Loading state: skeleton/shimmer hoac disabled form + spinner nhe.
- Saving state: khoa tam nut Push, hien "Saving...".
- Success state: thong bao ngan gon o StatusBar.
- Error state: thong bao co nguyen nhan + action Retry.

### 6.2 Validation pattern
- Validate tai chinh field (IP, wildcard, ad) ngay khi input.
- Highlight border + helper text neu sai.
- Nut Push chi enabled khi toan form hop le.

### 6.3 Dirty-state va bao ve du lieu
- isDirty bat khi user sua field.
- Neu doi tab/host khi isDirty=true, hien prompt:
  - Save
  - Discard
  - Cancel

### 6.4 Hieu nang va do muot
- Debounce validation nhe de tranh giat.
- List model update theo batch khi load nhieu network rows.
- Tranh re-create toan bo delegate neu khong can thiet.

## 7. Contract payload de xuat

### 7.1 Static
- {
  "default_route": "192.168.1.1",
  "routes": [
    { "network": "10.0.0.0", "mask": "255.255.255.0", "nexthop": "192.168.1.1", "ad": 1 }
  ]
}

### 7.2 OSPF
- {
  "processes": [
    {
      "process_id": 1,
      "router_id": "1.1.1.1",
      "ad": 110,
      "default_info": true,
      "auto_summary": false,
      "networks": [
        { "network": "192.168.1.0", "wildcard": "0.0.0.255", "area": "0" }
      ]
    }
  ]
}

### 7.3 EIGRP
- {
  "processes": [
    {
      "as_number": 100,
      "router_id": "2.2.2.2",
      "auto_summary": false,
      "passive_default": false,
      "networks": [
        { "network": "10.0.0.0", "wildcard": "0.0.0.255", "interface_name": "Gig0/0" }
      ]
    }
  ]
}

## 8. Danh sach file du kien can cap nhat khi implement

### 8.1 Backend
- src/database/DatabaseManager.h
- src/database/DatabaseManager.cpp
- src/database/RoutingStaticRepository.h
- src/database/RoutingStaticRepository.cpp
- src/database/RoutingOspfRepository.h
- src/database/RoutingOspfRepository.cpp
- src/database/RoutingEigrpRepository.h
- src/database/RoutingEigrpRepository.cpp
- CMakeLists.txt

### 8.2 QML
- qml/content/ContentArea.qml
- qml/routing/RoutingView.qml
- qml/routing/static/StaticRoutingForm.qml
- qml/routing/ospf/OspfRoutingForm.qml
- qml/routing/eigrp/EigrpRoutingForm.qml
- qml/routing/BaseProcessCard.qml
- qml/routing/ospf/OspfProcessCard.qml
- qml/routing/eigrp/EigrpProcessCard.qml

## 9. Lo trinh implementation de xuat

### Phase 1 - Data/API foundation
- Tao 3 Routing repositories.
- Expose Routing APIs trong DatabaseManager.
- Viet test save/load/clear cho tung route_type.

### Phase 2 - UI integration
- Noi currentHostIp vao RoutingView va forms.
- Noi Push Config vao dbManager.
- Them load/hydrate khi vao tab va khi doi host.

### Phase 3 - UX hardening
- Them loading/saving/error states.
- Them dirty-state confirm.
- Tinh chinh validation + status feedback.

### Phase 4 - QA
- Round-trip test: tao -> save -> reload -> edit -> save.
- Test switch host nhanh, test xoa device cascade.
- Regression test cho DHCP/Device de dam bao khong anh huong.

## 10. Tieu chi hoan thanh
- Static/OSPF/EIGRP luu va tai lai dung theo host.
- Push Config co feedback day du, khong co trang thai mo ho.
- UX khi input loi ro rang va de sua.
- Chuyen host/tab muot, khong mat state da luu.
- Khong gay regression cho module hien co.

## 11. Rui ro va giam thieu
- Rui ro payload khong khop schema.
  - Giam thieu: chot contract payload truoc khi code.
- Rui ro state QML phuc tap, de lo dirty-state.
  - Giam thieu: gom state management theo helper functions.
- Rui ro loi transaction khi save nhieu bang.
  - Giam thieu: transaction bat buoc + log loi chi tiet.

## 12. Ngoai pham vi
- Chua bao gom BGP backend.
- Chua bao gom deploy config that len thiet bi qua SSH/script runtime.
- Chua bao gom migration schema nang cao hoac toi uu index.
