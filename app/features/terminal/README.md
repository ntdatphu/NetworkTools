# Managed external terminal

Trạng thái: **partial**. NetworkTools-side manager and NTTP/1 server are
implemented and fake-tested; the separate Alacritty fork and Fedora/EVE-NG
acceptance remain external deliverables.

Active composition never renders a terminal. It launches the separately
installed `networktools-terminal` process and lets that process own its window,
PTY, terminal parsing, input, clipboard, and system OpenSSH child.

## Ownership

- `session.py`: UUID-based session DTO with separate process, window, IPC, and
  SSH-child states. It never stores a password.
- `ssh.py`: fail-closed host/username/port validation and argument-only OpenSSH
  construction.
- `launcher.py`: companion binary discovery and the `--nt-*` managed launch
  contract passed directly to `QProcess` without a shell.
- `protocol.py`: versioned NTTP/1 JSON Lines validation, allowlisted events and
  commands, and a 64 KiB message limit.
- `ipc_server.py`: `QLocalServer` endpoint in a user-owned `0700` runtime
  directory with a `0600` socket, registered-session checks, request IDs, and
  bounded timeouts.
- `managed_manager.py`: one managed session per inventory host, duplicate-open
  focus, lifecycle aggregation, graceful close fallback, crash cleanup, and
  restart.

The stable QML context is still `cli`. Its public terminal contract is:

```text
openDeviceTerminal(host)
focusDeviceTerminal(host)
closeDeviceTerminal(host)
restartDeviceTerminal(host)
isDeviceTerminalOpen(host)
deviceTerminalState(host)
terminalStateChanged(host, state)
terminalError(host, message)
```

UI states are `closed`, `starting`, `open`, `disconnected`, and `error`. QML does
not receive detailed process/IPC state and does not contain process or protocol
logic.

## Persistence and network behavior

This feature has no tables. It reads normalized device metadata through
`DeviceLoginService`. Stored passwords are intentionally excluded from session
objects, process arguments, IPC, messages, and logs. Interactive SSH is a new
system OpenSSH connection and is not shared with the automation
`DeviceSessionRegistry`.

`Up (Dev)` devices, unknown inventory rows, Telnet, unsafe host/user/port values,
a missing companion binary, and an unavailable safe runtime directory all fail
closed before a process starts. Automated tests never start SSH or contact a
device.

## NTTP/1

Terminal events are `terminal.started`, `terminal.ready`, `child.started`,
`child.exited`, `terminal.closed`, and `terminal.error`. Manager commands are
`window.focus`, `window.close`, `window.set_title`, `session.ping`, and
`session.get_info`. NTTP/1 does not carry terminal output, passwords, screen
content, database data, or arbitrary commands.

## Tests and known limits

`tests/unit/test_managed_terminal.py` covers launch/security, lifecycle,
duplicate prevention, crash cleanup, protocol validation, fragmented local
socket input, permissions, and unknown-session rejection. The socket cases need
an environment that permits creation of Unix sockets.

The former embedded implementation remains in `manager.py`, `window.py`,
`worker.py`, and `stream.py` only as inactive migration compatibility code with
its existing tests. It is not instantiated by `TerminalHelper`. Removing that
code, `qtpyTerminal-main`, and its Python dependencies is deferred to a focused
cleanup after companion-fork end-to-end acceptance.

The companion fork must still supply branding, `--nt-*` CLI parsing, the NTTP
client/window command dispatcher, packaging, license notices, and real
Fedora/Wayland/Cisco evidence. See
`docs/plan/networktools-terminal-alacritty.md` and ADR-0001.
