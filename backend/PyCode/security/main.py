import os
import sys
import argparse
import sqlite3

CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(CURRENT_DIR, "../.."))

if PROJECT_ROOT not in sys.path: sys.path.append(PROJECT_ROOT)
if CURRENT_DIR not in sys.path: sys.path.append(CURRENT_DIR)

from PyCode.share.config import DB_PATH

def main():
    parser = argparse.ArgumentParser(description="Security Automation Gateway")
    parser.add_argument("-t", "--target", type=str, default="all", help="IP của Router")
    parser.add_argument("-m", "--module", type=str, choices=['acl', 'dhcp', 'all'], default="all", help="Tính năng")
    # THÊM THAM SỐ NHẬN ID TỪ GIAO DIỆN:
    parser.add_argument("-id", "--acl_id", type=int, help="ID của ACL cần cấu hình (Ưu tiên cao nhất)")
    args = parser.parse_args()

    if not os.path.exists(DB_PATH):
        print(f"[-] LỖI: Không tìm thấy Database tại: {DB_PATH}")
        return

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    try:
        if args.module in ['acl', 'all']:
            # ĐÃ ĐỔI TÊN IMPORT SANG WORKER MỚI
            from PyCode.security.ACL.woker_acl import run_acl_worker
            
            # KỊCH BẢN 1: UI TRUYỀN XUỐNG ĐÚNG 1 CÁI ID
            if args.acl_id:
                cursor.execute("SELECT host FROM ACL_DB WHERE Acl_id = ?", (args.acl_id,))
                row = cursor.fetchone()
                if row:
                    target_host = row[0]
                    print(f"\n[*] [Security Gateway] Đã tra cứu ACL_ID {args.acl_id} -> Thuộc về Host: {target_host}")
                    # Truyền dưới dạng list [args.acl_id] vì worker xài mảng
                    run_acl_worker(target_host, [args.acl_id], DB_PATH)
                else:
                    print(f"\n[-] LỖI: Không tìm thấy ACL_ID {args.acl_id} trong Database!")
            
            # KỊCH BẢN 2: UI KHÔNG TRUYỀN ID (Đồng bộ hàng loạt theo IP)
            else:
                print(f"\n[*] [Security Gateway] Quét hàng loạt ACL cho Target: {args.target}")
                query = "SELECT Acl_id FROM ACL_DB WHERE success IN (0, -1)"
                params = []
                if args.target != "all":
                    query += " AND host = ?"
                    params.append(args.target)
                    
                cursor.execute(query, tuple(params))
                acl_list = [row[0] for row in cursor.fetchall()]
                
                if acl_list:
                    run_acl_worker(args.target, acl_list, DB_PATH)
                else:
                    print(f"\n[INFO] Không có tác vụ ACL nào đang chờ cho {args.target}.")

    except Exception as e:
        print(f"[-] Lỗi Gateway: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    main()