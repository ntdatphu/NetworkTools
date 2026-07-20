# SFTP

Truyền file hai panel qua SFTP. **implemented**, ngoài nhóm network feature cốt lõi nhưng được quản lý như feature độc lập. QML `qml/sftp/SftpView.qml`; API `SftpController`; implementation `features/sftp`. Không lưu secret vào log; transfer chạy worker và shutdown khi app thoát. Test: `test_sftp_client.py` (yêu cầu Paramiko).
