#import "../config/commands.typ": appendix-heading, todo

#appendix-heading[PHỤ LỤC A. HƯỚNG DẪN CÀI ĐẶT VÀ CHẠY]

== Yêu cầu hệ thống

- Python và các dependency đúng với phiên bản chốt của dự án.
- Môi trường Windows hoặc Linux theo phạm vi thử nghiệm.
- Thiết bị Cisco IOS thật hoặc lab EVE-NG/GNS3 khi chạy thử kết nối thật.

== Chạy ứng dụng

```bash
cd app
uv run python main.py
```

== Chạy kiểm thử

```powershell
cd app
$env:UV_CACHE_DIR = ".uv-cache"
uv run python -m unittest discover -s tests -v
```

#todo[Bổ sung quy trình build database và các lỗi thường gặp theo phiên bản mã nguồn cuối cùng.]
