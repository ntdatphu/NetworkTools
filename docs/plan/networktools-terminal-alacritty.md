# NetworkTools Terminal (Alacritty Fork) Integration Plan

Status: NetworkTools-side Phase A implemented; companion fork pending  
Source: `NetworkTools_Terminal_Alacritty_Roadmap.md` (2026-08-12)  
Primary platform: Fedora Linux on Wayland  
Protocol: NTTP/1 over a user-local Unix domain socket

## 1. Outcome

NetworkTools will launch and manage a separately distributed **NetworkTools
Terminal** process, based on an Alacritty fork. NetworkTools owns inventory,
device metadata, process lifecycle, session state, and local IPC. The terminal
fork owns its window, PTY, terminal rendering, input, clipboard, scrollback, and
the OpenSSH child process.

The two products remain separate repositories:

```text
NetworkTools/           PyQt6/QML manager and device application
NetworkTools-Terminal/  Alacritty fork and NTTP/1 client
```

Alacritty source must not be copied into this repository. NetworkTools Terminal
must not read NetworkTools databases, receive passwords on its command line, or
contain device/configuration business logic.

## 2. Fixed decisions

1. The terminal is an independent process; NetworkTools never renders its screen.
2. `session_id` is the primary identity. A PID and window title are attributes,
   not identities.
3. The default is one managed terminal per inventory device. Opening it again
   focuses the existing session.
4. NetworkTools uses `QProcess` for spawn/exit/crash and NTTP/1 for window-ready,
   focus, graceful close, title changes, and health checks.
5. NTTP/1 is JSON Lines on a user-only Unix socket below
   `$XDG_RUNTIME_DIR/networktools/`; it is never exposed over TCP.
6. NTTP/1 carries lifecycle/control metadata only. It does not carry terminal
   output, passwords, arbitrary shell commands, or database content.
7. Interactive SSH uses system OpenSSH with an argument list and no shell.
   Network automation continues to use the existing NetworkTools session
   registry; the two connections are not shared.
8. The fork keeps `TERM=alacritty` initially and avoids changes to
   `alacritty_terminal` unless upstream lacks a required terminal capability.
9. The Linux MVP degrades safely when IPC is unavailable. Windows named-pipe
   support and manager-restart reannouncement are later milestones.

## 3. Repository split and ownership

| Work item | NetworkTools repository | NetworkTools-Terminal repository |
|---|---:|---:|
| Device lookup and policy | yes | no |
| Safe OpenSSH argument construction | yes | no |
| Session registry and UI state | yes | no |
| `QProcess` lifecycle | yes | no |
| NTTP/1 server and validation | yes | no |
| Alacritty baseline, fork, and upstream remote | no | yes |
| Branding, icon, desktop entry, config path | no | yes |
| `--nt-*` managed CLI parsing | no | yes |
| NTTP/1 client and window command dispatch | no | yes |
| PTY, ANSI/VT, input, clipboard, rendering | no | yes |
| Device DB, credentials, parsers, config push | yes | forbidden |

## 4. NetworkTools implementation

The terminal feature owns the implementation. `core.terminal.TerminalHelper`
remains a thin compatibility facade for the existing QML context property
`cli`.

```text
QML -> TerminalHelper -> ManagedTerminalManager
                              |       |
                              |       +-> NttpServer (QLocalServer)
                              +-> TerminalLauncher -> QProcess -> terminal
                                      |
                                      +-> OpenSshCommandBuilder
```

Planned feature files:

- `features/terminal/session.py`: session DTO and independent process/window/
  IPC/child state.
- `features/terminal/ssh.py`: validated OpenSSH program and arguments.
- `features/terminal/protocol.py`: NTTP/1 envelope validation and JSON framing.
- `features/terminal/ipc_server.py`: bounded, user-local `QLocalServer` endpoint.
- `features/terminal/launcher.py`: binary discovery and `QProcess` construction.
- `features/terminal/manager.py`: one-session-per-device registry, lifecycle,
  command timeouts, duplicate prevention, and aggregate QML state.

Public QML-facing operations:

