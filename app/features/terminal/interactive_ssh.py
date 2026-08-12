"""Interactive Paramiko PTY child for legacy network devices."""

from __future__ import annotations

import argparse
import os
import select
import signal
import sys
import termios
import tty
from pathlib import Path

import paramiko

APP_ROOT = Path(__file__).resolve().parents[2]
if str(APP_ROOT) not in sys.path:
    sys.path.insert(0, str(APP_ROOT))

from features.devices import DeviceLoginService, DeviceRepository
from features.devices.ssh_algorithm_repository import get_ssh_algorithm_override
from infrastructure.network.ssh_algorithms import make_transport_factory


def _terminal_size() -> tuple[int, int]:
    try:
        size = os.get_terminal_size(sys.stdin.fileno())
        return max(1, size.columns), max(1, size.lines)
    except OSError:
        return 80, 24


def _connect(db_path: Path, host: str) -> tuple[paramiko.SSHClient, paramiko.Channel]:
    device = DeviceLoginService(DeviceRepository(db_path)).load(host)
    if device is None:
        raise RuntimeError("Device is no longer available in the active workspace.")

    client = paramiko.SSHClient()
    client.load_system_host_keys()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    override = get_ssh_algorithm_override(db_path, host)
    connect_options: dict[str, object] = {
        "hostname": device["host"],
        "port": int(device["port"]),
        "username": device["username"],
        "password": device["password"],
        "look_for_keys": False,
        "allow_agent": False,
        "timeout": 10,
        "banner_timeout": 15,
        "auth_timeout": 15,
    }
    if override:
        connect_options["transport_factory"] = make_transport_factory(override)
    client.connect(**connect_options)
    columns, lines = _terminal_size()
    channel = client.invoke_shell(term="xterm-256color", width=columns, height=lines)
    channel.settimeout(0.0)
    return client, channel


def _relay(channel: paramiko.Channel) -> int:
    stdin_fd = sys.stdin.fileno()
    stdout_fd = sys.stdout.fileno()
    previous = termios.tcgetattr(stdin_fd)

    def resize(_signum: int, _frame: object) -> None:
        columns, lines = _terminal_size()
        try:
            channel.resize_pty(width=columns, height=lines)
        except OSError:
            pass

    old_handler = signal.signal(signal.SIGWINCH, resize)
    try:
        tty.setraw(stdin_fd)
        while not channel.closed:
            readable, _, _ = select.select([channel, stdin_fd], [], [], 0.25)
            if channel in readable:
                try:
                    data = channel.recv(65536)
                except BlockingIOError:
                    data = b""
                if data:
                    os.write(stdout_fd, data)
                elif channel.exit_status_ready():
                    break
            if stdin_fd in readable:
                data = os.read(stdin_fd, 65536)
                if not data:
                    break
                channel.sendall(data)
        return channel.recv_exit_status() if channel.exit_status_ready() else 0
    finally:
        signal.signal(signal.SIGWINCH, old_handler)
        termios.tcsetattr(stdin_fd, termios.TCSADRAIN, previous)


def main() -> int:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--db", required=True, type=Path)
    parser.add_argument("--host", required=True)
    args = parser.parse_args()
    client: paramiko.SSHClient | None = None
    try:
        client, channel = _connect(args.db, args.host)
        return _relay(channel)
    except (OSError, paramiko.SSHException, RuntimeError) as exc:
        print(f"NetworkTools SSH failed: {exc}", file=sys.stderr)
        return 1
    finally:
        if client is not None:
            client.close()


if __name__ == "__main__":
    raise SystemExit(main())
