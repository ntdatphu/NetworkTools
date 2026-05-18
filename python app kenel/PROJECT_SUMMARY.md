# Project Summary - Python App Kenel

## 1. Tong quan

`python app kenel` la mot ung dung CLI Python dung de quan ly database SQLite cho NetworkTools va thu nghiem ket noi truc tiep vao thiet bi mang qua Netmiko. Thu muc nay dong vai tro nhu mot "kernel/tooling" rieng cho:

- Tao hoac cap nhat `device_network.db` tu SQL schema.
- Luu duong dan database/schema vao `database_paths.json`.
- Mo phien login SSH/Telnet den router/switch Cisco IOS.
- Cung cap file setup moi truong Python bang `uv`.

Day khong phai UI desktop; no la command-line app chay qua `main.py`.

## 2. Cong nghe va phu thuoc

- Ngon ngu: Python.
- Database: SQLite, thao tac qua module standard `sqlite3`.
- Device connection: Netmiko.
- Quan ly package/venv: `uv`, cau hinh trong `pyproject.toml`.
- Cac dependency du kien:
  - `netmiko`, `ncclient`
  - `nornir`, `nornir-netmiko`
  - `requests`, `urllib3`
  - `Jinja2`, `PyYAML`
  - `pyshark`, `scapy`, `napalm`

Luu y: `pyproject.toml` hien khai bao `requires-python = ">=3.10"` de setup bang `uv` co the chay tren cac moi truong Python pho bien hon.

## 3. Cau truc thu muc

- `main.py`: entry point CLI. Chua vong lap lenh, logic tao database, doc/ghi JSON path va goi login device.
- `login/device_connector.py`: wrapper Netmiko de connect, disconnect, gui command va mo interactive CLI.
- `login/login(demo).py`: file demo ket noi router va chay lenh `show ip interface brief`.
- `login/__init__.py`: marker package cho module `login`.
- `sql/main.sql`: schema SQL tong hop cho database mang.
- `device_network.db`: SQLite database hien co.
- `database_paths.json`: file JSON luu path den `main.sql` va `device_network.db`.
- `pyproject.toml`: metadata va dependency Python.
- `setup.bat`: script Windows kiem tra/cai `uv`, tao `.venv`, cai package tu `pyproject.toml`.
- `PROJECT_SUMMARY.md`: file tong hop nay.

## 4. Entry point va lenh CLI

Chay ung dung bang:

```powershell
python main.py
```

Khi khoi dong, CLI hien menu lenh:

- `cre database`: tim cac file SQL danh so dang `NN_*.sql`, merge vao `sql/main.sql`, execute SQL de tao/cap nhat `device_network.db`, sau do ghi `database_paths.json`.
- `--init-db --sql <main.sql> --db <device_network.db>`: che do non-interactive cho frontend Qt goi truc tiep de chuyen `main.sql` thanh database SQLite.
- `find database`: execute `sql/main.sql` hien co de cap nhat database va ghi lai JSON path.
- `login <host> <method> <port> <user> <pass>`: goi `login_device()` de ket noi thiet bi.
- `info paths`: in cac path dang cau hinh trong app.
- `info json`: doc va in noi dung `database_paths.json`.
- `info sql`: hien danh sach file SQL con duoc discover.
- `exit`: thoat CLI.

Neu import duoc `readline`, CLI co them lich su lenh bang phim len/xuong. Tren Windows, comment trong code goi y cai `pyreadline`.

## 5. Luong tao database

`main.py` dinh nghia cac path:

```python
WORKSPACE_ROOT = "E:\\python app kenel"
SQL_DIR = os.path.join(WORKSPACE_ROOT, "sql")
MAIN_SQL = os.path.join(SQL_DIR, "main.sql")
DB_FILE = os.path.join(WORKSPACE_ROOT, "device_network.db")
JSON_FILE = os.path.join(WORKSPACE_ROOT, "database_paths.json")
```

Luong `cre database`:

1. `get_sql_files()` tim cac file trong `sql/` co pattern `NN_*.sql`.
2. `merge_sql_files()` ghi noi dung cac file tim duoc vao `main.sql`.
3. `create_db()` mo SQLite database va chay `conn.executescript(sql_script)`.
4. `save_paths()` ghi path vao `database_paths.json`.

Trong thu muc hien tai chi thay `sql/main.sql`, khong thay cac file `NN_*.sql`. Vi vay `cre database` co nguy co ghi de `main.sql` thanh file rong neu `SQL_FILES` rong.

## 6. Schema database

`sql/main.sql` la schema lon cho thiet bi mang. Cac nhom bang chinh gom:

