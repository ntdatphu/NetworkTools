import os
from ciscoconfparse import CiscoConfParse

# IMPORT CẤU HÌNH TỪ CONFIG.PY 
from backend.PyCode.share.config import DB_PATH, BACKUP_DIR

# IMPORT CÁC THỢ PHỤ 
from backend.PyCode.sync.sync_interface import sync_interface_worker
from backend.PyCode.sync.sync_routing import sync_ospf_worker
from backend.PyCode.sync.sync_dhcp import sync_dhcp_worker
from backend.PyCode.sync.sync_acl import sync_acl_worker
from backend.PyCode.sync.sync_nat import sync_nat_worker

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
            sync_dhcp_worker,
            sync_acl_worker,
            sync_nat_worker
        ]

    def trigger_sync(self, target: str) -> bool:
        """
        Nhận target từ API. Nếu là 'all' thì quét toàn bộ thư mục backup.
        """
        if target.lower() == "all":
            print("\n[+] SYNC MANAGER: Kích hoạt đồng bộ TOÀN BỘ thiết bị...")
            if not os.path.exists(self.backup_dir):
                print(f"[-] SYNC LỖI: Thư mục backup không tồn tại tại {self.backup_dir}")
                return False
            
            # Quét các thư mục con trong folder backup (mỗi folder là 1 IP)
            hosts = [d for d in os.listdir(self.backup_dir) if os.path.isdir(os.path.join(self.backup_dir, d))]
            
            if not hosts:
                print("[-] SYNC: Không tìm thấy thiết bị nào trong thư mục backup.")
                return False
                
            overall_status = True
            for host_ip in hosts:
                if not self._sync_single_host(host_ip):
                    overall_status = False
            
            print("\n[+] SYNC MANAGER: Hoàn thành đồng bộ TOÀN BỘ thiết bị!")
            return overall_status
        else:
            # Nếu truyền IP cụ thể thì chạy 1 thằng
            return self._sync_single_host(target)

    def _sync_single_host(self, host_ip: str) -> bool:
        """
        Hàm xử lý lõi cho 1 thiết bị đơn lẻ
        """
        # Đường dẫn ghép chuẩn xác: .../backup/<host_ip>/<host_ip>_running-config.txt
        config_file = os.path.join(self.backup_dir, host_ip, f"{host_ip}_running-config.txt")
        
        if not os.path.exists(config_file):
            print(f"[-] SYNC LỖI: Không tìm thấy file {config_file}")
            return False

        print(f"\n SYNC MANAGER: Đang băm file config của {host_ip}...")
        
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
            
            print(f" SYNC MANAGER: Xong quy trình đồng bộ {host_ip}\n")
            return True
            
        except Exception as e:
            print(f"[-] SYNC MANAGER CRASH trên {host_ip}: {e}")
            return False