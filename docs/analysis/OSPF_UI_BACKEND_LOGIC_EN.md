# OSPF UI and Backend Logic Principles

## 1. Scope and Components
This document summarizes the OSPF logic implemented across:
- QML UI: OSPF form, process card, validation dialog.
- C++/Qt backend: `DatabaseManager` and `OspfRoutingRepository` for SQLite read/write.
- Python login parser backend: running-config parsing and DB ingestion.
- Data schema: `ospf_processes`, `ospf_networks`.

## 2. OSPF UI Principles (QML)

### 2.1 Screen Goals
The OSPF screen supports:
- Loading OSPF configuration by selected host.
- Creating/editing/removing multiple OSPF processes.
- Managing network rows per process.
- Validating input before save.
- Tracking unsaved local changes.

### 2.2 Core Form State
In `OspfRoutingForm.qml`, key state variables are:
- `currentHostIp`: active host.
- `isLoading`, `isSaving`: operation guards.
- `hasPendingLocalChanges`: local state differs from loaded state.
- `loadedProcessesSignature`: baseline signature after successful load.
- `processModel`: list of process cards.
- `processPayloadByUid`: payload map by `processUid` for stable delegate hydration.

Dirty-check principle:
- Each card provides `signatureData()`.
- The form aggregates all cards and serializes to JSON.
- If current signature differs from baseline, `hasPendingLocalChanges` becomes true.

### 2.3 UI Data Lifecycle
1. When `currentHostIp` changes, form calls `loadFromDatabase()`.
2. Form calls `dbManager.getOspfRouting(host)`.
3. If successful, each process is appended into `processModel`.
4. After rendering, baseline signature is recomputed and dirty flag is reset.

### 2.4 Process Card Logic
In `OspfProcessCard.qml`:
- `persisted = originalOspfId > 0` indicates a DB-backed process.
- Persisted rows start locked (`editMode = false`) and require "Change" to edit.
- New rows (`ospf_id = 0`) are editable immediately.

Each card manages:
- Process fields: `process_id`, `router_id`, `ad`, `default_info`, `auto_summary`.
- Dynamic network list with add/remove rows, each row containing `network`, `wildcard`, `area`.

### 2.5 UI Validation Rules
`validate(showErrors)` enforces:
- `process_id`: required integer in [1..65535].
- `router_id`: optional, but if present must be valid IPv4.
- `ad`: if provided, must be in [1..255].
- Network rows: no partial row; all 3 fields are required.
- `network` and `wildcard` must be valid IPv4.
- Each process must contain at least one valid network row.

On strict validation (save flow):
- Form calls `showValidation(message)` and opens `OspfValidationDialog`.

### 2.6 Save / Reload / Cancel in UI
- Save:
  - Build payload from each card via `snapshotForSave()`.
  - Call `dbManager.saveOspfRouting(host, payload)`.
  - On success: reload from DB to re-sync baseline and visible state.
- Reload:
  - Re-read from DB and discard local edits.
- Cancel Changes:
  - Equivalent to reload plus info notification.

## 3. UI to Backend Payload Contract
Each process item sent to backend contains:
- `ospf_id`: 0 for new, >0 for existing record.
- `process_id`: int.
- `router_id`: optional string.
- `ad`: int (or potentially invalid if blank; backend normalizes).
- `default_info`, `auto_summary`: bool.
- `networks`: list of `{ network, wildcard, area }`.

## 4. C++ Backend Principles (Repository)

### 4.1 Read by Host
`OspfRoutingRepository::getByHost(host)`:
- Validates host and DB state.
- Reads `ospf_processes` by host with filter `success != -1`.
- For each process, reads `ospf_networks` by `ospf_id`, also filtered by `success != -1`.
- Returns structured payload with `ok`, `message`, and `processes`.

### 4.2 Save by Host: Transaction + Diff
`saveByHost(host, processes)` runs inside a DB transaction:

1. Validate incoming payload:
- `process_id` in [1..65535].
- No duplicate `process_id` in same payload.
- `router_id`, if present, must be IPv4.
- `ad` out of [1..255] is normalized to 110 (not rejected).
- Each process must have at least one valid network.

2. Read active existing processes (`success != -1`) for comparison.

3. Process each payload process:
- If existing process and core fields (`process_id/router_id/ad`) unchanged:
  - Only update options (`default_info`, `auto_summary`) and `action`.
  - Diff networks by key `network|wildcard|area`:
    - New key: insert network with `success = 0`.
    - Missing key: soft-delete network via `success = -1`.
- If new process, or existing process changed in core fields:
  - Soft-delete old process and its networks (`success = -1`).
  - Insert new process (`action = 3`, `success = 0`) and insert all networks.

4. Existing active processes missing from payload:
- Soft-delete those processes and their related networks.

5. Commit transaction. Any failure causes rollback.

### 4.3 Meaning of `action`
Bitmask in `ospf_processes.action`:
- Bit 2 (`2`): `default_info` changed.
- Bit 1 (`1`): `auto_summary` changed.
- Value `3` is typically used when inserting a new process.

### 4.4 Meaning of `success`
- `0`: active/currently tracked by sync workflow.
- `-1`: soft-deleted (excluded from UI load queries).

Repository logic treats `success != -1` as logically active.

### 4.5 Clear by Host
`clearByHost(host)`:
- Finds active process IDs for host.
- Marks related networks as `-1`.
- Marks host processes as `-1`.
- Commit/rollback is transaction-protected.

## 5. Python Parser/Login Backend (Supplemental)

### 5.1 Running-config Parser
`script/login/parser/routing_parser.py`:
- Detects `router ospf <process_id>` blocks.
- Extracts `network A.B.C.D W.X.Y.Z area N` lines.
- Builds `ospf` payload with:
  - Parsed `process_id`.
  - `router_id = None`, `ad = None`.
  - Default `default_info = 0`, `auto_summary = 0`.

### 5.2 DB Ingestion Service
`script/login/services/routing_service.py`:
- Calls `clear_routing_for_host(host)` first (static/eigrp/ospf clear).
- Inserts OSPF process, then inserts OSPF networks.

Implication:
- Python flow is mainly for inventory/sync ingestion from device configs.
- C++ QML flow is the primary interactive edit/save path in the app.

## 6. OSPF Data Schema
From `data.sql`:
- `ospf_processes`:
  - `ospf_id`, `host`, `process_id`, `router_id`, `ad`, `default_info`, `auto_summary`, `action`, `success`.
- `ospf_networks`:
  - `id`, `ospf_id`, `network`, `wildcard`, `area`, `success`.

Relationship:
- One OSPF process has many network rows.
- FK: `ospf_networks.ospf_id -> ospf_processes.ospf_id`.

## 7. End-to-End Summary Flow
1. User selects host -> UI loads OSPF from DB.
2. User edits processes/networks in cards.
3. UI computes dirty state from serialized signatures.
4. User saves -> strict UI validation runs.
5. Backend saves via transaction and process/network diff.
6. Removed entries are soft-deleted (`success = -1`); new/changed rows are inserted/updated.
7. UI reloads DB data after successful save to ensure consistency.

## 8. Key Architectural Characteristics
- Dual-layer validation: UI + backend validation for stronger data integrity.
- Soft-delete instead of hard-delete helps change tracking and sync compatibility.
- Network-level diff reduces unnecessary rewrites when process core fields are unchanged.
- Post-save reload prevents UI state drift from persisted data.
