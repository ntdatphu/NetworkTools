import os
import sys
from dotenv import load_dotenv, find_dotenv

# 1. RADAR TỰ ĐỘNG MÒ TÌM FILE .env TỪ BẤT CỨ ĐÂU
env_path = find_dotenv()
if not env_path:
    raise Exception("[-] LỖI CRITICAL: Không tìm thấy file .env! Vui lòng tạo file .env ở gốc dự án.")

load_dotenv(env_path)

# 2. XÁC ĐỊNH TỌA ĐỘ GỐC DỰ ÁN
PROJECT_ROOT = os.path.dirname(env_path)

# Ép Python nhận diện gốc dự án để tránh lỗi ModuleNotFoundError khi các file gọi nhau
if PROJECT_ROOT not in sys.path:
    sys.path.append(PROJECT_ROOT)

# 3. LẮP RÁP CÁC ĐƯỜNG DẪN TRUNG TÂM
db_rel_path = os.getenv("DB_RELATIVE_PATH", "backend/core_services/database/device_network.db")

# Dùng split("/") thay vì join thẳng để tương thích mượt mà cả Windows (dấu \) và Linux (dấu /)
DB_PATH = os.path.join(PROJECT_ROOT, *db_rel_path.split("/"))
BACKUP_DIR = os.path.join(PROJECT_ROOT, "backend", "core_services", "database", "backup")
TMP_DIR = os.path.join(PROJECT_ROOT, "Tmp")

DEFAULT_SSH_TIMEOUT = 60

# =====================================================================
# 4. ĐƯỜNG DẪN CÁC FILE GIAO TIẾP JSON (I/O) CHO TỪNG MODULE
# =====================================================================
# --- Module Interface ---
INTERFACE_INPUT = os.path.join(TMP_DIR, "interface_input.json")
INTERFACE_OUTPUT = os.path.join(TMP_DIR, "interface_output.json")

# --- Module DHCP ---
DHCP_INPUT = os.path.join(TMP_DIR, "dhcp_input.json")
DHCP_OUTPUT = os.path.join(TMP_DIR, "dhcp_output.json")

# --- Module Routing (OSPF, Static, EIGRP...) ---
ROUTE_INPUT = os.path.join(TMP_DIR, "route_input.json")
ROUTE_OUTPUT = os.path.join(TMP_DIR, "route_output.json")

# (Sau này có module ACL, NAT thì sếp cứ táng thêm vào đây)