```text
openDeviceTerminal(host)
focusDeviceTerminal(host)
closeDeviceTerminal(host)
restartDeviceTerminal(host)
isDeviceTerminalOpen(host)
deviceTerminalState(host)
```

Public signals:

```text
terminalStateChanged(host, state)
terminalError(host, message)
```

Aggregate UI states are `closed`, `starting`, `open`, `disconnected`, and
`error`. Detailed process/window/IPC/child states stay in Python.

## 5. NTTP/1 contract

Every message is one UTF-8 JSON object followed by `\n`, with a maximum encoded
line size of 64 KiB. Required common fields are `protocol`, `type`, and
`session_id`. `protocol` must be exactly `nttp/1`.

MVP terminal events:

- `terminal.started`
- `terminal.ready`
- `child.started`
- `child.exited`
- `terminal.closed`
- `terminal.error`

MVP manager commands:

- `session.ping`
- `session.get_info`
- `window.focus`
- `window.close`
- `window.set_title`

Commands contain a unique `request_id`; responses must repeat it. Unknown
versions, message types, events, commands, sessions, oversized lines, malformed
JSON, and unsafe title values are rejected. No general-purpose command execution
is part of NTTP/1.

## 6. Safe launch contract

The manager discovers `networktools-terminal` through an explicit configured
path or `PATH`. Managed startup uses arguments equivalent to:

```text
networktools-terminal
  --nt-managed
  --nt-session-id <uuid>
  --nt-device-id <stable inventory id>
  --nt-device-name <sanitized display name>
  --nt-host <validated host>
  --nt-ipc <runtime socket>
  --title <sanitized title>
  -e ssh -p <validated port> <validated username>@<validated host>
```

The password returned by the existing device login service is deliberately not
copied into `TerminalSession`, process arguments, IPC, logging, errors, previews,
or generated configuration. OpenSSH handles agent, key, host-key, askpass, and
interactive authentication.

## 7. Milestones and gates

### Phase A — NetworkTools manager (this repository, P0)

- [x] Audit current embedded terminal and QML entry points.
- [x] Add the session model and aggregate states.
- [x] Add validated OpenSSH argument construction.
- [x] Add binary discovery and `QProcess` lifecycle hooks.
- [x] Add one-session-per-device registry and duplicate-open behavior.
- [x] Add crash/error cleanup and restart behavior.
- [x] Add NTTP/1 parsing, size bounds, request IDs, and timeouts.
- [x] Add user-only `QLocalServer` runtime socket.
- [x] Relay state/actions through the stable `cli` QML facade.
- [x] Retire the embedded terminal path from active composition.

Gate: fake-process and fake-NTTP tests prove launch arguments, secret exclusion,
duplicate prevention, ready/close/crash transitions, malformed input rejection,
and graceful IPC degradation without opening a real network connection.

### Phase B — Alacritty fork baseline (companion repository, P0)

- [ ] Create/fork `NetworkTools-Terminal` and add Alacritty as `upstream`.
- [ ] Record upstream commit, Rust/Fedora/GPU/session details in
  `docs/networktools/baseline.md`.
- [ ] Build unmodified upstream in release mode.
- [ ] Manually verify Wayland window, local shell, input, resize, clipboard,
  OpenSSH, and terminfo.

Gate: the unmodified baseline works on the stated Fedora lab before patches.

### Phase C — Fork branding and managed CLI (companion repository, P0)

- [ ] Brand the binary, app identity, title, icon, desktop entry, README, config
  path, man page, and completions as NetworkTools Terminal.
- [ ] Preserve Apache-2.0/MIT notices and document the Alacritty origin.
- [ ] Add `--nt-managed`, session/device/name/host/IPC metadata, validation, and
  debug mode without changing `TERM`.
- [ ] Keep patches isolated under `alacritty/src/networktools/` where practical.

Gate: standalone mode behaves as a normal terminal and managed metadata parsing
has Rust unit tests.

### Phase D — Fork NTTP client (companion repository, P0)

- [ ] Add non-blocking Unix-socket client using a reader thread/channel into the
  winit event loop.
- [ ] Emit lifecycle events at startup, window creation, child spawn/exit, and
  window close.
