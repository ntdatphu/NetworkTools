import os
from ciscoconfparse import CiscoConfParse
from backend.PyCode.share.config import DB_PATH, BACKUP_DIR

# IMPORT CÁC THỢ PHỤ L3
from backend.PyCode.sync.sync_interface import sync_interface_worker
from backend.PyCode.sync.sync_routing import sync_eigrp_worker, sync_ospf_worker
from backend.PyCode.sync.sync_dhcp import sync_dhcp_worker
from backend.PyCode.sync.sync_acl import sync_acl_worker
from backend.PyCode.sync.sync_nat import sync_nat_worker

# IMPORT CÁC THỢ PHỤ L2 (MỚI)
from backend.PyCode.sync.sync_l2_vlan import sync_l2_vlan_worker
from backend.PyCode.sync.sync_l2_interface import sync_l2_interface_worker

class SyncManager:
    def __init__(self):
        self.db_path = DB_PATH
        self.backup_dir = BACKUP_DIR
        self.sync_pipeline_l3 = [
            sync_interface_worker, sync_ospf_worker, sync_dhcp_worker,
            sync_acl_worker, sync_nat_worker, sync_eigrp_worker
        ]

    def trigger_sync(self, target: str) -> bool:
        overall_status = True
        print(f"\n[*] [SYNC MANAGER] BẮT ĐẦU ĐỌC FILE VÀ BĂM DỮ LIỆU (OFFLINE MODE) CHO {target.upper()}")
        
        if target.lower() == "all":
            if not os.path.exists(self.backup_dir):
                print(f"[-] SYNC LỖI: Thư mục backup không tồn tại tại {self.backup_dir}")
                return False
            
            hosts = [d for d in os.listdir(self.backup_dir) if os.path.isdir(os.path.join(self.backup_dir, d))]
            if not hosts: return False
                
            for host_ip in hosts:
                if not self._sync_single_host(host_ip): overall_status = False
        else:
            overall_status = self._sync_single_host(target)

        print("\n[+] SYNC MANAGER: Đã hoàn tất TOÀN BỘ quy trình cập nhật Database!")
        return overall_status

    def _sync_single_host(self, host_ip: str) -> bool:
        # === 1. XỬ LÝ L3 (Routing / DHCP / ACL...) ===
        config_file = os.path.join(self.backup_dir, host_ip, f"{host_ip}_running-config.txt")
        if os.path.exists(config_file):
            try:
                with open(config_file, 'r', encoding='utf-8') as f:
                    config_lines = f.read().splitlines()
                parse_obj = CiscoConfParse(config_lines, factory=True)
                for worker in self.sync_pipeline_l3:
                    try: worker(host_ip, parse_obj, self.db_path)
                    except Exception as e: print(f"[-] Lỗi {worker.__name__}: {e}")
            except Exception as e:
                print(f"[-] SYNC L3 CRASH trên {host_ip}: {e}")

        # === 2. XỬ LÝ L2 (VLAN / MAC / Interface) OFFLINE ===
        print(f"  [*] Đang xử lý trạng thái L2 (VLAN/Interface) cho {host_ip}...")
        try:
            sync_l2_vlan_worker(host_ip)
            sync_l2_interface_worker(host_ip)
        except Exception as e:
            print(f"[-] SYNC L2 CRASH trên {host_ip}: {e}")
            return False

        return True