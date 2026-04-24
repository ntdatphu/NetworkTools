import json
import os
import sys
import sqlite3
import argparse
from collections import defaultdict

# =====================================================================
# 1. BẬT RADAR TÌM GỐC DỰ ÁN
# =====================================================================
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(CURRENT_DIR, "../../.."))

if PROJECT_ROOT not in sys.path:
    sys.path.append(PROJECT_ROOT)
if CURRENT_DIR not in sys.path:
    sys.path.append(CURRENT_DIR)

from PyCode.share.config import DB_PATH, ROUTE_OUTPUT, TMP_DIR

try:
    from worker_routing import run_routing_config
except ImportError as e:
    print(f"[-] Lỗi Import: Không tìm thấy file 'worker_routing.py'!\n    Chi tiết: {e}")
    sys.exit(1)

# =====================================================================
# SIÊU ĐIỀU PHỐI ROUTING (NHẬN LỆNH TỪ FRONTEND)
# =====================================================================
def main():
    # Khởi tạo bộ đọc tham số (nhận tín hiệu từ UI)
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

    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()

        # -------------------------------------------------------------
        # 🟢 PHẦN 1: THU THẬP DỮ LIỆU OSPF
        # -------------------------------------------------------------
        if target_module in ['ospf', 'all']:
            query_ospf = "SELECT ospf_id, host, process_id, router_id, ad, action FROM ospf_processes"
            params_ospf = []
            if target_ip != "all":
                query_ospf += " WHERE host = ?"
                params_ospf.append(target_ip)

            cursor.execute(query_ospf, tuple(params_ospf))
            for proc in cursor.fetchall():
                ospf_id, host, proc_id, router_id, ad, db_action = proc

                cursor.execute("SELECT id, network, wildcard, area, success FROM ospf_networks WHERE ospf_id = ? AND (success = 0 OR success IS NULL OR success = -1)", (ospf_id,))
                pending_networks = cursor.fetchall()

                action_code = str(db_action).strip().zfill(3) if db_action else "000"
                if action_code == "000" and len(pending_networks) == 0:
                    continue

                net_list, net_ids_add, net_ids_del = [], [], []
                for net_id, net_ip, net_wild, net_area, net_success in pending_networks:
                    if net_success == -1:
                        net_list.append({"network": net_ip, "wildcard": net_wild, "area": net_area, "state": "remove"})
                        net_ids_del.append(net_id)
                    else:
                        net_list.append({"network": net_ip, "wildcard": net_wild, "area": net_area})
                        net_ids_add.append(net_id)

                config_data = {"process_id": proc_id, "networks": net_list}
                if action_code[0] == '1' and router_id: config_data["router_id"] = router_id
                if action_code[1] == '1': config_data["default_originate"] = True
                elif action_code[1] == '0': config_data["default_originate"] = "remove"

                if ad:
                    ad_str = str(ad).strip()
                    if "-" in ad_str:
                        ad_parts = ad_str.split("-")
                        config_data["distance"] = {"intra_area": int(ad_parts[0]) if len(ad_parts)>0 else 110, "inter_area": int(ad_parts[1]) if len(ad_parts)>1 else 110, "external": int(ad_parts[2]) if len(ad_parts)>2 else 110}
                    else:
                        try: config_data["distance"] = {"intra_area": int(ad_str), "inter_area": int(ad_str), "external": int(ad_str)}
                        except ValueError: pass

                valid_data.append({
                    "module": "routing", "sub_type": "ospf", "action": "setup",
                    "target": {"ip": host}, "ospf_id_db": ospf_id,
                    "net_ids_add": net_ids_add, "net_ids_del": net_ids_del,
                    "config": [config_data]
                })

        # -------------------------------------------------------------
        # 🔵 PHẦN 2: THU THẬP DỮ LIỆU STATIC & DEFAULT ROUTE
        # -------------------------------------------------------------
        if target_module in ['static', 'all']:
            hosts_data = defaultdict(lambda: {"def_routes": [], "stat_routes": [], "ids_add": {"def": [], "stat": []}, "ids_del": {"def": [], "stat": []}})

            query_def = "SELECT id, host, next_hop_ip, success FROM static_default_routes WHERE (success = 0 OR success IS NULL OR success = -1)"
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

            query_stat = "SELECT id, host, network, subnet_mask, next_hop, ad, success FROM static_routes WHERE (success = 0 OR success IS NULL OR success = -1)"
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

    # -------------------------------------------------------------
    # 🟡 PHẦN 3 & 4: ĐẨY LỆNH, UPDATE DB VÀ XUẤT LOG CHO FRONTEND
    # -------------------------------------------------------------
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

                # Lấy log từ cả "message" hoặc "msg" tùy theo Worker
                report_item = {"ip": ip, "status": "SUCCESS" if status == "success" else "FAIL", "log": res.get("message", res.get("msg", "")), "db_updated": False}

                if status == "success":
                    for item in valid_data:
                        if item["target"]["ip"] == ip:
                            if item["sub_type"] == "ospf":
                                o_id = item["ospf_id_db"]
                                cursor.execute("UPDATE ospf_processes SET action = '000', success = 1 WHERE ospf_id = ?", (o_id,))
                                for n_id in item["net_ids_add"]: cursor.execute("UPDATE ospf_networks SET success = 1 WHERE id = ?", (n_id,))
                                for n_id in item["net_ids_del"]: cursor.execute("DELETE FROM ospf_networks WHERE id = ?", (n_id,))
                            elif item["sub_type"] == "static":
                                track = item["tracking_ids"]
                                for d_id in track["ids_add"]["def"]: cursor.execute("UPDATE static_default_routes SET success = 1 WHERE id = ?", (d_id,))
                                for s_id in track["ids_add"]["stat"]: cursor.execute("UPDATE static_routes SET success = 1 WHERE id = ?", (s_id,))
                                for d_id in track["ids_del"]["def"]: cursor.execute("DELETE FROM static_default_routes WHERE id = ?", (d_id,))
                                for s_id in track["ids_del"]["stat"]: cursor.execute("DELETE FROM static_routes WHERE id = ?", (s_id,))

                    success_count += 1
                    report_item["db_updated"] = True

                ui_report.append(report_item)

            conn.commit()
            conn.close()
            print(f"\n[*] Đã đồng bộ Database thành công cho {success_count} thiết bị.")

            # Xuất log động theo chuẩn để UI bên ngoài đọc vào
            log_filename = f"routing_log_{target_module}_{target_ip.replace('.', '_')}.json" if target_ip != "all" else "master_routing_log.json"
            log_file_path = os.path.join(TMP_DIR, log_filename)
            os.makedirs(TMP_DIR, exist_ok=True)
            with open(log_file_path, 'w', encoding='utf-8') as log_file:
                json.dump(ui_report, log_file, ensure_ascii=False, indent=4)

            print(f"[*] Đã xuất file Log tại: {log_file_path}")

        except Exception as e:
            print(f"[-] Lỗi khi dọn dẹp Database hoặc xuất file Log: {e}")

if __name__ == "__main__":
    main()