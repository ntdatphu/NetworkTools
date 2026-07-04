# NetworkTools PyQt6/QML app

Run from the repository root:

```bash
python app/main.py
```

This app copies the QML/module structure from `frontend/` into `app/NetworkTools/`.
It creates `app/device_network.db` from `app/NetworkTools/main.sql` on first run.

Implemented bridge functions:

- `Ctrl+N` opens the New Device window through the existing QML shortcut.
- New Device data is inserted into the SQLite `devices` table.
- The sidebar device list reads from the same database and creates folders under `app/backup/`.

Most deep routing/DHCP/NAT/ACL bridge functions are currently safe stubs so the overall UI can open while the C++ repositories are ported incrementally.
