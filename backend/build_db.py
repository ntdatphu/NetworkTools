import sqlite3
import os

# =====================================================================
# 1. THIẾT LẬP ĐƯỜNG DẪN DATABASE
# =====================================================================
# Đường dẫn tương đối (Lưu DB vào thư mục hiện tại)
DB_PATH = "device_network.db" 

# Nếu sếp muốn trỏ đúng vào thư mục gốc của dự án, bỏ comment đoạn dưới:
# CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
# PROJECT_ROOT = os.path.abspath(os.path.join(CURRENT_DIR, "../../"))
# DB_PATH = os.path.join(PROJECT_ROOT, "PyCode", "share", "database", "device_network.db")

def create_and_seed_database():
    print(f"[*] Đang khởi tạo Database tại: {DB_PATH}")
    
    # Kết nối DB (sẽ tự tạo file mới nếu chưa có)
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Bật tính năng kiểm tra Khóa Ngoại (Foreign Key)
    cursor.execute("PRAGMA foreign_keys = ON;")
    
    try:
        # =====================================================================
        # 2. TẠO CẤU TRÚC BẢNG (SCHEMA)
        # =====================================================================
        print("[*] Đang xây dựng cấu trúc các bảng...")
        
        # Bảng Devices (Gốc)
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS devices (
                host TEXT PRIMARY KEY,
                device_name TEXT,
                os TEXT,
                method TEXT,
                portnumber INTEGER,
                username TEXT,
                password TEXT,
                success INTEGER DEFAULT 0
            )
        """)
        
        # Bảng OSPF Processes
        # Lưu ý: Cột ad là TEXT để chứa format "110-115-120", action là TEXT mặc định '111'
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS ospf_processes (
                ospf_id INTEGER PRIMARY KEY,
                host TEXT NOT NULL,
                process_id INTEGER,
                router_id TEXT,
                ad TEXT, 
                default_info INTEGER DEFAULT 0,
                auto_summary INTEGER DEFAULT 0,
                action TEXT DEFAULT '111',
                success INTEGER DEFAULT 0,
                FOREIGN KEY (host) REFERENCES devices (host) ON DELETE CASCADE
            )
        """)
        
        # Bảng OSPF Networks
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS ospf_networks (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                ospf_id INTEGER NOT NULL,
                network TEXT,
                wildcard TEXT,
                area INTEGER,
                success INTEGER DEFAULT 0,
                FOREIGN KEY (ospf_id) REFERENCES ospf_processes (ospf_id) ON DELETE CASCADE
            )
        """)

        # =====================================================================
        # 3. NẠP DỮ LIỆU MẪU (SEED DATA) CHO 10 NODE
        # =====================================================================
        print("[*] Đang nạp dữ liệu 10 Router Spine-Leaf...")
        
        # Dọn dẹp rác cũ nếu file DB đã tồn tại
        cursor.execute("DELETE FROM ospf_networks")
        cursor.execute("DELETE FROM ospf_processes")
        cursor.execute("DELETE FROM devices")

        # Nạp bảng devices
        devices_data = [
            ('192.168.121.101', 'vIOS1', 'cisco_ios', 'SSH', 22, 'cisco', 'cisco', 1),
            ('192.168.121.102', 'vIOS2', 'cisco_ios', 'SSH', 22, 'cisco', 'cisco', 1),
            ('192.168.121.103', 'vIOS3', 'cisco_ios', 'SSH', 22, 'cisco', 'cisco', 1),
            ('192.168.121.104', 'vIOS4', 'cisco_ios', 'SSH', 22, 'cisco', 'cisco', 1),
            ('192.168.121.105', 'vIOS5', 'cisco_ios', 'SSH', 22, 'cisco', 'cisco', 1),
            ('192.168.121.106', 'vIOS6', 'cisco_ios', 'SSH', 22, 'cisco', 'cisco', 1),
            ('192.168.121.107', 'vIOS7', 'cisco_ios', 'SSH', 22, 'cisco', 'cisco', 1),
            ('192.168.121.108', 'vIOS8', 'cisco_ios', 'SSH', 22, 'cisco', 'cisco', 1),
            ('192.168.121.109', 'vIOS9', 'cisco_ios', 'SSH', 22, 'cisco', 'cisco', 1),
            ('192.168.121.110', 'vIOS10', 'cisco_ios', 'SSH', 22, 'cisco', 'cisco', 1)
        ]
        cursor.executemany("""
            INSERT INTO devices (host, device_name, os, method, portnumber, username, password, success) 
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, devices_data)

        # Nạp bảng ospf_processes (action = 100)
        processes_data = [
            (1, '192.168.121.101', 1, '1.1.1.1', '100', 0),
            (2, '192.168.121.102', 1, '2.2.2.2', '100', 0),
            (3, '192.168.121.103', 1, '3.3.3.3', '100', 0),
            (4, '192.168.121.104', 1, '4.4.4.4', '100', 0),
            (5, '192.168.121.105', 1, '5.5.5.5', '100', 0),
            (6, '192.168.121.106', 1, '6.6.6.6', '100', 0),
            (7, '192.168.121.107', 1, '7.7.7.7', '100', 0),
            (8, '192.168.121.108', 1, '8.8.8.8', '100', 0),
            (9, '192.168.121.109', 1, '9.9.9.9', '100', 0),
            (10, '192.168.121.110', 1, '10.10.10.10', '100', 0)
        ]
        cursor.executemany("""
            INSERT INTO ospf_processes (ospf_id, host, process_id, router_id, action, success) 
            VALUES (?, ?, ?, ?, ?, ?)
        """, processes_data)

        # Nạp bảng ospf_networks
        networks_data = [
            (1, '10.0.12.0', '0.0.0.255', 0, 0), (1, '10.0.13.0', '0.0.0.255', 0, 0), (1, '10.0.16.0', '0.0.0.255', 0, 0), (1, '1.1.1.1', '0.0.0.0', 0, 0),
            (2, '10.0.12.0', '0.0.0.255', 0, 0), (2, '10.0.23.0', '0.0.0.255', 0, 0), (2, '10.0.24.0', '0.0.0.255', 0, 0), (2, '2.2.2.2', '0.0.0.0', 0, 0),
            (3, '10.0.13.0', '0.0.0.255', 0, 0), (3, '10.0.23.0', '0.0.0.255', 0, 0), (3, '10.0.35.0', '0.0.0.255', 0, 0), (3, '3.3.3.3', '0.0.0.0', 0, 0),
            (4, '10.0.24.0', '0.0.0.255', 0, 0), (4, '10.1.11.0', '0.0.0.255', 0, 0), (4, '4.4.4.4', '0.0.0.0', 0, 0),
            (5, '10.0.35.0', '0.0.0.255', 0, 0), (5, '10.1.12.0', '0.0.0.255', 0, 0), (5, '5.5.5.5', '0.0.0.0', 0, 0),
            (6, '10.0.16.0', '0.0.0.255', 0, 0), (6, '10.0.67.0', '0.0.0.255', 0, 0), (6, '6.6.6.6', '0.0.0.0', 0, 0),
            (7, '10.0.67.0', '0.0.0.255', 0, 0), (7, '10.0.70.0', '0.0.0.255', 0, 0), (7, '7.7.7.7', '0.0.0.0', 0, 0),
            (8, '10.0.108.0', '0.0.0.255', 0, 0), (8, '10.0.89.0', '0.0.0.255', 0, 0), (8, '10.1.13.0', '0.0.0.255', 0, 0), (8, '8.8.8.8', '0.0.0.0', 0, 0),
            (9, '10.0.109.0', '0.0.0.255', 0, 0), (9, '10.0.89.0', '0.0.0.255', 0, 0), (9, '10.1.14.0', '0.0.0.255', 0, 0), (9, '9.9.9.9', '0.0.0.0', 0, 0),
            (10, '10.0.70.0', '0.0.0.255', 0, 0), (10, '10.0.108.0', '0.0.0.255', 0, 0), (10, '10.0.109.0', '0.0.0.255', 0, 0), (10, '10.10.10.10', '0.0.0.0', 0, 0)
        ]
        cursor.executemany("""
            INSERT INTO ospf_networks (ospf_id, network, wildcard, area, success) 
            VALUES (?, ?, ?, ?, ?)
        """, networks_data)

        # Lưu thay đổi
        conn.commit()
        print("\n[+] XONG! Database đã được build hoàn chỉnh và sẵn sàng sử dụng.")
        
    except sqlite3.IntegrityError as e:
        print(f"[-] Lỗi khóa ngoại (Foreign Key) hoặc trùng lặp: {e}")
    except Exception as e:
        print(f"[-] Lỗi không xác định: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    create_and_seed_database()