import os
import json
import sys

# --- IMPORT WORKER MỚI LÀM ---
try:
    from worker_dhcp import run_dhcp_worker
except ImportError as e:
    print(f"[-] Lỗi Import: Không tìm thấy worker_dhcp! Chi tiết: {e}")
    sys.exit(1)

CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(CURRENT_DIR, "..", "..", "..", ".."))

def dhcp_dispatcher():
    INPUT_FILE = os.path.join(PROJECT_ROOT, "Tmp", "dhcp_input.json")
    OUTPUT_FILE = os.path.join(PROJECT_ROOT, "Tmp", "dhcp_output.json") # File UI sẽ đọc
    DB_FILE = os.path.join(PROJECT_ROOT, "PyCode", "share", "database", "device_network.db")

    print(f"[*] [DHCP Module] Đang lắng nghe tại: {INPUT_FILE}")

    if os.path.exists(INPUT_FILE):
        try:
            with open(INPUT_FILE, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            task_list = data if isinstance(data, list) else [data]
            
            print(f"[+] Đã nhận {len(task_list)} yêu cầu DHCP. Đang xử lý...")
            # GỌI WORKER THỰC THI (Đã mở khóa)
            run_dhcp_worker(task_list, DB_FILE, OUTPUT_FILE)

        except Exception as e:
            print(f"[-] Lỗi xử lý DHCP: {e}")

if __name__ == "__main__":
    dhcp_dispatcher()