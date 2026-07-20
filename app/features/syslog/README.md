# Syslog

UDP/TCP listener, parser, batch writer, filter/page, device configuration, lifecycle và retention. **implemented**. QML `qml/features/syslog/SyslogWorkspace.qml`; public API `SyslogManager`/settings; implementation `features/syslog`; DB info_collected và device inventory. Receiver không ghi DB trên UI thread; writer batch, retention/index được quản lý bởi repository/schema. Test đầy đủ trong `tests/syslog`. Backlog: chuyển namespace feature và đo tải dài hạn.
