# System infrastructure

Các adapter phụ thuộc hệ điều hành nhưng không phụ thuộc Qt: đọc RAM, interface/IP/SSID và mở terminal/process. Facade trong `core` chỉ chuyển kết quả thành property/signal cho QML. Mọi hàm public phải có docstring, không log credential và phải có fallback an toàn trên nền tảng không hỗ trợ.
