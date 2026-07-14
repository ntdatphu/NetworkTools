import json
import os
from worker_switch import SwitchWorker

def get_device_from_json(json_path, ip_address):
    """Móc thông tin đăng nhập từ file thiết bị (Mock DB)"""
    try:
        with open(json_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
            for row in data.get("devices", []):
                if row.get("host") == ip_address:
                    return {
                        'host': row.get("host"),
                        'username': row.get("username"),
                        'password': row.get("password"),
                        'secret': row.get("password"), 
                        'os': row.get("os", "ios")
                    }
        return None
    except Exception as e:
        print(f"[-] Lỗi đọc Database JSON: {e}")
        return None

def main():
    print("="*60)
    print("🚀 HỆ THỐNG QUẢN LÝ TẬP TRUNG (THUẦN JSON 100%) 🚀")
    print("="*60)

    # --- 1. ĐỊNH TUYẾN ĐƯỜNG DẪN ---
    base_dir = os.path.dirname(os.path.abspath(__file__))
    
    # File JSON nằm trong thư mục share
    db_json_path = os.path.join(base_dir, 'share', 'devices_mock.json')
    config_json_path = os.path.join(base_dir, 'share', 'config_input.json')
    
    # THƯ MỤC TEMPLATE (Sửa lại cho đúng với cây thư mục của sếp)
    template_folder = os.path.join(base_dir, 'templates_switch')

    if not os.path.exists(db_json_path):
        print(f"[-] Lỗi: Không tìm thấy DB giả lập tại {db_json_path}")
        return
    if not os.path.exists(config_json_path):
        print(f"[-] Lỗi: Không tìm thấy kịch bản tại {config_json_path}")
        return

    # --- 2. ĐỌC KỊCH BẢN TỪ JSON ---
    try:
        with open(config_json_path, 'r', encoding='utf-8') as f:
            config_data = json.load(f)
            target_ip = config_data.get('target_ip')
            action = config_data.get('action', 'configure').lower()
    except Exception as e:
        print(f"[-] Lỗi đọc file kịch bản JSON: {e}")
        return

    if not target_ip:
        print("[-] Lỗi: File kịch bản JSON thiếu trường 'target_ip'")
        return

    # --- 3. GHÉP NỐI VỚI DỮ LIỆU ĐĂNG NHẬP ---
    print(f"[*] Đang tra cứu thông tin thiết bị {target_ip} trong Mock DB...")
    device_info = get_device_from_json(db_json_path, target_ip)
    
    if not device_info:
        print(f"[-] Bó tay! Thiết bị {target_ip} chưa được khai báo.")
        return

    # --- 4. GIAO VIỆC CHO WORKER ---
    print(f"[*] Dữ liệu hợp lệ. Bàn giao cho SwitchWorker thi công...")
    
    # Trỏ thẳng vào thư mục templates_switch
    worker = SwitchWorker(template_dir=template_folder) 
    worker.execute(device_info=device_info, config_data=config_data, action=action)

if __name__ == "__main__":
    main()