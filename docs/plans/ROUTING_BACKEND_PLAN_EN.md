# ROUTING BACKEND AND UI IMPLEMENTATION PLAN (BEST UX)

## 1. Objective
- Complete backend support for Routing: Static, OSPF, and EIGRP.
- Upgrade Routing QML UI for a best-in-class user experience: clear states, fast feedback, minimal user errors.
- Ensure host-based persistence with correct reload behavior across tabs and host switches.
- This document is planning only; no code changes are made here.

## 2. Consolidated current-state assessment

### 2.1 Current UI/QML status
- RoutingView currently only switches tabs and does not receive currentHostIp.
- StaticRoutingForm, OspfRoutingForm, and EigrpRoutingForm already have forms and Push Config buttons, but do not persist to DB.
- BaseProcessCard exposes major fields, but checkbox states (Default/Auto-Summary) are not consistently exposed for serialization.
- No dedicated Routing loading/saving/error/dirty state handling yet.

### 2.2 Current backend status
- DatabaseManager currently exposes only Device, DHCP Pool, and Excluded Address APIs.
- No Routing repositories or Routing Q_INVOKABLE APIs exist yet.
- Existing architecture is stable: DatabaseManager facade -> Domain Repository -> QSqlQuery.

### 2.3 Current schema readiness
- Routing schema is already present and sufficient:
  - ROUTING_DB (parent by host + route_type for OSPF/EIGRP)
  - static_default_routes, static_routes (independent host-based tables)
  - ospf_processes, ospf_networks
  - eigrp_processes, eigrp_networks
- Foreign keys and cascade behavior are already suitable for host lifecycle.

## 3. Best UX direction
- User always knows active host and active routing protocol.
- Invalid input is caught early at field level, not only on Push.
- Push Config provides explicit states: saving, success, failure, retry.
- Switching host/tab does not lose saved data; reload is accurate and fast.
- Push button is disabled when there is no valid change.

## 4. Backend plan

### 4.1 Add new repositories
- RoutingStaticRepository
- RoutingOspfRepository
- RoutingEigrpRepository

Each repository should include:
- saveByHost(host, payload)
- getByHost(host)
- clearByHost(host)

### 4.2 Extend DatabaseManager
- Add Routing repository members and initialize in initializeDatabase().
- Expose Q_INVOKABLE methods:
  - getStaticRouting(host)
  - saveStaticRouting(host, defaultRoute, routes)
  - getOspfRouting(host)
  - saveOspfRouting(host, processes)
  - getEigrpRouting(host)
  - saveEigrpRouting(host, processes)
  - clearRoutingByType(host, routeType)

### 4.3 Persistence strategy
- Use replace-on-save in a transaction:
  - Static/Default: delete and insert directly by host in static_default_routes/static_routes
  - OSPF/EIGRP: upsert ROUTING_DB by (host, route_type), then replace child rows by routing_id
- Reason:
  - Current Push workflow is full-state payload.
  - This is simpler, safer against stale rows, and easier to debug.

### 4.4 Required backend validation
- host must not be empty.
- route_type must be in allowed values.
- process_id, as_number, ad must respect valid ranges.
- required network fields must not be empty.
- rollback on any query failure.

## 5. Related QML update plan

### 5.1 RoutingView + ContentArea
- Add currentHostIp property to RoutingView.
- Bind currentHostIp from ContentArea to RoutingView.
- Trigger routing data load when host changes.

### 5.2 StaticRoutingForm
- Add currentHostIp, isLoading, isSaving, isDirty, lastError.
- Add loadStaticRouting() and serializeStaticPayload().
- Push Config flow:
  - local validation
  - set isSaving=true
  - call dbManager.saveStaticRouting
  - set isDirty=false on success
  - show status via StatusBar and field-level messages on failure.
- Add unsaved-change prompt when leaving form.

### 5.3 OspfRoutingForm
- Add currentHostIp, isLoading, isSaving, isDirty.
- Implement serializeOspfProcesses() from OspfProcessCard items.
- Implement hydrateOspfProcesses(data) to rebuild process + network models.
- Push Config:
  - disabled when empty/invalid
  - success message includes saved process/network counts.

### 5.4 EigrpRoutingForm
- Mirror OSPF state model (loading/saving/dirty).
- Serialize full process payload: as_number, router_id, auto_summary, passive_default, networks.
- Add inline validation feedback for as_number and network rows.

### 5.5 BaseProcessCard and child cards
- Expose additional readonly aliases:
  - defaultChecked
  - autoSummaryChecked
- Normalize network row schema:
  - OSPF: { network, wildcard, area }
  - EIGRP: { network, wildcard, interface_name }
- Add dataChanged() signal so parent forms can maintain isDirty reliably.

## 6. UX patterns for best experience

### 6.1 Required states
- Empty state: explicit guidance when no route/process exists.
- Loading state: lightweight skeleton/shimmer or disabled controls + spinner.
- Saving state: temporary lock on Push button with "Saving..." label.
- Success state: concise success message in StatusBar.
- Error state: clear cause + Retry action.

### 6.2 Validation behavior
- Validate at field level during input (IP, wildcard, ad).
- Highlight invalid fields with border + helper text.
- Enable Push only when form is valid.

### 6.3 Dirty-state protection
- isDirty becomes true on any user edit.
- On tab/host change with unsaved edits, show prompt:
  - Save
  - Discard
  - Cancel

### 6.4 Performance and smoothness
- Debounce expensive validations.
- Batch model updates during large payload load.
- Avoid unnecessary delegate recreation.

## 7. Proposed payload contracts

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

## 8. Expected file update list during implementation

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

## 9. Proposed implementation roadmap

### Phase 1 - Data/API foundation
- Create 3 Routing repositories.
- Expose Routing APIs in DatabaseManager.
- Add save/load/clear tests per route_type.

### Phase 2 - UI integration
- Bind currentHostIp into RoutingView and forms.
- Connect Push Config to dbManager routing APIs.
- Implement load/hydrate on tab enter and host change.

### Phase 3 - UX hardening
- Add loading/saving/error states.
- Add unsaved-change prompts.
- Refine validation and status feedback.

### Phase 4 - QA
- Round-trip tests: create -> save -> reload -> edit -> save.
- Fast host-switch tests and delete-device cascade tests.
- Regression checks for DHCP and Device modules.

## 10. Definition of done
- Static/OSPF/EIGRP can persist and reload correctly by host.
- Push Config has complete and clear feedback states.
- Input errors are visible and actionable.
- Host/tab switching is smooth and does not lose saved state.
- No regression in existing stable modules.

## 11. Risks and mitigations
- Risk: payload-schema mismatch.
  - Mitigation: lock payload contract before implementation.
- Risk: complex QML state causing dirty-state bugs.
  - Mitigation: centralized state helper functions per form.
- Risk: partial failure in multi-table writes.
  - Mitigation: mandatory transaction + rollback + detailed logs.

## 12. Out of scope
- BGP backend is excluded.
- Real device push via SSH/script runtime is excluded.
- Advanced schema migration/index optimization is excluded.
