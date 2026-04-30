# STATIC/DEFAULT ROUTING UPDATE REPORT

## 1. Scope
- Date: 2026-04-12
- Requested scope: improve StaticRoutingForm only, separate Static vs Default UX, support add/delete/edit, auto-load by host.
- Out of scope in this update: OSPF and EIGRP forms.

## 2. Implemented Changes

### 2.1 Backend
- Added new repository:
  - src/database/RoutingStaticRepository.h
  - src/database/RoutingStaticRepository.cpp
- Added DatabaseManager APIs:
  - getStaticRouting(host)
  - saveStaticRouting(host, defaultRoute, routes)
  - clearStaticRouting(host)
- Save strategy:
  - static_default_routes and static_routes are independent tables (no ROUTING_DB parent-child relation).
  - Replace rows by host in static_default_routes and static_routes inside one transaction.
  - Rollback on validation/query failure.

### 2.2 QML Integration
- ContentArea now passes currentHostIp into RoutingView.
- RoutingView now passes currentHostIp into StaticRoutingForm.
- StaticRoutingForm redesigned:
  - Clear separation of Default Route card and Static Routes card.
  - CRUD for static rows (add/edit/delete).
  - Auto-save with debounce when user edits fields.
  - Auto-load from DB when host changes.
  - Manual Reload and Save Now actions.
  - Status messages via statusBar.

## 3. UX Behavior After Update
- Select device host -> Static tab auto-loads host-specific default/static data.
- Edit default route or static rows -> auto-save runs after short delay.
- Delete/add/edit rows supported in same form.
- Save Now allows explicit commit and immediate feedback.
- Reload discards unsaved local edits and reloads DB state.

## 4. Files Changed
- CMakeLists.txt
- src/database/DatabaseManager.h
- src/database/DatabaseManager.cpp
- src/database/RoutingStaticRepository.h
- src/database/RoutingStaticRepository.cpp
- qml/content/ContentArea.qml
- qml/routing/RoutingView.qml
- qml/routing/static/StaticRoutingForm.qml
- md/analysis/QML_ANALYSIS.md
- md/analysis/QML_ANALYSIS_EN.md
- md/plans/ROUTING_BACKEND_PLAN_VI.md

## 5. Build Verification
- Build task used: Build NetworkUI (Debug)
- Result: compile completed and reached linking appNetworkUI.exe with new static repository and QML form updates.

## 6. Notes
- This update intentionally avoids OSPF/EIGRP modifications as requested.
- Existing schema tables used directly for this scope: static_default_routes, static_routes.

## 7. Success-Rule Update (2026-04-12)
- Added `success INTEGER DEFAULT 0` for:
  - `static_default_routes`
  - `static_routes`
- Existing DB compatibility:
  - Auto-migrate in startup path (`DatabaseConnection`) using `ALTER TABLE ... ADD COLUMN success INTEGER DEFAULT 0` when missing.

### 7.1 Default route rule (independent flow)
- Save default with value -> row is active with `success = 0`.
- Delete/Clear default -> current active default rows for host are marked `success = -1`.
- Re-input default value after delete/change -> new active row saved with `success = 0`.

### 7.2 Static route rule (independent flow)
- Save new static row -> insert with `success = 0`.
- Delete static row in UI -> row removed from payload; backend marks old row `success = -1`.
- Added `Change` button per persisted static row in `StaticRoutingForm`:
  - Press `Change` to unlock row for editing.
  - Save edited row -> old row marked `success = -1`, new row inserted with `success = 0`.

### 7.3 Export replaced static rows to text
- When old static rows are replaced/deleted, backend appends rollback command lines to:
  - `script/static_removed_<host>.txt`
- Output line format:
  - `no <network> <subnetmark> <next hop> <ad>`

## 8. Manual-Save and UX Fix Update (2026-04-12)
- Auto-save in `StaticRoutingForm` is disabled.
- Data is persisted only when user clicks:
  - `Save Default`
  - `Save Static`

### 8.1 Default Clear behavior
- Pressing `Clear` on default route now applies deletion state to DB for current host:
  - default route rows move to `success = -1`
- If clear action fails, the UI keeps pending state so user can retry save.

### 8.2 Static Change/Cancel behavior
- Persisted static rows show `Change`.
- While editing (`Change` mode), row shows `Cancel`.
- `Cancel` restores original values (network/mask/next-hop/ad), clears row error flags, and exits edit mode without applying replacement.

### 8.3 Runtime stability fix
- Fixed QML runtime error:
  - `TypeError: Value is undefined and could not be converted to an object`
- Root cause: unsafe `routeModel.get(index)` access in delegate during dynamic updates.
- Fix: delegate now uses bound role properties (`routeId`, `original*`) instead of unstable lookups.
