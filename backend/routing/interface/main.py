import os
import json
import sys

# =====================================================================
# 1. BẬT RADAR TÌM GỐC DỰ ÁN TRƯỚC KHI IMPORT BẤT CỨ THỨ GÌ
# =====================================================================
# Lấy thư mục chứa file main.py hiện tại (thư mục 'interface')
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))

# Lùi 3 cấp để về gốc dự án: interface -> router_layer3 -> PyCode -> GỐC
PROJECT_ROOT = os.path.abspath(os.path.join(CURRENT_DIR, "../../../"))

# Nhét cái Gốc dự án vào hệ thống để nó biết đường tìm thư mục PyCode
if PROJECT_ROOT not in sys.path:
    sys.path.append(PROJECT_ROOT)

# Thêm luôn thư mục hiện tại để gọi file router_interface.py nằm cùng chỗ
if CURRENT_DIR not in sys.path:
    sys.path.append(CURRENT_DIR)

# =====================================================================
# 2. BÂY GIỜ MỚI GỌI CONFIG VÀ CÁC MODULE KHÁC
# =====================================================================
# GỌI THẲNG ĐƯỜNG DẪN FILE I/O VÀ DATABASE TỪ TRẠM RADAR
from backend.core_services.config import DB_PATH, INTERFACE_INPUT, INTERFACE_OUTPUT

try:
    from router_interface import run_interface_config
except ImportError as e:
    print(f"[-] Lỗi Import: Không tìm thấy file 'router_interface.py'!\n    Chi tiết: {e}")
    sys.exit(1)

def interface_dispatcher():
    print(f"[*] [Interface Main] Đường dẫn Database: {DB_PATH}")

    if not os.path.exists(DB_PATH):
        print(f"[-] LỖI: Không tìm thấy file Database '{DB_PATH}'!")
        return

    print(f"[*] [Interface Main] Đang quét yêu cầu tại: {INTERFACE_INPUT}")

    if os.path.exists(INTERFACE_INPUT):
        try:
            with open(INTERFACE_INPUT, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            task_list = data if isinstance(data, list) else [data]
            first_task = task_list[0] if task_list else {}
            task_module = first_task.get("module") 

            if task_module == "interface":
                print(f"[*] [Interface Main] Chuyển {len(task_list)} tác vụ cho Worker...")
                
                #  Truyền biến INTERFACE_OUTPUT sang Worker
                run_interface_config(task_list, INTERFACE_OUTPUT)
            else:
                print(f"[-] [Interface Main] Bỏ qua. Module '{task_module}' không thuộc thẩm quyền của Interface Main.")

        except json.JSONDecodeError:
            print(f"[-] Lỗi: File JSON input bị lỗi cú pháp.")
        except Exception as e:
            print(f"[-] Lỗi xử lý: {e}")
    else:
        print(f"[-] Không tìm thấy file Input tại: {INTERFACE_INPUT}")

if __name__ == "__main__":
    interface_dispatcher()