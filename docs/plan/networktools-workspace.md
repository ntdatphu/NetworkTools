# NetworkTools Workspace Architecture and Implementation Plan

Status: proposed  
Target format: `.ntp` (NetworkTools Project)  
Scope: architecture and phased implementation only; no Python or QML implementation is included here.

## 1. Executive summary

NetworkTools should become a document-oriented desktop application: the app starts in an independent Welcome window, and opening or creating a project activates a temporary runtime workspace backed by one portable `.ntp` file. The `.ntp` payload is a versioned ZIP package containing the two SQLite databases, the configuration-backup tree, package metadata, and bounded whole-project snapshots.

The application must never edit the `.ntp` archive in place. It works only against an extracted per-session directory. Every save first produces consistent SQLite backup images, assembles a complete replacement package beside the destination as `<project>.ntp.tmp`, flushes and validates that package, and only then atomically replaces the destination. Autosave, explicit Save, Save As, snapshot creation, rollback, close, and crash recovery all use the same serialization coordinator so they cannot race.

Password protection should use an authenticated AES-256 design. The recommended format is a small versioned NetworkTools encryption envelope around the canonical ZIP payload, using AES-256-GCM and a password-derived key. An unprotected `.ntp` remains an ordinary ZIP. A protected `.ntp` decrypts to the exact same ordinary ZIP payload. This encrypts filenames and metadata as well as file contents and avoids legacy ZipCrypto. If external archive-tool compatibility is later made mandatory, record a separate ADR and substitute a vetted WinZip AES-256 AE-2 implementation; do not invent a ZIP encryption variant.

Whole-project snapshots are deliberately not Git repositories. Version 1 should favor simple, auditable full snapshots with checksums and retention limits. The current codebase's per-device configuration history is Dulwich/Git-backed under `backup/`; it must be exported to an immutable indexed file layout before nested `.git` directories and the Dulwich dependency can be removed.

## 2. Goals and non-goals

### 2.1 Goals

- Make one `.ntp` file the portable, user-visible source of truth for a NetworkTools project.
- Keep active SQLite I/O on normal filesystem files in an isolated temporary workspace, never directly in the ZIP.
- Make interruption during save leave either the previous valid `.ntp` or the complete new `.ntp`, not a partially rewritten archive.
- Recover unsaved work after an app or machine crash without silently overwriting the user's project.
- Provide whole-project snapshots that can be listed, labeled, validated, and rolled back without Git.
- Optionally protect the complete project with password-based AES-256 authenticated encryption.
- Separate application-global settings from project data.
- Start with a JetBrains-style independent Welcome window and expose the same project commands through a native-aware QML menu system.
- Preserve the existing dependency rule `QML -> slots -> service -> repository/worker` and make workspace paths explicit dependencies.

### 2.2 Non-goals for the first release

- Real-time collaboration, cloud sync, or merging concurrent edits.
- Incremental/delta archive updates; version 1 rewrites a complete package for correctness.
- A general-purpose VCS, branches, commits, or remote snapshot synchronization.
- Editing SQLite files while they remain inside the ZIP.
- Guaranteed secure erasure of temporary plaintext on SSDs; this cannot be promised portably.
- Multiple writable instances of the same project.
- Replacing domain-level Undo/Redo with snapshots. Snapshots are coarse recovery points.

## 3. Research findings and adopted lessons