- Device inventory: `devices`, `yangcfg`.
- Interface/router interface: `interface_name`, `router_iface_l3`, `router_iface_subif`, `router_iface_tunnel`, `router_iface_wan`, `router_iface_qos`, `router_iface_helper`.
- DHCP: `dhcp_pool`, `excluded_address`.
- Static routing: `static_default_routes`, `static_routes`.
- OSPF: `ospf_processes`, `ospf_networks`, `ospf_distance`, `ospf_areas`, `ospf_area_ranges`, `ospf_redistribute`, `ospf_passive_interfaces`, `ospf_tuning`, `ospf_interface_settings`, `router_iface_ospf`.
- EIGRP: `eigrp_processes`, `eigrp_networks`, `eigrp_interface_settings`, `router_iface_eigrp`, `eigrp_passive_interfaces`, `eigrp_distribute_lists`, `eigrp_offset_lists`, `eigrp_redistribute`, `eigrp_key_chains`.
- ACL: `ACL_DB`, `standard_acl_rules`, `extended_acl_rules`, `dynamic_acl_rules`, `reflexive_acl_rules`, `mac_acl_rules`, `router_iface_acl`.
- NAT: `NAT_DB`, `NAT_ACL_DB`, `nat_interfaces`, `router_iface_nat`, `nat_pools`, `nat_static_mappings`, `nat_dynamic_rules`, `nat_overload_interface_rules`, `nat_exempt_rules`, NAT ACL rule tables.
- Layer 2/VLAN: `vlan_db`, `interface_l2`, `iface_access`, `iface_trunk`, `iface_stp`, `iface_port_security`, `iface_qos`, `iface_storm_control`, `iface_monitor`, `iface_mac_table`, `etherchannel`, `stp_config`, `security_l2`, `dhcp_trust_ports`, `svi_interface`.

Schema nay co do phu rong hon nhieu so voi logic CLI hien tai. CLI chi tao/cap nhat database; viec doc/ghi chi tiet cac bang cau hinh duong nhu nam o frontend C++/QML hoac cac tool backend khac.

## 7. Luong login thiet bi

`main.py` xu ly lenh:

```text
login <host> <method> <port> <user> <pass>
```

Sau do goi:

```python
login_device(host, method, port, username, password, device_type="cisco_ios")
```

`login/device_connector.py`:

- Tao class `DeviceConnector`.
- Dung `ConnectHandler` cua Netmiko.
- Neu method la `telnet`, doi `device_type` thanh `cisco_ios_telnet`.
- Xu ly cac loi chinh:
  - `NetmikoTimeoutException`
  - `NetmikoAuthenticationException`
  - `ConnectionException`
- Sau khi connect thanh cong, mo interactive CLI voi prompt:

```text
>>(host)>
```

Trong interactive mode:

- Nhap bat ky CLI command nao de gui sang thiet bi.
- `quit` hien help ngan.
- `exit` dong phien va disconnect.

## 8. Setup moi truong

`setup.bat` thuc hien:

1. Kiem tra `uv`.
2. Neu chua co, cai `uv` bang PowerShell installer tu `https://astral.sh/uv/install.ps1`.
3. Tao `.venv` bang `uv venv`.
4. Cai package editable bang:

```powershell
uv pip install -e .
```

5. Kich hoat `.venv\Scripts\activate` neu ton tai.

Script nay phu hop Windows. Neu muon dung trong frontend Qt sau build, can dong bo voi co che `setup_venv.bat/setup_venv.sh` o thu muc backend hien tai.

## 9. Diem can chu y

- Path da duoc doi sang tinh dong theo vi tri `main.py`, giup kernel chay duoc sau khi CMake copy vao thu muc output cua frontend.
- `database_paths.json` trong source hien tro den `E:\NetworkTools\python app kenel\...`; khi frontend goi non-interactive, file JSON trong ban copy output se duoc ghi theo path output.
- `cre database` chi merge cac file `NN_*.sql`; hien tai khong thay file nao khop pattern nay. Neu chay lenh, `main.sql` co the bi ghi lai khong dung mong doi.
- `main.py` import `sys` nhung chua dung.
- `login/device_connector.py` import `sys` nhung chua dung.
- Nhieu chuoi output/comment trong file hien bi loi encoding khi doc tu terminal, nen chuan hoa UTF-8 de tranh kho bao tri.
- Mat khau duoc nhap qua command line va truyen thang vao Netmiko. Cach nay de lo trong history/terminal; nen can can nhac prompt password an ky tu hoac lay tu secret store.
- `device_network.db` la binary database duoc commit/luu trong thu muc code. Can xac dinh day la sample database hay runtime artifact.
- Ten thu muc `kenel` co ve la typo cua `kernel`; neu doi ten can cap nhat toan bo path/script lien quan.

## 10. De xuat cai thien

- Doi path hard-code sang duong dan dong:

```python
WORKSPACE_ROOT = os.path.dirname(os.path.abspath(__file__))
```

- Bao ve `merge_sql_files()` de khong ghi de `main.sql` khi khong co file `NN_*.sql`.
- Giu `requires-python` dong bo voi runtime that su dang dung tren may dev/build.
- Dung `getpass.getpass()` cho password trong lenh login.
- Tach phan CLI command parser, database service va device connector thanh module rieng neu ung dung tiep tuc lon len.
- Them README/cach chay ngan gon va ghi ro quan he giua thu muc nay voi `frontend` va `backend`.
- Neu day la runtime kernel cho NetworkTools, nen hop nhat voi folder `backend` hien duoc frontend copy sau build de tranh trung lap schema/script.
