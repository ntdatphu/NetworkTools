# SFTP

Trạng thái: **implemented** cho client tích hợp một session.

Feature sở hữu kết nối Paramiko, xác minh host key SHA-256, hai file panel,
profile, local/remote navigation và transfer queue. QML ở `UI/qml/sftp/` và
`UI/qml/panels/SftpConnectionsPanel.qml`; public context là `sftpController`.

| File | Trách nhiệm |
| --- | --- |
| `controller.py` | QObject state, QSettings, profile, history, queue và slot QML |
| `sftp_service.py` | SSH/SFTP, host key, list và file operation remote |
| `local_service.py` | File operation local có giới hạn an toàn |
| `file_model.py` | Metadata/role của hai panel |
| `transfer_model.py` | Trạng thái/progress của transfer |
| `credential_store.py` | Windows DPAPI current-user; không fallback plaintext |
| `workers.py` | QRunnable cho blocking operation |

Folder delete không đệ quy; symlink không được upload khi duyệt thư mục. Cancel
là cooperative quanh lời gọi Paramiko, không phải transactional rollback. Profile
JSON không chứa plaintext password; lưu password tắt mặc định và chỉ bật khi
DPAPI khả dụng. External Tools có thể mở client SFTP ngoài nhưng cấm
`{password}` trên argv.

Hướng dẫn vận hành, shortcut, threat boundary và giới hạn đầy đủ:
[`../../../docs/SFTP.md`](../../../docs/SFTP.md). Test chính:
`tests/test_sftp_client.py`, `tests/test_external_tools.py`, UI contract và QML
smoke.
