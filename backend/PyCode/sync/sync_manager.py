import os
from ciscoconfparse import CiscoConfParse

# IMPORT CẤU HÌNH TỪ CONFIG.PY 
from backend.PyCode.share.config import DB_PATH, BACKUP_DIR

# IMPORT CÁC THỢ PHỤ 
from backend.PyCode.sync.sync_interface import sync_interface_worker
from backend.PyCode.sync.sync_routing import sync_ospf_worker
from backend.PyCode.sync.sync_dhcp import sync_dhcp_worker


class SyncManager:
    """
    FILE QUẢN LÝ CHUNG MODULE SYNC (Backend Thuần)
    """
    def __init__(self):
        # Lấy trực tiếp từ config.py
        self.db_path = DB_PATH
        self.backup_dir = BACKUP_DIR
        
        self.sync_pipeline = [
            sync_interface_worker,
            sync_ospf_worker,
            sync_dhcp_worker
        ]

    def trigger_sync(self, host_ip: str) -> bool:
        # Đường dẫn ghép chuẩn xác: .../backup/<host_ip>/<host_ip>_running-config.txt
        config_file = os.path.join(self.backup_dir, host_ip, f"{host_ip}_running-config.txt")
        
        if not os.path.exists(config_file):
            print(f"[-] SYNC LỖI: Không tìm thấy file {config_file}")
            return False

        print(f"\n[🚀] SYNC MANAGER: Đang băm file config của {host_ip}...")
        
        try:
            with open(config_file, 'r', encoding='utf-8') as f:
                config_lines = f.read().splitlines()

            # Băm file bằng thư viện ciscoconfparse
            parse_obj = CiscoConfParse(config_lines, factory=True)

            for worker in self.sync_pipeline:
                try:
                    worker(host_ip, parse_obj, self.db_path)
                except Exception as worker_err:
                    print(f"[-] Lỗi tại thợ phụ {worker.__name__}: {worker_err}")
            
            print(f"[✅] SYNC MANAGER: Xong quy trình đồng bộ {host_ip}\n")
            return True
            
        except Exception as e:
            print(f"[-] SYNC MANAGER CRASH: {e}")
            return False