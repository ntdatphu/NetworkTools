import os
import sys
from dotenv import load_dotenv, find_dotenv

# =========================================================
# 1. RADAR TỰ ĐỘNG MÒ TÌM GỐC DỰ ÁN QUA FILE .env
# =========================================================
env_path = find_dotenv()
if not env_path:
    raise Exception("[-] LỖI CRITICAL: Không tìm thấy file .env! Vui lòng tạo file .env ở gốc dự án.")

load_dotenv(env_path)

# PROJECT_ROOT đang là thư mục NetworkTools (vì chứa file .env)
PROJECT_ROOT = os.path.dirname(env_path)

# Cực kỳ quan trọng: Thêm backend vào sys.path để các module Python nhận diện được nhau
BACKEND_DIR = os.path.join(PROJECT_ROOT, "backend")
if BACKEND_DIR not in sys.path:
    sys.path.append(BACKEND_DIR)

# =========================================================
# 2. ĐƯỜNG DẪN DATABASE & BACKUP (GLOBAL)
# =========================================================
# Đường dẫn tương đối lấy từ file .env. 
# CHÚ Ý: Nếu file .env của sếp đang có dòng DB_RELATIVE_PATH, sếp phải sửa nó thành backend/PyCode/... nhé!
db_rel_path = os.getenv("DB_RELATIVE_PATH", "backend/PyCode/share/database/device_network.db")

# Đã thêm "backend" vào tất cả các đường dẫn!
DB_DEVICE_NETWORK = os.path.join(PROJECT_ROOT, *db_rel_path.split("/"))
BACKUP_DIR = os.path.join(PROJECT_ROOT, "backend", "PyCode", "share", "database", "backup")
TMP_DIR = os.path.join(PROJECT_ROOT, "backend", "Tmp")

# Đảm bảo thư mục TMP và Backup luôn tồn tại
os.makedirs(TMP_DIR, exist_ok=True)
os.makedirs(BACKUP_DIR, exist_ok=True)

DEFAULT_SSH_TIMEOUT = 60

# =====================================================================
# 3. ĐƯỜNG DẪN CÁC FILE GIAO TIẾP JSON (I/O) CHO TỪNG MODULE
# =====================================================================
INTERFACE_INPUT = os.path.join(TMP_DIR, "interface_input.json")
INTERFACE_OUTPUT = os.path.join(TMP_DIR, "interface_output.json")

DHCP_INPUT = os.path.join(TMP_DIR, "dhcp_input.json")
DHCP_OUTPUT = os.path.join(TMP_DIR, "dhcp_output.json")

ROUTE_INPUT = os.path.join(TMP_DIR, "route_input.json")
ROUTE_OUTPUT = os.path.join(TMP_DIR, "route_output.json")

SECURITY_INPUT = os.path.join(TMP_DIR, "security_input.json")
SECURITY_OUTPUT = os.path.join(TMP_DIR, "security_output.json")

# Biến mới cho Module Login Export
FILE_LOGIN_EXPORT = os.path.join(TMP_DIR, "login_output.json")

# =========================================================
# 4. ĐƯỜNG DẪN CÁC THƯ MỤC TEMPLATE (JINJA2)
# =========================================================
# Thêm chữ "backend" vào đây luôn để Jinja2 không bị mù đường
SECURITY_DIR = os.path.join(PROJECT_ROOT, "backend", "PyCode", "security")
ACL_TEMPLATE_DIR = os.path.join(SECURITY_DIR, "ACL", "Templates")
DHCP_TEMPLATE_DIR = os.path.join(SECURITY_DIR, "DHCP", "Templates")

def get_acl_template_path(os_folder):
    """Truyền vào 'cisco_ios', trả về đường dẫn tới thư mục jinja2 tương ứng"""
    return os.path.join(ACL_TEMPLATE_DIR, os_folder)

# =========================================================
# 5. QUY HOẠCH TÊN BẢNG DATABASE (SINGLE SOURCE OF TRUTH)
# =========================================================
DB_TABLES = {
    "device_info": {
        "main": "devices" # Bảng chứa thông tin IP, User, Pass, Role thiết bị
    },
    "acl": {
        "main": "ACL_DB",
        "extended": "extended_acl_rules",
        "standard": "standard_acl_rules",
        "mac": "mac_acl_rules",
        "reflexive": "reflexive_acl_rules",
        "dynamic": "dynamic_acl_rules"
    },
    "dhcp_snooping": {
        "main": "dhcp_snooping_global",      
        "interfaces": "dhcp_snooping_ports"  
    }
}