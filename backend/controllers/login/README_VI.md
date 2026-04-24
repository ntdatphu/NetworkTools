# Login Script - 2 phiên bản

## 1) Phiên bản DB (theo plan)
File chạy: login_new.py

Mục tiêu:
- Đọc thiết bị từ SQLite devices
- Login theo SSH/TELNET (netmiko), RESTCONF (requests), NETCONF (ncclient)
- Cập nhật success, os, role vào bảng devices
- Tùy chọn parse và ghi routing tables + ACL_DB

Lệnh chạy:
- Windows:
  python login_new.py --db "..\..\device_network.db" --write-routing-acl
- Linux:
  python3 login_new.py --db ../../device_network.db --write-routing-acl

## 2) Phiên bản thủ công JSON (không DB)
File chạy: manual_json_login.py

Mục tiêu:
- Đọc danh sách thiết bị từ file JSON
- Login theo giao thức tương tự
- Ghi kết quả ra file JSON output
- Không tương tác DB

Ghi chú giao thức:
- SSH/TELNET: netmiko
- RESTCONF: requests
- NETCONF: ncclient

Lệnh chạy:
- Windows:
  python manual_json_login.py --input manual_input_example.json --output manual_output.json
- Linux:
  python3 manual_json_login.py --input manual_input_example.json --output manual_output.json

## 3) Phien ban connect host chi dinh (dung cho context menu Connec)
File chay: connect_selected.py

Muc tieu:
- Nhan danh sach host chi dinh (thuc te UI truyen 1 host duoc right-click)
- Mac dinh chi xu ly ban ghi co `success = 0`
- Login theo `method` trong DB (`SSH`/`TELNET`)
- Login thanh cong: cap nhat `success = 1`, `os`, `role`
- Login that bai: giu `success = 0`

Luat suy role:
- `rou`: co route (`show ip route`)
- `sw2`: co vlan (`show vlan` hoac fallback `show vl`)
- `sw3`: co ca route va vlan

Lenh chay:
- Windows:
  python connect_selected.py --db "..\..\device_network.db" --hosts "10.10.20.172"
- Linux:
  python3 connect_selected.py --db ../../device_network.db --hosts "10.10.20.172"

## Cài thư viện
- Windows:
  python -m venv .venv
  .\.venv\Scripts\activate
  pip install -r requirements.txt

- Linux:
  python3 -m venv .venv
  source .venv/bin/activate
  pip install -r requirements.txt