- [ ] Dispatch focus, close, title, ping, and info commands through a grouped
  NetworkTools event variant.
- [ ] Continue operating when the manager socket is absent or disconnects.

Gate: fake-manager tests cover serialization, unknown protocol/command, message
limits, and lifecycle ordering.

### Phase E — End-to-end Linux MVP (both repositories, P0)

- [ ] Run the 16-step Definition of Done from the source roadmap.
- [ ] Verify duplicate open focuses the original process.
- [ ] Verify user close, manager close, SSH exit, process crash, IPC failure,
  manager shutdown, and device deletion.
- [ ] Verify no credential appears in process inspection or logs.
- [ ] Verify GNOME Wayland focus behavior and documented urgency fallback.

Gate: all automated tests pass and the Fedora/EVE-NG lab matrix is recorded
separately from fake-test evidence.

### Phase F — Packaging and post-MVP (P1/P2)

- [ ] NetworkTools theme/config generation and status/context-menu polish.
- [ ] Provider selection/fallback and a packaged-binary capability check.
- [ ] Fedora desktop integration and RPM/installer packaging.
- [ ] Version/capability handshake and compatibility table.
- [ ] IPC reconnect/backoff and `session.reannounce` after manager restart.
- [ ] Windows local-transport implementation only after Linux stabilization.

Tabs, splits, screen scraping, terminal-output streaming, Rust SSH, password IPC,
session persistence, and remote control remain out of scope.

## 8. Test matrix

Automated NetworkTools tests use fake devices, fake processes, and local temporary
sockets only. They never start SSH, contact lab devices, capture packets, or open
a real terminal window.

| Area | Required evidence |
|---|---|
| Session | UUID identity, one active session/device, PID not used as identity |
| Launch | list arguments, validated host/user/port/title, no shell, no password |
| Process | started, normal exit, crash, start error, cleanup, restart |
| IPC | valid JSONL, fragmentation, multiple lines, 64 KiB bound, bad JSON/version |
| Commands | request ID, response, timeout, focus, close, title, ping/info |
| UI contract | stable `cli` slots/signals and aggregate state changes |
| Security | user-local socket, no TCP listener, unknown session/command rejection |

Manual evidence is still required for Fedora GNOME Wayland, rendering, keyboard,
clipboard, resize, local shell, OpenSSH, Cisco IOS/IOS-XE, EVE-NG, GPU variants,
and desktop packaging. These checks must not be represented as complete based on
unit tests.

## 9. External dependency and completion rule

This repository cannot complete fork-specific phases without the location of the
separate `NetworkTools-Terminal` repository and a chosen GitHub owner/organization.
It also cannot claim Fedora/Wayland/Cisco acceptance without the stated lab.

The NetworkTools-side implementation may be merged independently once Phase A's
gate passes. The feature remains `partial` until Phases B–E have concrete build,
test, and lab evidence. The complete MVP is done only when both repositories pass
their gates and the full end-to-end lifecycle is demonstrated.

## 10. Implementation record (2026-08-12)

Phase A is implemented in this repository. The active `TerminalHelper`
composition uses `ManagedTerminalManager`; it no longer creates the legacy
embedded widget/Netmiko interactive worker. The public `cli` context remains
stable and now relays external-process state and errors.

Verified results:

- `uv lock --check`: passed.
- Temporary canonical database build: passed for 74 device-network and 21
  info-collected tables.
- Repository-wide Python compilation: passed.
- `tests.unit.test_managed_terminal`: 15/15 passed, including real Unix-socket
  permissions, fragmented JSONL input, response correlation, and timeout tests.
- Focused QML contract and `UI/Main` load: passed without new warnings.
- Full suite outside the socket-restricted sandbox: 390 tests ran with 11
  failures, 1 error, and 2 skips. This matches the audited functional baseline;
  the previous UDP environment error passed outside the sandbox, and no new
  terminal-related failure appeared.
- `scripts/validate_structure.py`: still fails only on the audited
  `features/interfaces/README.md` status-word issue.

No real terminal binary, SSH process, device connection, Fedora GUI, packet
capture, or lab listener was started for this implementation. Phases B–E need a
provided companion-repository location and explicit lab execution.
