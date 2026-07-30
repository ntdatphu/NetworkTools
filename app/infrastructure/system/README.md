# System infrastructure

Các adapter phụ thuộc hệ điều hành nhưng không phụ thuộc Qt: đọc RAM,
interface/IP/SSID và tài nguyên hệ thống. Terminal thiết bị đã chuyển sang
`features/terminal` để dùng cửa sổ do app quản lý, không gọi process terminal
ngoài. Facade trong `core` chỉ chuyển kết quả thành property/signal cho QML.
Mọi hàm public phải có docstring, không log credential và phải có fallback an
toàn trên nền tảng không hỗ trợ.