| Product or platform | Documented behavior | NetworkTools decision |
|---|---|---|
| JetBrains IDEs | The Welcome screen exposes Open and recent projects; recent projects can be searched and organized. JetBrains autosaves on lifecycle events and idle/focus behavior. Local History records revisions independently of VCS, supports labels and rollback, and is explicitly bounded rather than permanent. See [Open and close projects](https://www.jetbrains.com/help/idea/open-close-and-move-projects.html), [Save and revert changes](https://www.jetbrains.com/help/idea/saving-and-reverting-changes.html), and [Local History](https://www.jetbrains.com/help/idea/local-history.html). | Make Welcome an app-level window, not an empty page inside an already-open project. Combine event-driven autosave with a maximum dirty interval. Give snapshots labels, timestamps, retention, and a clear statement that they are not long-term VCS. |
| Microsoft Office/Word | Open XML documents are ZIP packages composed of named parts. Office distinguishes normal saves from AutoRecover and exposes recovery/version selection instead of silently guessing which recovered version should win. See [Open XML package structure](https://learn.microsoft.com/en-us/office/open-xml/general/how-to-remove-a-document-part-from-a-package), [Office save, backup, and recovery](https://support.microsoft.com/en-us/office/collab-files/save-back-up-and-recover-a-file-in-microsoft-office), and [Word recovery](https://support.microsoft.com/en-us/word/recover-your-word-files-and-documents). | Use a manifest-driven ZIP package, but keep crash-recovery state separate from the last committed project. On restart, show recoverable sessions with timestamps and require an explicit Recover, Open Original, Save Copy, or Discard choice. |
| WinRAR/archive tools | Archive products treat packaging, encryption, integrity/recovery, and retention as separate concerns; WinRAR documents AES-256 protection and recovery records. See the [WinRAR product information](https://www.win-rar.com/fileadmin/downloads/WinRAR_Product_brochure3p.pdf). | Do not mistake ZIP CRCs for authenticated security or snapshots for corruption repair. Use authenticated encryption, package checksums, pre-replacement validation, and separate snapshots/recovery state. |
| SQLite | Copying a live database file during a transaction can produce an inconsistent backup. SQLite recommends its backup API or `VACUUM INTO` for a consistent live copy. WAL and journal files are part of database state while active. See [How to corrupt an SQLite database](https://www.sqlite.org/howtocorrupt.html), [Online backup API](https://www.sqlite.org/backup.html), and [`VACUUM INTO`](https://www.sqlite.org/lang_vacuum.html). | Never add a live database file to the archive with a raw filesystem copy. Serialize each database through the SQLite backup API to a staging image, then validate the image. Do not package `-wal`, `-shm`, or journal side files. |
| Python filesystem and ZIP APIs | Cross-platform replacement is provided by `os.replace`; successful same-filesystem rename/replace is atomic on supported local filesystems. Python's ZIP documentation warns about untrusted paths and notes that the standard library cannot create encrypted ZIPs. See [`os.replace`](https://docs.python.org/3/library/os.html#os.replace) and [`zipfile`](https://docs.python.org/3/library/zipfile.html). | Place `.ntp.tmp` in the destination directory, validate every archive member before extraction, and add a vetted cryptographic dependency for protected packages. Never call broad extraction on an unvalidated archive. |
| OWASP | OWASP recommends authenticated AES modes and slow, salted password derivation such as Argon2id; fast hashes are unsuitable for password-derived keys. See [Cryptographic Storage](https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html) and [Password Storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html). | Derive a 256-bit key with Argon2id using per-file parameters and salt, then encrypt the ZIP stream with AES-256-GCM. Store parameters, never the password or derived key. |
| Qt | `ApplicationWindow` owns a `menuBar` slot. `QtQuick.Controls.MenuBar` is native on macOS from Qt 6.8; `Qt.labs.platform.MenuBar` supports native/global menu facilities including Linux desktops with a compatible D-Bus registrar, but the Labs API is experimental. See [`ApplicationWindow`](https://doc.qt.io/qt-6/qml-qtquick-controls-applicationwindow.html), [`MenuBar`](https://doc.qt.io/qt-6/qml-qtquick-controls-menubar.html), and [Qt Labs Platform MenuBar](https://doc.qt.io/qt-6/qml-qt-labs-platform-menubar.html). | Keep one shared command/action model. Present it through `ApplicationWindow.menuBar` everywhere. Verify KDE behavior with the packaged Qt 6.10 runtime; if the stable control is not exported to KDE's global menu, use a narrowly isolated Linux QML presenter based on Qt Labs after an explicit compatibility test. Windows retains the conventional in-window menu. |

## 4. Current-state impact in this repository

The implementation must account for the following existing design, rather than layering workspace behavior over global paths:

- `app/main.py` currently calls `ensure_runtime_databases()` before creating the application and eagerly creates project-dependent services. Startup must be split into a lightweight global shell and a workspace activation phase.
- `app/infrastructure/database/paths.py` currently resolves `device_network.db` and `info_collected.db` under one global `app/data` directory. It should remain authoritative for installed schema resources, but active database paths must come from an immutable `WorkspacePaths`/`WorkspaceContext` created per open project.
- Some repositories accept injected paths, but several workers and compatibility modules cache `DEVICE_NETWORK_DB` or `DB_PATH` at import or construction time. All writable database consumers must be inventoried and converted to constructor/factory injection before switching workspaces is safe. Mutating a global path after consumers exist is not acceptable.
- `ConfigBackupService` is currently rooted at `app/backup`; it must instead use `<workspace>/backup`.
- `ConfigBackupRepository` currently creates one Dulwich Git repository per device. This conflicts with the no-Git snapshot direction and makes portable archives contain nested `.git` trees unless migrated.
- `app/UI/qml/content/WelcomeScreen.qml` is currently only an empty-content placeholder inside the main workspace. Keep that behavior under a clearer name such as Empty Workspace/No Device view; create a separate top-level Welcome window for project selection.
- `StatefulWindow.qml` already provides shared window geometry persistence and is an appropriate base for both Welcome and workspace windows after settings keys are separated by window role.
- Global settings already use `QSettings`; keep theme, window, global external-tool, and other app-wide preferences outside `.ntp`. Project-specific settings must be added to the package explicitly rather than mixed into `QSettings`.

## 5. Target architecture

### 5.1 Responsibility boundaries

| Component | Responsibility | Must not do |
|---|---|---|
| Application coordinator | Own startup, Welcome/project window transitions, OS open-file requests, and clean shutdown ordering. | Read/write project databases directly. |
| Recent projects store/model | Persist canonical path, project ID, display name, last-opened time, pinned state, and last known health in global settings. | Store passwords or extracted workspace paths. |
| Workspace manager | Create/open/import/close sessions, acquire locks, validate packages, activate paths, and expose lifecycle state. | Contain feature business logic. |
| Package codec | Read/write the versioned ZIP payload, manifest, checksums, limits, and optional encryption envelope. | Access live feature services or QML. |
| Save coordinator | Track dirty generations, debounce autosave, make consistent staging images, serialize saves, perform atomic replacement, and handle conflicts. | Allow parallel save or snapshot jobs. |
| Snapshot service | Create/list/label/restore/delete bounded whole-project snapshots. | Implement Git semantics or include snapshots inside snapshots. |
| Recovery manager | Maintain session leases/heartbeats, detect stale sessions, and present recovery candidates. | Overwrite the original automatically after a crash. |
| Workspace context | Hold immutable project/session IDs and concrete paths for both databases, `backup/`, snapshots, and staging. | Resolve writable paths from the process working directory. |
| QML workspace facade | Expose stable properties, state, progress, commands, errors, and models to QML. | Perform archive, crypto, or SQLite operations. |
| Command registry | Define File/Edit/View/Tools/Help actions, shortcuts, text, enablement, and handlers once for toolbar, Welcome screen, and menu presenters. | Duplicate save/open logic in individual QML controls. |

The dependency flow remains `QML -> facade/slots -> workspace or feature service -> repository/infrastructure`. Infrastructure may depend on `WorkspaceContext`; it must not import QML or global UI state.

### 5.2 Workspace lifecycle and state model

Use one explicit state machine so buttons, menus, autosave, and close handling agree:

1. `NO_WORKSPACE`: Welcome window is available; project-dependent services do not exist.
2. `OPENING`: lock, decrypt if needed, preflight, extract, validate, migrate in staging.
3. `ACTIVE_CLEAN`: workspace is usable and matches the last committed `.ntp` generation.
4. `ACTIVE_DIRTY`: one or more committed feature mutations are newer than the last saved generation.
5. `SAVING`: one serializer owns the save; newer mutations may continue to increment the dirty generation.
6. `CONFLICT` or `READ_ONLY`: external replacement, lock contention, unsupported format, or destination permissions prevent normal overwrite.
7. `CLOSING`: stop new work, drain writers, perform final save or honor an explicit user choice, release lock, clean session.
8. `RECOVERY_AVAILABLE`: a stale session exists and awaits a Welcome-screen decision.

Only one writable project is active in a process for version 1. Opening another project prompts to close the current project or launch a new process. This keeps service lifetimes and global QML context manageable while still allowing JetBrains-style separate project windows. Multi-project-in-one-process support can be considered only after all feature state is proven workspace-scoped.

## 6. `.ntp` package specification

### 6.1 Canonical ZIP layout

The version 1 ZIP payload uses normalized UTF-8 POSIX paths and contains:

```text
manifest.json
device_network.db
info_collected.db
backup/
snapshots/index.json
snapshots/<snapshot-id>/snapshot.json
snapshots/<snapshot-id>/device_network.db
snapshots/<snapshot-id>/info_collected.db
snapshots/<snapshot-id>/backup/...
```

Rules:

- The two root database files and the `backup/` directory are required. Write an explicit `backup/` entry when it is empty.
- `manifest.json` is required, UTF-8 JSON, and is parsed before any extraction.
- `snapshots/` may be empty, but `snapshots/index.json` is present for format consistency. Snapshot payloads never contain another `snapshots/` tree.
- Runtime-only files are forbidden: SQLite `-wal`, `-shm`, and journals; locks; autosave state; temporary files; logs; caches; generated reports unless a later format version explicitly adds them.
- Archive paths are case-sensitive at the format level. Reject duplicate names after Unicode normalization and case folding so a package behaves consistently on Windows, macOS, and Linux.
- Use broadly compatible DEFLATE compression for version 1. Enable ZIP64 and stream files to bound memory use.

### 6.2 Manifest fields

The manifest should define, at minimum:

- `format`: fixed identifier `networktools-project`.
- `formatVersion`: package-format integer, initially `1`.
- `projectId`: immutable UUID generated at creation/import.
- `name`: user-visible project name.
- `createdAt` and `modifiedAt`: UTC ISO-8601 timestamps.
- `createdByAppVersion` and `lastSavedByAppVersion`.
- `minimumReaderVersion`: oldest app version allowed to open read/write.
- `databaseSchemaVersions`: independent versions for both SQLite databases.
- `content`: required path, byte length, and SHA-256 digest for each root state item; backup entries may be represented by a sorted inventory digest to keep the manifest bounded.
- `snapshotPolicy`: count/size limits and whether automatic snapshots are enabled.
- `snapshotCount` and current snapshot-index digest.
- `features`: optional format capabilities so older readers can reject unsupported mandatory features.

Do not put passwords, derived keys, device credentials, absolute local paths, temp paths, machine names, or recent-project UI state in the manifest. The manifest digest model detects accidental corruption for plaintext projects; it is not a substitute for a digital signature against malicious tampering.

### 6.3 Format compatibility and migrations

- Distinguish package version from database schema versions.
- A reader accepts known optional fields, ignores unknown optional fields, and rejects unknown required capabilities.
- Opening an older supported package performs migration only in the extracted workspace. Before a destructive schema migration, create a pre-migration snapshot in the session. The original `.ntp` remains untouched until a complete post-migration save succeeds.
- Opening a newer unsupported format offers read-only metadata if safely possible, then refuses extraction/editing with a precise upgrade message.
- Failed migration leaves the original intact and keeps diagnostic/recovery data without adding the project to Recents as successfully opened.

## 7. Open, extract, validate, and close protocol

### 7.1 Open protocol

1. Canonicalize the requested path without following a package-internal path. Confirm it is a regular local file and enforce the `.ntp` extension for normal Open.
2. Acquire an advisory OS lock plus a human-readable sidecar lease containing project path fingerprint, process ID, host identifier, app version, and heartbeat. A live competing lock offers read-only open, Open a Copy, or Cancel; never break it silently.
3. Record the source fingerprint: stable file identity where available, size, modification time, and package digest. This is used to detect external replacement before save.
4. Detect plaintext ZIP versus the NetworkTools encrypted envelope by magic/version, not by filename. Prompt for a password only for a protected package.
5. Preflight the central directory/envelope before extraction: member count, duplicate normalized names, absolute/drive/UNC paths, `..`, NUL/control characters, symlinks/reparse-like entries, required files, declared sizes, total uncompressed size, per-entry size, compression ratio, and supported methods.
6. Create a random session directory under the per-user NetworkTools cache/runtime location, with permissions limited to the current user. Never derive the directory name from untrusted archive paths.
7. Extract members individually after resolving and proving every destination remains under the session root. Enforce limits while streaming, not only from declared ZIP metadata.
8. Validate manifest digests, snapshot index, SQLite headers, supported schemas, `PRAGMA quick_check`, and foreign-key consistency. Use full `integrity_check` for imports, explicit verification, and suspicious recovery; quick checks keep normal open responsive.
9. Run supported package/database migrations in the session and revalidate.
10. Construct immutable workspace paths and then instantiate project-dependent repositories, workers, managers, and the workspace window. Update Recents only after activation succeeds.

### 7.2 Close protocol

1. Transition to `CLOSING` and reject new feature writes/network jobs that would mutate project state.
2. Stop or drain network collectors and background writers before taking the final database images.
3. If dirty, run the normal save pipeline. On failure offer Retry, Save a Copy, Return to Project, or Discard; make the destructive choice explicit.
4. Shut down workspace services, close SQLite connections, release the package lock, and mark the recovery lease clean.
5. Remove the extracted session on a best-effort basis. Log cleanup failures without passwords or sensitive file contents and retry stale cleanup on the next launch.
6. Show the independent Welcome window when the last project window closes; quitting the app is a separate command.

## 8. Safe save and autosave design

### 8.1 Dirty tracking

- Every successful business transaction that can alter a packaged item increments a monotonic workspace generation and emits one mutation event after commit.
- Do not mark dirty for view selection, transient connection state that is intentionally nonpersistent, or failed/rolled-back operations.
- During migration, retain a conservative filesystem watcher over the two DBs and `backup/` as a safety net for legacy writers, but treat explicit mutation events as the target design. Remove reliance on file modification time after all writers use the service boundary.
- The save coordinator captures generation `N`. If generation `N+1` appears while it writes, successful replacement only clears through `N` and immediately schedules another save.

### 8.2 Autosave policy

Adopt event-driven behavior inspired by JetBrains, with conservative defaults:

- Debounce for 2 seconds after the last committed mutation.
- Force a save when dirty for 30 seconds even if mutations continue.
- Save on application deactivation, before snapshot/rollback/import, before closing a project, and before quitting.
- `Ctrl+S`/File > Save bypasses the debounce but joins the same serialized queue.
- Coalesce repeated requests; there is exactly one package writer per workspace.
- Run SQLite imaging, archive creation, hashing, encryption, and validation off the UI thread, with cancellability only before atomic replacement begins.
- Show compact state: Saved, Saving, Unsaved changes, Read-only, Conflict, or Save failed. Repeated failures must become visible and must not spin in a retry loop.

The interval may become a global setting later, but disabling automatic crash recovery or final-close prompting should require an explicit advanced choice.

### 8.3 Atomic save protocol

For target `example.ntp`, the required temporary target is `example.ntp.tmp` in the same directory:

1. Take the save mutex and capture generation `N` plus the source fingerprint.
2. Under a workspace-wide snapshot read lock, use SQLite's backup API to write consistent staged copies of both live databases. Coordinate `backup/` writers with the same lock and copy its stable state to staging. Do not raw-copy a database and do not package WAL/journal sidecars.
3. Run `quick_check` and foreign-key checks against the staged databases. Fail without touching the destination if either image is invalid.
4. Materialize the snapshot tree/index from the session, calculate content sizes/digests, and write the final manifest last in the staging model.
5. Remove only a stale temp file that is proven to belong to this project/save protocol. Create a new `.ntp.tmp` exclusively; never follow symlinks.
6. Stream a complete canonical ZIP into `.ntp.tmp`. If protected, stream that ZIP through the encryption envelope into the same destination-side temp file; an implementation-only inner temp must be private and cleaned.
7. Close the archive/encryption stream, flush it, and request an OS file sync. Reopen the temp package and verify envelope authentication, ZIP structure/CRC, manifest digests, required entries, and staged database health.
8. Recheck the destination fingerprint. If the on-disk `.ntp` changed since open/last save, enter `CONFLICT` and preserve the temp as a recovery candidate; do not overwrite external changes.
9. Atomically replace the destination with `.ntp.tmp` using a same-filesystem replace operation. Sync the parent directory where the platform supports it.
10. Record the new fingerprint, update Recents, and clear dirty state only through generation `N`. If newer changes exist, schedule another pass.

The application must not keep the source `.ntp` open after extraction, because Windows will otherwise prevent replacement. Network shares and unusual filesystems may not honor local atomicity/durability guarantees; detect or document this limitation, preserve recovery output on failure, and recommend Save a Copy to a local disk.

### 8.4 Save As, conflicts, and failures

- Save As writes and validates the new destination before switching the active project path/lock. A failure leaves the original active.
- When the destination is read-only or unavailable, keep working state and offer Retry or Save a Copy.
- On external modification, offer Save a Copy, Reopen External Version (after handling current unsaved state), or Cancel. No automatic last-writer-wins behavior.
- Preserve a valid `.ntp.tmp` after a crash or late save failure and show it as a recovery candidate. Remove invalid or superseded temps only after validation and user-safe retention rules.
- Add deterministic fault-injection points before staging, after each database image, during ZIP/encryption writes, after sync, immediately before replace, and immediately after replace.

## 9. Crash recovery

- Each session has metadata with session ID, project ID/path, original fingerprint, encrypted flag, dirty/saved generations, last successful autosave, app version, process identity, and heartbeat. It contains no password.
- A clean close marks the session complete before cleanup. A stale heartbeat plus a non-running owner identifies an interrupted session; PID alone is insufficient because IDs are reused.
- On startup, the Welcome window lists recoverable sessions with project name/path and timestamps. Actions are Recover, Open Original, Save Recovery Copy, and Discard.
- Recovery first validates the session databases and backup tree. Recovering an encrypted project requires the password again before overwriting or producing an encrypted copy.
- Never replace the original merely because a newer temp exists. The user reviews the candidate and the original fingerprint first.
- For protected projects, live extracted SQLite files necessarily exist in plaintext while SQLite is using them. Restrict the session directory to the current user, avoid predictable names, never log contents, and clean promptly. Document that project encryption protects the closed `.ntp`, not memory, page files, a compromised user account, or a live temp workspace. Periodic recovery packages for protected projects should themselves be encrypted.

## 10. Snapshot mechanism without Git

### 10.1 Snapshot semantics

A workspace snapshot is a consistent, immutable copy of the complete logical project state at one generation:

- both SQLite databases, imaged with the backup API;
- the `backup/` tree under a coordinated read lock;
- snapshot metadata and checksums;
- no nested `snapshots/`, temp files, locks, or logs.

Snapshot metadata contains a UUID, UTC timestamp, user label/comment, app and schema versions, source generation, reason (`manual`, `before-migration`, `before-rollback`, or `automatic`), pinned flag, item sizes/digests, and validation status.

Version 1 stores full copies under `snapshots/<id>/`. This is intentionally simpler and easier to validate than home-grown binary deltas. ZIP compression reduces some cost; retention prevents unbounded growth. Content-addressed deduplication may be introduced only as a future package-format capability after profiling, with migration and garbage-collection rules specified first.

### 10.2 Snapshot operations

- Create Snapshot flushes current mutations, captures one consistent generation, adds the snapshot, and runs the atomic package-save pipeline.
- History lists newest first and supports labels, pinned/manual status, size, schema/app version, and health.
- Preview compares high-level database counts/schema versions and backup-file inventory; row-level semantic diff is a later feature.
- Rollback first creates a pinned `before-rollback` safety snapshot. It restores the selected snapshot into a new staging workspace, validates it, swaps the active runtime state only after project services are quiescent, reinitializes dependent models/services, and saves the result as the new current state. The selected historical snapshot is not deleted.
- Delete Snapshot applies only to unpinned snapshots after confirmation and uses the next atomic save.
- Default policy: retain 20 automatic snapshots and cap automatic snapshot bytes at the lesser of a configurable absolute limit and a percentage of available disk. Manual/pinned, pre-migration, and pre-rollback snapshots are never silently evicted. Warn before an action that cannot fit required staging space.

### 10.3 Existing Dulwich history migration

The current `backup/<host>/cfg/.git` repositories are domain-level running-configuration history, not whole-project snapshots. Migrate them without losing user history:

1. Enumerate every reachable commit in chronological order using the existing repository adapter.
2. Export each `running-config.txt` blob to an immutable file under a non-Git history layout, with an index containing timestamp, message, changed flag, host, and `legacySourceCommitId`.
3. Verify exported content counts and hashes against every reachable Git commit and test existing list/read/diff behaviors against the new adapter.
4. Keep the original repository untouched through at least one successful `.ntp` save and reopen verification. Never package both histories indefinitely.
5. Remove nested `.git` directories only through an explicit migration cleanup after validation; retain a recovery copy until the rollout policy expires.
6. Remove Dulwich from `app/pyproject.toml` only after no consumer or migration path needs it.

The new device-config history may compute text diffs on demand between immutable files. It remains distinct from whole-project snapshots, although it is included in `backup/` and therefore rolls back with the project.

## 11. Optional AES-256 password protection

### 11.1 Recommended encrypted format

- Plain project: the `.ntp` bytes are the canonical ZIP payload.
- Protected project: a small binary envelope precedes AES-256-GCM ciphertext whose plaintext is that exact ZIP payload.
- Authenticated header fields include magic, envelope version, cipher/KDF identifiers, Argon2id memory/time/parallelism parameters, random salt, random GCM nonce, ciphertext length, and authentication-tag location. Authenticate the non-secret header as additional data so parameters cannot be altered undetected.
- Derive a 256-bit key with Argon2id. Benchmark a release-build target delay appropriate for desktop use and store the parameters per file so they can be strengthened on a future save. Use a unique cryptographic salt and nonce for every complete rewrite.
- Stream encryption/decryption and package I/O so large projects do not require a second in-memory copy.

### 11.2 Password behavior and security rules

- Password protection is opt-in at Create, Save As, and Project Security settings. Changing/removing a password is a complete atomic rewrite.
- Never store the password or derived key in `.ntp`, QSettings, Recents, logs, crash metadata, command lines, environment variables, or analytics. Keep it only for the active session and clear buffers on a best-effort basis.
- Do not silently remember passwords. A future keychain integration must be a separate, explicit opt-in using the OS credential store.
- Use a confirmation field on creation/change, support password-manager paste and long Unicode passwords, and show Caps Lock where supported. Do not truncate or silently normalize passwords.
- Wrong password, corrupted ciphertext, and modified authentication data should return a safe generic open failure while detailed non-secret diagnostics go to logs.
- AES-GCM authentication protects encrypted packages. Plain packages rely on checksums for accidental corruption and provide no confidentiality/authenticity against an attacker who can rewrite the file.
- Do not use ZipCrypto, unauthenticated AES modes, custom ciphers, or a fast SHA-256(password) key.
- Before choosing libraries, complete a dependency/security ADR: maintenance status, license, Windows/macOS/Linux wheels, streaming support, test vectors, FIPS needs, update policy, and supply-chain scanning. Prefer established `cryptography` primitives plus an established Argon2 implementation over archive libraries with obsolete crypto.

## 12. Welcome window and project UX

### 12.1 Window model

- `WelcomeWindow` is an independent top-level `ApplicationWindow` available when no project is active. It uses its own geometry key and can open Global Settings without building databases or project services.
- `WorkspaceWindow` is the existing main application experience, activated only after a project validates. Its title shows project name, dirty/save status, and path where platform conventions allow.
- Opening a project hides/closes Welcome only after the workspace window is ready. Closing the last project returns to Welcome. A failed open leaves Welcome usable with an actionable error.
- Rename the current content-level `WelcomeScreen.qml` concept to avoid confusing “no device selected” with “no project open.”

### 12.2 Welcome content and behavior

The Welcome window provides:

- Recent Projects: searchable, keyboard-navigable, newest-first list with pin/unpin, canonical path, last-opened time, encrypted indicator, missing/unavailable state, Remove from Recents, and Reveal in File Manager.
- Create New: project name/location, optional password, then database creation from canonical schemas in a session followed by the first atomic `.ntp` save.
- Open: `.ntp` picker plus drag/drop and OS file-open routing.
- Import: a guided path for legacy `app/data` databases plus `app/backup`, or explicitly selected loose databases/backup folder. Import never mutates sources.
- Global Settings: theme, appearance, external tools, autosave defaults, snapshot defaults, and other app-wide preferences. Project security and project metadata appear only in a workspace.
- Recovery: a prominent section when stale sessions or valid `.ntp.tmp` candidates exist.

Do not eagerly decrypt or fully hash every recent project on Welcome. Use cheap existence/metadata checks and validate fully only on open. Remove missing projects only on user action, since removable/network media may return.

### 12.3 Recent-project storage

Store a bounded list in global settings with project ID, canonical path, display name, last-opened UTC time, pinned state, last known encrypted flag, and last known health. Deduplicate by project ID and filesystem identity/path. Path changes after Save As update the entry only after success. Never store passwords, database data, snapshot labels, or temp paths.

## 13. Native menu and command architecture

### 13.1 Menu contents

The workspace `ApplicationWindow` owns a QML `MenuBar` driven by shared actions. Initial menus include:

- File: New Project, Open Project, Open Recent, Save, Save As, Create Snapshot, Snapshot History, Close Project, Quit.
- Edit: existing standard editing/undo commands where an active control supports them.
- View: existing panels, status bar, theme/appearance entry points, and window commands.
- Tools: existing NetworkTools tools and project/global settings as appropriate.
- Help: shortcuts, documentation, diagnostics, and About.

The Welcome window has a reduced menu using the same New/Open/Settings/Quit/About actions. Enablement comes from lifecycle state; for example, Save is disabled in `NO_WORKSPACE`, during incompatible read-only open, and while final replacement is noninterruptible.

### 13.2 Platform strategy

- Use the stable `QtQuick.Controls.MenuBar` assigned to `ApplicationWindow.menuBar` as the baseline. The current lock resolves PyQt/Qt 6.10.2, so macOS native menu behavior is available.
- On Windows, retain the standard in-window menu, mnemonics, accelerators, and expected shortcuts.
- On macOS, verify native placement and standard About/Settings/Quit roles; custom QML delegates are intentionally ignored by native rendering.
- On KDE/Linux, run a packaging spike under Plasma with and without the global-menu widget. Official Qt Quick Controls documentation does not promise Linux global export. If the stable menu is not exported, instantiate an isolated `Qt.labs.platform` QML menu presenter only when the D-Bus registrar is available, backed by the same actions, and suppress the duplicate in-window presenter. Document the Labs compatibility risk and pin it in platform tests.
- Never maintain two independent command implementations. Toolbar, context entry, Welcome action, standard menu, and Linux native presenter dispatch the same backend command.

## 14. OS file integration

- Register `.ntp` as `application/vnd.networktools.project` with a NetworkTools Project description and dedicated icon during packaging/install, not ad hoc on every startup.
- Windows: register a versioned ProgID and Open verb without forcibly taking the user's default association. Follow [Microsoft file-type registration guidance](https://learn.microsoft.com/en-us/windows/win32/shell/how-to-register-a-file-type-for-a-new-application).
- Linux: ship shared MIME metadata and a `.desktop` entry advertising the MIME type, following the [Shared MIME](https://specifications.freedesktop.org/shared-mime-info/latest-single/) and [Desktop Entry](https://specifications.freedesktop.org/desktop-entry/1.1/mime-types.html) specifications.
- macOS: declare the document type/UTI and icon in the app bundle. Route Finder requests through Qt file-open events as described by [`QFileOpenEvent`](https://doc.qt.io/qt-6/qfileopenevent.html).
- Accept a canonical local `.ntp` path from command-line launch on Windows/Linux and file-open events on macOS. Queue requests arriving before Welcome initialization and reject non-local URLs unless a future feature explicitly supports them.

## 15. Step-by-step implementation phases

### Phase 0 - Decisions, inventory, and executable format fixtures

1. Approve ADRs for plaintext/encrypted container format, snapshot full-copy policy, locking model, and Qt/KDE menu fallback.
2. Freeze the version 1 manifest/envelope schemas and resource limits. Create small golden `.ntp` fixtures conceptually representing plaintext, encrypted, empty backup, snapshots, old schema, corrupt digest, traversal, duplicate path, and oversized archive cases.
3. Inventory every read/write reference to both database paths and `app/backup`, including module-level defaults and worker subprocess/thread boundaries. Classify global versus project-specific settings/data.
4. Define lifecycle events, error taxonomy, progress model, dirty-generation contract, and user-facing recovery/conflict choices.

Exit gate: format and lifecycle reviews are approved; every writable path consumer has an owner and migration task; no implementation begins with unresolved encryption or retention semantics.

### Phase 1 - Workspace-scoped paths and service lifecycle

1. Introduce immutable workspace identity/path configuration while keeping schema/install paths global.
2. Convert repositories, database managers, sync/collector workers, syslog persistence, and backup services to receive active paths explicitly at construction/factory time.
3. Split application startup into global services and project services. Move runtime database bootstrap from pre-application startup into Create/Import/Open migration flows.
4. Add ordered workspace shutdown and prove all SQLite connections/background writers close before deactivation.
5. Keep a developer-only fixture workspace for tests; do not silently fall back to `app/data` in production.

Exit gate: tests can instantiate two isolated workspace contexts sequentially without cross-writing; starting at Welcome creates no project DB; a search shows no production writer relying on mutable global DB/backup paths.

### Phase 2 - Package codec and secure open pipeline

1. Implement manifest models, ZIP reader/writer, deterministic normalized entry rules, checksums, and compatibility checks.
2. Implement preflight limits and safe streaming extraction with traversal, symlink, duplicate, decompression-bomb, and malformed metadata defenses.
3. Add SQLite staged-image validation and package migration hooks.
4. Implement plaintext round trips and fixture-based compatibility tests.
5. Complete the crypto dependency ADR, then add the encrypted envelope, Argon2id derivation, AES-256-GCM streaming, password prompts/contracts, and known-answer/tamper tests.

Exit gate: round trips preserve both DBs and backup bytes; hostile fixtures cannot escape or exhaust configured limits; wrong passwords/tampering cannot yield partial extracted state; no password appears in logs or settings.

### Phase 3 - Save coordinator, atomic replacement, and recovery

1. Add generation-based dirty tracking and one serialized save queue.
2. Build consistent SQLite images through the backup API and coordinate backup-tree reads/writes.
3. Implement destination-side `.ntp.tmp`, flush/sync, reopen validation, fingerprint conflict detection, and atomic replacement.
4. Route explicit Save, Save As, autosave triggers, project close, and app quit through the same coordinator.
5. Add session lease/heartbeat records, stale-session discovery, protected recovery packages, and Welcome-facing recovery actions.
6. Add fault-injection and crash-process integration tests across every save boundary.

Exit gate: killing the app at every injection point always leaves the previous project or a fully valid new project plus an explainable recovery candidate; parallel mutations are not lost; external replacement is never overwritten silently; UI remains responsive during large saves.

### Phase 4 - Snapshots and removal of Git-backed project history

1. Implement snapshot metadata/index, full-state creation, list/label/pin/delete, retention accounting, and size/free-space checks.
2. Implement safe rollback with automatic pre-rollback snapshot, service quiescence, staging validation, model refresh, and atomic project save.
3. Build the Dulwich export adapter for existing per-device config histories, preserve legacy commit IDs in metadata, and verify list/read/diff parity.
4. Migrate imported histories, retain a recovery copy through verification, then remove nested Git storage and eventually the Dulwich dependency.
5. Add snapshot corruption, retention, schema-version, low-disk, and rollback-interruption tests.

Exit gate: a snapshot restores both DBs and backup state consistently; snapshots never include themselves; pinned/manual safety points are not silently evicted; no new `.ntp` contains a `.git` directory.

### Phase 5 - Independent Welcome window and project UX

1. Create the application/window coordinator and separate Welcome and workspace top-level window roles.
2. Add recent-project persistence/model, search, pin/remove/reveal behavior, missing-media state, and recovery section.
3. Add Create New, Open, Import, password, validation-progress, and actionable-error flows.
4. Convert the current content-level Welcome placeholder into an explicitly named empty-selection workspace view.
5. Add accessibility, keyboard-only operation, screen-reader labels, focus order, localization-ready strings, drag/drop, and high-contrast checks.

Exit gate: clean launch shows Welcome without project services; create/open/import transitions only after validation; close returns to Welcome; failures and cancel leave no phantom Recents entry or leaked active session.

### Phase 6 - Menu system and desktop file integration

1. Introduce the shared command/action registry and bind Welcome, workspace UI, shortcuts, and menus to it.
2. Add the QML `MenuBar` to each `ApplicationWindow` with lifecycle-aware enablement and standard shortcut behavior.
3. Run Windows, macOS, and KDE menu spikes; add the isolated Qt Labs Linux presenter only if necessary and supported by the packaged platform plugin.
4. Add installer/package metadata for `.ntp`, MIME/UTI/ProgID, icons, command-line opening, and macOS file-open events.
5. Test paths with spaces, Unicode, removable drives, missing files, multiple launch requests, and opening while another instance holds the lock.

Exit gate: double-clicking an `.ntp` opens or queues the correct project on all supported OSes; menu actions invoke the same commands; Windows keeps standard in-window behavior; macOS and supported KDE configurations use their expected global/native presentation.

### Phase 7 - Legacy import and guarded rollout

1. Detect existing `app/data/device_network.db`, `app/data/info_collected.db`, and `app/backup` and offer a one-time Import Existing NetworkTools Data card. Never mutate or delete sources during import.
2. Validate and migrate copies, export Dulwich history, create an initial `Imported legacy data` snapshot, and write the first `.ntp` atomically.
3. Reopen and validate the newly written package before marking migration successful. Keep legacy sources until the user explicitly archives/removes them outside this migration.
4. Gate the new workspace system behind a development flag, then preview/beta, then default-on. Retain a read-only diagnostic/import path for early package versions.
5. Update architecture, database, usage, shortcuts, packaging, security, and recovery documentation.

Exit gate: production-like legacy datasets import without source changes; rollback to the previous application release remains documented; support can diagnose package/open/save failures from redacted logs.

### Phase 8 - Hardening and release qualification

1. Run long-duration autosave tests with network collectors, SFTP/syslog activity, repeated snapshot/rollback, password changes, and app focus cycling.
2. Test abrupt process kill, power-loss simulation where practical, full disk, quota, permission denial, antivirus/file-indexer contention, slow/removable/network filesystems, clock changes, and destination replacement.
3. Fuzz manifest/envelope/ZIP parsing and run dependency/security/license scanning.
4. Benchmark open/save/rollback with small, typical, and maximum-supported projects. Keep memory bounded by streaming and publish supported size limits.
5. Complete Windows, KDE Linux, and macOS release-package test matrices and accessibility review.

Exit gate: all acceptance criteria below pass with release binaries and packaged dependencies; known filesystem limitations and temp-plaintext implications are documented.

## 16. Verification strategy

### 16.1 Unit and contract tests

- Manifest/envelope version parsing, canonical path normalization, checksum inventories, feature flags, and migration selection.
- Archive member validation: traversal, absolute/UNC/drive paths, symlinks, case/Unicode collisions, duplicate entries, unsupported compression, misleading sizes, and streaming limit enforcement.
- AES-GCM/Argon2id known-answer, random salt/nonce, wrong password, header/ciphertext/tag tampering, and password redaction.
- Dirty generations, save coalescing, retry/backoff, close decisions, lock leases, external fingerprints, retention, and recent-project deduplication.
- Snapshot create/index/retention/rollback and legacy Git-export equivalence.

### 16.2 Integration tests

- Mutate both databases during autosave and prove each saved generation is internally consistent.
- Exercise backup writes during saves under the shared coordination lock.
- Reopen every produced package and run database quick/foreign-key checks plus content digests.
- Kill a child app process at each fault-injection point and inspect original, temp, session, and recovery outcomes.
- Open the same project twice and verify read-only/copy/cancel flows.
- Replace the project externally and verify conflict behavior.
- Import current repository-format data, including Dulwich histories, without modifying sources.

### 16.3 QML/UI tests

- QML smoke-load both top-level windows with and without workspace/recovery models.
- Verify menu action availability for every lifecycle state and ensure shortcuts do not fire twice.
- Test recent list search/pin/remove/missing states, create/open/import cancellation, wrong-password retry, save failure, recovery, and rollback confirmation.
- Verify focus order, keyboard operation, screen-reader names, scaling, and high contrast.

### 16.4 Platform matrix

| Area | Windows | KDE Linux | macOS |
|---|---|---|---|
| Atomic local replace and locked destination behavior | Required | Required | Required |
| `.ntp` association and double-click/open request | ProgID/Open verb | MIME + desktop entry | UTI/document type + file-open event |
| Menu | In-window standard | In-window or D-Bus global presenter after capability check | Native global MenuBar |
| Temp directory permissions and cleanup | User ACL | mode `0700` | User-only directory |
| Unicode/long path/removable media cases | Required | Required | Required |

## 17. Observability and supportability

- Use structured, rotating application logs outside `.ntp` with operation ID, project ID, lifecycle transition, package format, duration, byte counts, and non-secret error category.
- Redact passwords, keys, device credentials, archive contents, config backup text, and full user paths where support policy requires it.
- Surface a copyable diagnostic summary: stage failed, source/destination, whether original remains valid, recovery candidate location, and recommended action.
- Record last successful save time/generation in session metadata and UI; do not claim Saved until replacement and validation complete.
- Add a read-only Verify Project command that checks envelope/ZIP, digests, snapshots, and SQLite health without modifying the project.

## 18. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Global/import-time DB paths write to the wrong project | Complete path injection before enabling workspace switching; test sequential isolated contexts; prohibit production fallback. |
| Raw copying of active SQLite creates an inconsistent archive | Mandate SQLite backup API images and package only staged DBs. |
| Autosave races with new writes | Monotonic generations, one serializer, coordinated snapshot locks, and immediate resave when a later generation exists. |
| Whole-package saves are slow or need double free space | Background streaming, explicit free-space checks, bounded snapshots, progress UI, and documented limits. Do not trade correctness for in-place ZIP updates. |
| External sync/client replaces the `.ntp` | Fingerprint before every replace and enter conflict mode. |
| Zip Slip or decompression bomb | Preflight plus streaming limits, normalized destination proof, reject links/collisions, fresh private extraction root. |
| Encrypted project leaks through active temp data | Current-user permissions, unpredictable paths, encrypted recovery packages, prompt cleanup, and clear threat-model documentation. |
| Password loss | Explicit warning and confirmation; no backdoor. Encourage user-managed password storage. Snapshots inside the same encrypted project do not bypass the password. |
| Snapshot growth | Separate automatic/manual classes, count/byte quotas, free-space checks, visible sizes, and no recursive snapshots. |
| Current Dulwich repositories inflate packages or violate no-Git requirement | Verified export to immutable indexed config-history files before packaging/removal. |
| KDE global menu is assumed but not supported by stable Quick Controls | Platform spike with packaged Qt; conditional isolated Qt Labs presenter backed by shared actions; retain in-window fallback. |
| Network filesystem lacks reliable atomic/durable semantics | Prefer local projects, warn/document limitations, preserve recovery temp, and offer Save a Copy. |

## 19. Release acceptance criteria

- A new, imported, plaintext, or protected project round-trips with both root databases and `backup/` intact.
- Normal operation never opens a SQLite connection to bytes inside the `.ntp` or packages a live DB by raw copy.
- Interruption at any tested save stage leaves the last valid project or the validated replacement; a recoverable candidate is never mistaken for committed state.
- `.ntp.tmp` is created beside the destination, fully synced/validated before atomic replace, and never overwrites an externally changed destination.
- Crash recovery is discoverable from Welcome and requires an explicit choice.
- Whole-project snapshots restore both databases and backup data, create a pre-rollback safety snapshot, obey retention, contain no nested snapshots, and use no Git repository.
- New/imported `.ntp` files contain no `.git` directory; legacy config history remains readable after verified migration.
- Protected files use AES-256 authenticated encryption with a slow salted KDF; no password/key is persisted or logged.
- Startup without a project shows the independent Welcome window and creates no project database.
- Recent Projects, Create New, Open/Import, Recovery, and Global Settings are keyboard-accessible and work without an active workspace.
- `ApplicationWindow` owns the QML menu presentation; Windows behavior remains standard, macOS is native with Qt 6.10, and KDE behavior is capability-tested with a documented fallback.
- File associations and OS open requests work in installed Windows, KDE Linux, and macOS builds.
- Existing legacy databases/backups import from copies, and the source data remains untouched until the user chooses otherwise.

## 20. Deferred enhancements

- Content-addressed snapshot deduplication after real package-size profiling.
- Semantic database/snapshot comparison and selective restore.
- Multiple active workspace windows in one process after all services become context-local.
- OS keychain opt-in for remembered project passwords.
- Project signing/authorship independent of password encryption.
- Remote/cloud project storage with an explicit synchronization and conflict protocol.

