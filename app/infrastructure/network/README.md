# Network infrastructure

Nơi đặt connector, registry session và command runner dùng chung. Connector phải che giấu thư viện transport; registry sở hữu vòng đời/timeout và đóng session khi tab/app đóng. Không log password/private key; lỗi trả về dạng có cấu trúc. Worker feature không tạo cơ chế cache session riêng.
