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
    T_OSPF_RANGE = DB_TABLES["routing_ospf"]["area_ranges"]
    T_OSPF_DIST = DB_TABLES["routing_ospf"]["distance"]
    T_OSPF_TUNE = DB_TABLES["routing_ospf"]["tuning"]
    T_OSPF_REDIS = DB_TABLES["routing_ospf"]["redistribute"]
    T_OSPF_PASS = DB_TABLES["routing_ospf"]["passive_interfaces"]
    T_OSPF_INTF = DB_TABLES["routing_ospf"]["interface_settings"]
    
    T_STATIC_DEF = DB_TABLES["routing_static"]["default"]
    T_STATIC_RT = DB_TABLES["routing_static"]["routes"]

    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()

        # =============================================================
        #  PHẦN 1: THU THẬP DỮ LIỆU OSPF (THEO CẤU TRÚC 9 BẢNG MỚI)
        # =============================================================
        if target_module in ['ospf', 'all']:
            # [FIX 1] Đã thêm cột 'success' vào cuối câu lệnh SELECT để biết Thằng Cha đã cấu hình xong chưa
            query_ospf = f"SELECT ospf_id, host, process_id, router_id, reference_bandwidth, passive_default, default_originate, default_originate_always, success FROM {T_OSPF_PROC}"
            params_ospf = []
            if target_ip != "all":
                query_ospf += " WHERE host = ?"
                params_ospf.append(target_ip)

            cursor.execute(query_ospf, tuple(params_ospf))
            for proc in cursor.fetchall():
                # Hứng thêm biến proc_success
                ospf_id, host, proc_id, router_id, ref_bw, passive_def, def_orig, def_always, proc_success = proc

                # [FIX 2] KHUNG JSON THÔNG MINH: Nếu Cha đã success (proc_success == 1), ẩn các lệnh của Cha đi (gán None) để Jinja2 không render lại.
                config_data = {
                    "process_id": proc_id, 
                    "router_id": (router_id if router_id else "remove") if proc_success <= 0 else None,
                    "reference_bandwidth": (ref_bw if ref_bw else "remove") if proc_success <= 0 else None,
                    "passive_default": (True if passive_def == 1 else False) if proc_success <= 0 else None,
                    "default_originate": ({"always": True if def_always == 1 else False} if def_orig == 1 else False) if proc_success <= 0 else None,
                    "networks": [],
                    "areas": [],
                    "redistribute": [],
                    "passive_interfaces": [],
                    "interfaces": []
                }
                
                net_ids_add, net_ids_del = [], []
                area_ids_add, area_ids_del = [], []
                range_ids_add, range_ids_del = [], []
                dist_ids_add, dist_ids_del = [], []
                tune_ids_add, tune_ids_del = [], []
                redis_ids_add, redis_ids_del = [], []
                pass_ids_add, pass_ids_del = [], []
                intf_ids_add, intf_ids_del = [], []
                
                # 1. Bốc Network
                cursor.execute(f"SELECT id, network, wildcard, area, success FROM {T_OSPF_NET} WHERE ospf_id = ? AND (success = 0 OR success IS NULL OR success = -1)", (ospf_id,))
                for n_id, n_ip, n_wild, n_area, n_success in cursor.fetchall():
                    state = "remove" if n_success == -1 else "setup"
                    config_data["networks"].append({"network": n_ip, "wildcard": n_wild, "area": n_area, "state": state})
                    if n_success == -1: net_ids_del.append(n_id)
                    else: net_ids_add.append(n_id)

                # 2. Bốc Area (Đã tích hợp Logic lôi Cha nếu Con pending)
                cursor.execute(f"SELECT id, area_id, area_type, no_summary, authentication, success FROM {T_OSPF_AREA} WHERE ospf_id = ? AND (success <= 0 OR success IS NULL OR id IN (SELECT area_db_id FROM {T_OSPF_RANGE} WHERE success <= 0 OR success IS NULL))", (ospf_id,))
                for a_db_id, a_id, a_type, no_sum, auth, a_success in cursor.fetchall():
                    state = "remove" if a_success == -1 else "setup"
                    
                    area_item = {
                        "id": a_id, "type": a_type, "no_summary": bool(no_sum), 
                        "authentication": auth, "state": state
                    }
                    
                    # Quét Range của Area này
                    cursor.execute(f"SELECT id, ip, mask, advertise, cost, success FROM {T_OSPF_RANGE} WHERE area_db_id = ? AND (success = 0 OR success IS NULL OR success = -1)", (a_db_id,))
                    ranges = []
                    for r_id, r_ip, r_mask, r_adv, r_cost, r_success in cursor.fetchall():
                        r_state = "remove" if r_success == -1 else "setup"
                        ranges.append({"ip": r_ip, "mask": r_mask, "advertise": bool(r_adv), "cost": r_cost, "state": r_state})
                        if r_success == -1: range_ids_del.append(r_id)
                        else: range_ids_add.append(r_id)
                    
                    if ranges: area_item["range"] = ranges
                    config_data["areas"].append(area_item)
                    
                    if a_success == -1: area_ids_del.append(a_db_id)
                    elif a_success == 0: area_ids_add.append(a_db_id) # Chỉ update db area nếu nó thực sự pending

                # 3. Bốc Distance
                cursor.execute(f"SELECT id, external, intra_area, inter_area, success FROM {T_OSPF_DIST} WHERE ospf_id = ? AND (success = 0 OR success IS NULL OR success = -1)", (ospf_id,))
                for d_id, ext, intra, inter, d_success in cursor.fetchall():
                    state = "remove" if d_success == -1 else "setup"
                    config_data["distance"] = {"external": ext, "intra_area": intra, "inter_area": inter, "state": state}
                    if d_success == -1: dist_ids_del.append(d_id)
                    else: dist_ids_add.append(d_id)

                # 4. Bốc Tuning
                cursor.execute(f"SELECT id, maximum_paths, max_lsa, spf_delay, spf_min_delay, spf_max_delay, lsa_delay, lsa_min_delay, lsa_max_delay, success FROM {T_OSPF_TUNE} WHERE ospf_id = ? AND (success = 0 OR success IS NULL OR success = -1)", (ospf_id,))
                for t_id, max_p, max_l, spf_d, spf_min, spf_max, lsa_d, lsa_min, lsa_max, t_success in cursor.fetchall():
                    state = "remove" if t_success == -1 else "setup"
                    config_data["tuning"] = {
                        "maximum_paths": max_p, "max_lsa": max_l, 
                        "timers": {"spf": {"delay": spf_d, "min_delay": spf_min, "max_delay": spf_max}, "lsa": {"delay": lsa_d, "min_delay": lsa_min, "max_delay": lsa_max}}, 
                        "state": state
                    }
                    if t_success == -1: tune_ids_del.append(t_id)
                    else: tune_ids_add.append(t_id)

                # 5. Bốc Redistribute
                cursor.execute(f"SELECT id, protocol, process_id, subnets, metric, metric_type, route_map, success FROM {T_OSPF_REDIS} WHERE ospf_id = ? AND (success = 0 OR success IS NULL OR success = -1)", (ospf_id,))
                for r_id, proto, proto_id, subnets, metric, m_type, r_map, r_success in cursor.fetchall():
                    state = "remove" if r_success == -1 else "setup"
                    config_data["redistribute"].append({
                        "protocol": proto, "id": proto_id, "subnets": bool(subnets), 
                        "metric": metric, "metric_type": m_type, "route_map": r_map, "state": state
                    })
                    if r_success == -1: redis_ids_del.append(r_id)
                    else: redis_ids_add.append(r_id)

                # 6. Bốc Passive Interfaces
                cursor.execute(f"SELECT id, interface_name, passive, success FROM {T_OSPF_PASS} WHERE ospf_id = ? AND (success = 0 OR success IS NULL OR success = -1)", (ospf_id,))
                for p_id, intf_name, pass_val, p_success in cursor.fetchall():
                    state = "remove" if p_success == -1 else "setup"
                    config_data["passive_interfaces"].append({"name": intf_name, "passive": bool(pass_val), "state": state})
                    if p_success == -1: pass_ids_del.append(p_id)
                    else: pass_ids_add.append(p_id)

                # 7. Bốc Interface Settings
                cursor.execute(f"SELECT id, interface_name, area, cost, hello_interval, dead_interval, mtu_ignore, bfd, network_type, auth_type, success FROM {T_OSPF_INTF} WHERE ospf_id = ? AND (success = 0 OR success IS NULL OR success = -1)", (ospf_id,))
                for i_id, intf_name, area, cost, hello, dead, mtu, bfd, net_type, auth, i_success in cursor.fetchall():
                    state = "remove" if i_success == -1 else "setup"
                    config_data["interfaces"].append({
                        "name": intf_name, "area": area, "cost": cost, "hello_interval": hello, "dead_interval": dead, 
                        "mtu_ignore": mtu, "bfd": bfd, "network_type": net_type, "auth_type": auth, "state": state
                    })
                    if i_success == -1: intf_ids_del.append(i_id)
                    else: intf_ids_add.append(i_id)

                # [FIX 3] KIỂM TRA PENDING: Chỉ đẩy cấu hình nếu Thằng Cha hoặc bất kỳ Thằng Con nào đang pending
                is_pending = (
                    (proc_success <= 0) or 
                    net_ids_add or net_ids_del or 
                    area_ids_add or area_ids_del or 
                    range_ids_add or range_ids_del or 
                    dist_ids_add or dist_ids_del or 
                    tune_ids_add or tune_ids_del or 
                    redis_ids_add or redis_ids_del or 
                    pass_ids_add or pass_ids_del or 
                    intf_ids_add or intf_ids_del
                )

                if is_pending:
                    # Đóng gói Gửi cho Worker
                    valid_data.append({
                        "module": "routing", "sub_type": "ospf", 
                        "action": "remove" if proc_success == -1 else "setup", # Set cờ Remove nếu Cha là -1
                        "target": {"ip": host}, "ospf_id_db": ospf_id,
                        "net_ids_add": net_ids_add, "net_ids_del": net_ids_del,
                        "area_ids_add": area_ids_add, "area_ids_del": area_ids_del,
                        "range_ids_add": range_ids_add, "range_ids_del": range_ids_del,
                        "dist_ids_add": dist_ids_add, "dist_ids_del": dist_ids_del,
                        "tune_ids_add": tune_ids_add, "tune_ids_del": tune_ids_del,
                        "redis_ids_add": redis_ids_add, "redis_ids_del": redis_ids_del,
                        "pass_ids_add": pass_ids_add, "pass_ids_del": pass_ids_del,
                        "intf_ids_add": intf_ids_add, "intf_ids_del": intf_ids_del,
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
                                
                                # Nếu yêu cầu là xóa toàn bộ OSPF (-1) thì xóa dòng cha
                                if item["action"] == "remove":
                                    cursor.execute(f"DELETE FROM {T_OSPF_PROC} WHERE ospf_id = ?", (o_id,))
                                else:
                                    cursor.execute(f"UPDATE {T_OSPF_PROC} SET success = 1 WHERE ospf_id = ?", (o_id,))
                                
                                for n_id in item["net_ids_add"]: cursor.execute(f"UPDATE {T_OSPF_NET} SET success = 1 WHERE id = ?", (n_id,))
                                for n_id in item["net_ids_del"]: cursor.execute(f"DELETE FROM {T_OSPF_NET} WHERE id = ?", (n_id,))
                                
                                for a_id in item["area_ids_add"]: cursor.execute(f"UPDATE {T_OSPF_AREA} SET success = 1 WHERE id = ?", (a_id,))
                                for a_id in item["area_ids_del"]: cursor.execute(f"DELETE FROM {T_OSPF_AREA} WHERE id = ?", (a_id,))

                                for r_id in item["range_ids_add"]: cursor.execute(f"UPDATE {T_OSPF_RANGE} SET success = 1 WHERE id = ?", (r_id,))
                                for r_id in item["range_ids_del"]: cursor.execute(f"DELETE FROM {T_OSPF_RANGE} WHERE id = ?", (r_id,))

                                for d_id in item["dist_ids_add"]: cursor.execute(f"UPDATE {T_OSPF_DIST} SET success = 1 WHERE id = ?", (d_id,))
                                for d_id in item["dist_ids_del"]: cursor.execute(f"DELETE FROM {T_OSPF_DIST} WHERE id = ?", (d_id,))

                                for t_id in item["tune_ids_add"]: cursor.execute(f"UPDATE {T_OSPF_TUNE} SET success = 1 WHERE id = ?", (t_id,))
                                for t_id in item["tune_ids_del"]: cursor.execute(f"DELETE FROM {T_OSPF_TUNE} WHERE id = ?", (t_id,))

                                for re_id in item["redis_ids_add"]: cursor.execute(f"UPDATE {T_OSPF_REDIS} SET success = 1 WHERE id = ?", (re_id,))
                                for re_id in item["redis_ids_del"]: cursor.execute(f"DELETE FROM {T_OSPF_REDIS} WHERE id = ?", (re_id,))

                                for p_id in item["pass_ids_add"]: cursor.execute(f"UPDATE {T_OSPF_PASS} SET success = 1 WHERE id = ?", (p_id,))
                                for p_id in item["pass_ids_del"]: cursor.execute(f"DELETE FROM {T_OSPF_PASS} WHERE id = ?", (p_id,))

                                for i_id in item["intf_ids_add"]: cursor.execute(f"UPDATE {T_OSPF_INTF} SET success = 1 WHERE id = ?", (i_id,))
                                for i_id in item["intf_ids_del"]: cursor.execute(f"DELETE FROM {T_OSPF_INTF} WHERE id = ?", (i_id,))
                                
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