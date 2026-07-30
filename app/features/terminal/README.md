# Internal terminal

Trạng thái: **implemented** cho SSH/Telnet qua session Netmiko của app.

Terminal tương tác do NetworkTools quản lý, không gọi PuTTY, Windows Terminal,
GNOME Terminal, Konsole hay `xterm`.

- `manager.py` sở hữu tối đa một cửa sổ/worker cho mỗi host và dừng worker trước
  khi registry đóng session.
- `worker.py` giữ `SessionEntry.operation_lock` trong suốt phiên tương tác,
  đọc/ghi Netmiko channel ở background thread và không để lệnh push xen vào.
- `stream.py` giữ CR/LF đúng ngữ nghĩa terminal và lọc NUL/`^@` từ console IOS
  ảo trước khi dữ liệu đi vào parser.
- `window.py` nhúng widget từ `qtpyTerminal-main`, nối external transport callback
  với worker và gom output theo batch 20 ms.
- `qtpyTerminal-main/` là source MIT được vendor trong repo. Bản điều chỉnh thêm
  external backend không fork PTY/shell, parser Pyte, scrollback và renderer
  dirty-line trên `QPlainTextEdit`.

Thanh cuộn dọc hoặc con lăn chuột duyệt history; `Ctrl+Shift+C/V` copy/paste;
`Tab` hoàn thành lệnh Cisco; các phím Ctrl và navigation được gửi thẳng đến
thiết bị. Caret luôn theo cursor VT của Pyte; kéo chuột vẫn chọn text để copy.

Host đang ở `Up (Dev)` không được phép mở kết nối mạng thật. Manager kiểm tra
inventory trước khi tạo cửa sổ và hướng dẫn người dùng chuyển `Down (Dev)`, sau
đó `Connect`; registry cũng kiểm tra lại policy này trước khi gọi worker để
không bao giờ truyền connector rỗng vào interactive loop.
