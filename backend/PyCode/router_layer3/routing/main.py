import json
import os
import sys
import sqlite3
import argparse
from collections import defaultdict

# Setup radar đường dẫn
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(CURRENT_DIR, "../../.."))
if PROJECT_ROOT not in sys.path: sys.path.append(PROJECT_ROOT)
if CURRENT_DIR not in sys.path: sys.path.append(CURRENT_DIR)

# [ĐỒNG BỘ 100%] Gọi tất cả vũ khí từ Trạm kiểm soát
from PyCode.share.config import DB_PATH, ROUTE_OUTPUT, TMP_DIR, DB_TABLES

try:
    from worker_routing import run_routing_config
except ImportError as e:
    print(f"[-] Lỗi Import Worker: Không tìm thấy file 'worker_routing.py'!\n    Chi tiết: {e}")
    sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description="Routing Automation Controller")
    parser.add_argument("-t", "--target", type=str, default="all", help="IP của Router (Mặc định: all)")
    parser.add_argument("-m", "--module", type=str, choices=['ospf', 'static', 'all'], default="all", help="Giao thức (ospf, static, all)")
    args = parser.parse_args()

    target_ip = args.target
    target_module = args.module

    print(f"\n[*] [Routing Master] Target: {target_ip} | Module: {target_module.upper()} | DB: {os.path.basename(DB_PATH)}")

    if not os.path.exists(DB_PATH):
        print(f"[-] LỖI: Không tìm thấy file Database tại: {DB_PATH}")
        return

    valid_data = []

    # -------------------------------------------------------------
    # ÉP KIỂU TÊN BẢNG TỪ FILE CONFIG.PY
    # -------------------------------------------------------------
    T_OSPF_PROC = DB_TABLES["routing_ospf"]["processes"]
    T_OSPF_NET = DB_TABLES["routing_ospf"]["networks"]
    T_OSPF_AREA = DB_TABLES["routing_ospf"]["areas"]
    
    T_STATIC_DEF = DB_TABLES["routing_static"]["default"]
    T_STATIC_RT = DB_TABLES["routing_static"]["routes"]

    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()

        # =============================================================
        #  PHẦN 1: THU THẬP DỮ LIỆU OSPF (THEO CẤU TRÚC 9 BẢNG MỚI)
        # =============================================================
        if target_module in ['ospf', 'all']:
            # Dùng f-string để gắn tên bảng động
            query_ospf = f"SELECT ospf_id, host, process_id, router_id, passive_default, default_originate FROM {T_OSPF_PROC}"
            params_ospf = []
            if target_ip != "all":
                query_ospf += " WHERE host = ?"
                params_ospf.append(target_ip)

            cursor.execute(query_ospf, tuple(params_ospf))
            for proc in cursor.fetchall():
                ospf_id, host, proc_id, router_id, passive_def, def_orig = proc

                # Khởi tạo khung JSON Payload
                config_data = {
                    "process_id": proc_id, 
                    "router_id": router_id if router_id else "remove",
                    "passive_default": True if passive_def == 1 else False,
                    "default_originate": True if def_orig == 1 else False,
                    "networks": [],
                    "areas": []
                }
                
                net_ids_add, net_ids_del = [], []
                
                # 1. Bốc Network
                cursor.execute(f"SELECT id, network, wildcard, area, success FROM {T_OSPF_NET} WHERE ospf_id = ? AND (success = 0 OR success IS NULL OR success = -1)", (ospf_id,))
                for n_id, n_ip, n_wild, n_area, n_success in cursor.fetchall():
                    state = "remove" if n_success == -1 else "setup"
                    config_data["networks"].append({"network": n_ip, "wildcard": n_wild, "area": n_area, "state": state})
                    if n_success == -1: net_ids_del.append(n_id)
                    else: net_ids_add.append(n_id)

                # 2. Bốc Area
                cursor.execute(f"SELECT area_id, area_type, no_summary, authentication, success FROM {T_OSPF_AREA} WHERE ospf_id = ? AND (success = 0 OR success IS NULL OR success = -1)", (ospf_id,))
                for a_id, a_type, no_sum, auth, a_success in cursor.fetchall():
                    state = "remove" if a_success == -1 else "setup"
                    config_data["areas"].append({
                        "id": a_id, "type": a_type, "no_summary": bool(no_sum), 
                        "authentication": auth, "state": state
                    })

                # Đóng gói Gửi cho Worker
                valid_data.append({
                    "module": "routing", "sub_type": "ospf", "action": "setup",
                    "target": {"ip": host}, "ospf_id_db": ospf_id,
                    "net_ids_add": net_ids_add, "net_ids_del": net_ids_del,
                    "config": [config_data]
                })

        # =============================================================
        #  PHẦN 2: THU THẬP DỮ LIỆU STATIC & DEFAULT ROUTE
        # =============================================================
        if target_module in ['static', 'all']:
            hosts_data = defaultdict(lambda: {"def_routes": [], "stat_routes": [], "ids_add": {"def": [], "stat": []}, "ids_del": {"def": [], "stat": []}})

            # Lấy Default Route
            query_def = f"SELECT id, host, next_hop_ip, success FROM {T_STATIC_DEF} WHERE (success = 0 OR success IS NULL OR success = -1)"
            params_def = []
            if target_ip != "all":
                query_def += " AND host = ?"
                params_def.append(target_ip)

            cursor.execute(query_def, tuple(params_def))
            for r_id, host, next_hop, success in cursor.fetchall():
                state = "remove" if success == -1 else "setup"
                hosts_data[host]["def_routes"].append({"next_hop": next_hop, "state": state})
                if success == -1: hosts_data[host]["ids_del"]["def"].append(r_id)
                else: hosts_data[host]["ids_add"]["def"].append(r_id)

            # Lấy Static Route
            query_stat = f"SELECT id, host, network, subnet_mask, next_hop, ad, success FROM {T_STATIC_RT} WHERE (success = 0 OR success IS NULL OR success = -1)"
            params_stat = []
            if target_ip != "all":
                query_stat += " AND host = ?"
                params_stat.append(target_ip)

            cursor.execute(query_stat, tuple(params_stat))
            for r_id, host, net, mask, next_hop, ad, success in cursor.fetchall():
                state = "remove" if success == -1 else "setup"
                route_item = {"network": net, "subnet_mask": mask, "next_hop": next_hop, "state": state}
                if ad: route_item["ad"] = ad
                hosts_data[host]["stat_routes"].append(route_item)
                if success == -1: hosts_data[host]["ids_del"]["stat"].append(r_id)
                else: hosts_data[host]["ids_add"]["stat"].append(r_id)

            for host, data in hosts_data.items():
                config_data = {}
                if data["def_routes"]: config_data["default_routes"] = data["def_routes"]
                if data["stat_routes"]: config_data["static_routes"] = data["stat_routes"]

                if config_data:
                    valid_data.append({
                        "module": "routing", "sub_type": "static", "action": "setup",
                        "target": {"ip": host},
                        "tracking_ids": {"ids_add": data["ids_add"], "ids_del": data["ids_del"]},
                        "config": [config_data]
                    })

    except Exception as e:
        print(f"[-] Lỗi truy xuất Database: {e}")
        return
    finally:
        if 'conn' in locals(): conn.close()

    # =============================================================
    #  PHẦN 3: ĐẨY LỆNH XUỐNG WORKER & UPDATE DB THÀNH CÔNG
    # =============================================================
    if not valid_data:
        print(f"\n[INFO] Không có dữ liệu {target_module.upper()} nào cần cập nhật cho {target_ip}.")
        return

    print(f"\n[INFO] Đang đẩy {len(valid_data)} gói cấu hình từ DB sang Worker...")
    run_routing_config(valid_data, DB_PATH, ROUTE_OUTPUT)

    if os.path.exists(ROUTE_OUTPUT):
        try:
            with open(ROUTE_OUTPUT, 'r', encoding='utf-8') as f:
                out_results = json.load(f)

            conn = sqlite3.connect(DB_PATH)
            cursor = conn.cursor()

            ui_report = []
            success_count = 0

            for res in out_results:
                ip = res.get("target")
                status = res.get("status")
                report_item = {"ip": ip, "status": "SUCCESS" if status == "success" else "FAIL", "log": res.get("message", res.get("msg", "")), "db_updated": False}

                if status == "success":
                    for item in valid_data:
                        if item["target"]["ip"] == ip:
                            # Update DB bằng tên bảng động
                            if item["sub_type"] == "ospf":
                                o_id = item["ospf_id_db"]
                                cursor.execute(f"UPDATE {T_OSPF_PROC} SET success = 1 WHERE ospf_id = ?", (o_id,))
                                for n_id in item["net_ids_add"]: cursor.execute(f"UPDATE {T_OSPF_NET} SET success = 1 WHERE id = ?", (n_id,))
                                for n_id in item["net_ids_del"]: cursor.execute(f"DELETE FROM {T_OSPF_NET} WHERE id = ?", (n_id,))
                            elif item["sub_type"] == "static":
                                track = item["tracking_ids"]
                                for d_id in track["ids_add"]["def"]: cursor.execute(f"UPDATE {T_STATIC_DEF} SET success = 1 WHERE id = ?", (d_id,))
                                for s_id in track["ids_add"]["stat"]: cursor.execute(f"UPDATE {T_STATIC_RT} SET success = 1 WHERE id = ?", (s_id,))
                                for d_id in track["ids_del"]["def"]: cursor.execute(f"DELETE FROM {T_STATIC_DEF} WHERE id = ?", (d_id,))
                                for s_id in track["ids_del"]["stat"]: cursor.execute(f"DELETE FROM {T_STATIC_RT} WHERE id = ?", (s_id,))

                    success_count += 1
                    report_item["db_updated"] = True

                ui_report.append(report_item)

            conn.commit()
            conn.close()
            print(f"\n[*] Đã đồng bộ Database thành công cho {success_count} thiết bị.")

            # Xuất log cho UI Frontend
            log_filename = f"routing_log_{target_module}_{target_ip.replace('.', '_')}.json" if target_ip != "all" else "master_routing_log.json"
            log_file_path = os.path.join(TMP_DIR, log_filename)
            with open(log_file_path, 'w', encoding='utf-8') as log_file:
                json.dump(ui_report, log_file, ensure_ascii=False, indent=4)
            print(f"[*] Đã xuất file Log tại: {log_file_path}")

        except Exception as e:
            print(f"[-] Lỗi khi Update Database hoặc xuất file Log: {e}")

if __name__ == "__main__":
    main()