# Network infrastructure

Nơi đặt connector, registry session và command runner dùng chung. Connector phải che giấu thư viện transport; registry sở hữu vòng đời/timeout và đóng session khi tab/app đóng. Không log password/private key; lỗi trả về dạng có cấu trúc. Worker feature không tạo cơ chế cache session riêng.

`DeviceConnector.collect_running_config()` chỉ thu thập output; feature `config_backup` quyết định path, ghi file và commit. `save_running_config()` là adapter tương thích cho interactive CLI cũ.
