import os
import sqlite3
from ciscoconfparse import CiscoConfParse

# 1. IMPORT CẤU HÌNH VÀ TIỆN ÍCH TỪ CONFIG
from backend.PyCode.share.config import DB_PATH, BACKUP_DIR, get_db_connection, DB_TABLES

# BỎ IMPORT DataCollector Ở ĐÂY! THẰNG SYNC KHÔNG CÒN QUYỀN ĐI SSH NỮA.

# 2. IMPORT CÁC THỢ PHỤ SYNC L3 (Băm file running-config)
from backend.PyCode.sync.sync_interface import sync_interface_worker
from backend.PyCode.sync.sync_routing import sync_eigrp_worker, sync_ospf_worker
from backend.PyCode.sync.sync_dhcp import sync_dhcp_worker
from backend.PyCode.sync.sync_acl import sync_acl_worker
from backend.PyCode.sync.sync_nat import sync_nat_worker

# 3. IMPORT CÁC THỢ PHỤ SYNC L2 (Băm file text trạng thái)
from backend.PyCode.sync.sync_l2_vlan import sync_vlan_worker
from backend.PyCode.sync.sync_l2_interface import sync_l2_interface_worker

class SyncManager:
    def __init__(self):
        self.db_path = DB_PATH
        self.backup_dir = BACKUP_DIR
        self.tbl_devices = DB_TABLES["device_info"]["main"]
        
        # Pipeline xử lý tĩnh L3 (Chỉ dành cho Router)
        self.sync_pipeline_l3 = [
            sync_interface_worker,
            sync_ospf_worker,
            sync_dhcp_worker,
            sync_acl_worker,
            sync_nat_worker,
            sync_eigrp_worker
        ]

    def _get_target_hosts_with_role(self, target: str) -> list:
        """Kết nối DB để lấy danh sách IP kèm theo Vai trò (Role)"""
        conn = get_db_connection()
        c = conn.cursor()
        if target.lower() != "all":
            c.execute(f"SELECT host, role FROM {self.tbl_devices} WHERE host = ?", (target,))
        else:
            c.execute(f"SELECT host, role FROM {self.tbl_devices}")
        rows = c.fetchall()
        conn.close()
        return rows

    def trigger_sync(self, target: str) -> bool:
        """Chỉ chuyên băm file vào DB, KHÔNG mở luồng SSH"""
        overall_status = True
        
        # 1. Lấy thông tin thiết bị và phân loại
        devices_info = self._get_target_hosts_with_role(target)
        if not devices_info:
            print("[-] [SYNC MANAGER] Không có thiết bị mục tiêu nào để đồng bộ.")
            return False

        routers = [ip for ip, role in devices_info if role and 'r' in str(role).lower() and 'sw' not in str(role).lower()]
        switches = [ip for ip, role in devices_info if role and 'sw' in str(role).lower()]

        print("\n[*] ===========================================================")
        print(f"[*] [SYNC MANAGER] BẮT ĐẦU ĐỌC FILE VÀ BĂM DỮ LIỆU (OFFLINE MODE)")
        print("[*] ===========================================================")

        # =================================================================
        # LUỒNG L3 (Chỉ chạy trên đám Router)
        # =================================================================
        if routers:
            print(f"\n[*] [SYNC MANAGER] XỬ LÝ CẤU HÌNH L3 ({len(routers)} ROUTERS)")
            for host_ip in routers:
                if not self._sync_single_host_l3(host_ip):
                    overall_status = False
        
        # =================================================================
        # LUỒNG L2 (Chỉ chạy trên đám Switch)
        # =================================================================
        if switches:
            print(f"\n[*] [SYNC MANAGER] XỬ LÝ TRẠNG THÁI L2 ({len(switches)} SWITCHES)")
            for host_ip in switches:
                sync_vlan_worker(host_ip)
                sync_l2_interface_worker(host_ip)

        print("\n[+] SYNC MANAGER: Đã hoàn tất TOÀN BỘ quy trình cập nhật Database!")
        return overall_status

    def _sync_single_host_l3(self, host_ip: str) -> bool:
        """Thợ chính chịu trách nhiệm mổ file running-config cho L3"""
        config_file = os.path.join(self.backup_dir, host_ip, f"{host_ip}_running-config.txt")
        if not os.path.exists(config_file):
            print(f"[-] [SYNC L3 LỖI] Không tìm thấy file {config_file}")
            return False

        print(f"[*] [SYNC L3] Đang băm file config của {host_ip}...")
        try:
            with open(config_file, 'r', encoding='utf-8') as f:
                config_lines = f.read().splitlines()

            parse_obj = CiscoConfParse(config_lines, factory=True)

            for worker in self.sync_pipeline_l3:
                try:
                    worker(host_ip, parse_obj, self.db_path)
                except Exception as worker_err:
                    print(f"  [-] Lỗi tại {worker.__name__}: {worker_err}")
            return True
            
        except Exception as e:
            print(f"[-] [SYNC L3 CRASH] Lỗi xử lý {host_ip}: {e}")
            return False