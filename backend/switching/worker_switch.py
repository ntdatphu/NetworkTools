import yaml
from napalm import get_network_driver
from jinja2 import Environment, FileSystemLoader

# Import module báo cáo
from PyCode.report.report_manager import write_report

def main():
    print("\n [WORKER SWITCH] -> Khởi động...")
    target_ip = "Unknown"
    
    # --- BƯỚC 1: ĐỌC DỮ LIỆU ---
    try:
        with open('file_input_config.yaml', 'r', encoding='utf-8') as f:
            data = yaml.safe_load(f)
            target_ip = data.get('target_ip', 'Unknown')
            action = data.get('action', 'configure').lower()
    except Exception as e:
        print(f" Lỗi đọc file YAML: {e}")
        write_report("error", "Unknown", "switch", "Lỗi đọc file cấu hình YAML", e)
        return

    # --- BƯỚC 2: CHỌN TEMPLATE ---
    template_name = 'template_switch.j2'
    if action == 'delete':
        template_name = 'template_switch_delete.j2'
        print(f"  CẢNH BÁO: Đang thực hiện chế độ XÓA (DELETE) trên Switch {target_ip}")

    # --- BƯỚC 3: RENDER TEMPLATE ---
    print(f"   -> Đang render template: {template_name}")
    env = Environment(loader=FileSystemLoader('.'))
    try:
        template = env.get_template(template_name)
        config_commands = template.render(data)
    except Exception as e:
        print(f" Lỗi Template Jinja2: {e}")
        write_report("error", target_ip, "switch", f"Lỗi xử lý Template {template_name}", e)
        return
    
    # --- BƯỚC 4: KẾT NỐI & THỰC THI ---
    driver = get_network_driver('ios')
    device = driver(
        data['target_ip'], 
        data['username'], 
        data['password'],
        # [FIX 1] Tăng thời gian chờ lên gấp 4 lần
        optional_args={
            'secret': data['password'], 
            'global_delay_factor': 4,
            'fast_cli': False # Gõ chậm lại cho chắc
        }
    )

    try:
        print(f"   -> Đang kết nối tới Switch {target_ip}...")
        device.open()
        
        # --- BỘ LỌC LỆNH ---
        print("   -> Đang xử lý lệnh...")
        raw_commands = config_commands.split('\n')
        clean_commands = [cmd.strip() for cmd in raw_commands if cmd.strip() and not cmd.strip().startswith('!')]
        
        # [FIX 2] Tắt log console để tránh bị spam tin nhắn gây lỗi Pattern not detected
        final_commands = ['no logging console'] + clean_commands

        # [FIX 3] Tăng read_timeout lên 60 giây
        print(f"   -> Đang gửi {len(final_commands)} lệnh (Timeout=60s)...")
        output = device.device.send_config_set(final_commands, read_timeout=60)
        
        print(output)
        
        # Bật lại log sau khi xong việc
        device.device.send_config_set(['logging console'])

        print("   -> Đang lưu cấu hình (write mem)...")
        device.device.save_config()
        print(f"\n [SWITCH] Thực thi lệnh '{action.upper()}' thành công!")
        
        # GHI BÁO CÁO THÀNH CÔNG
        msg = "Cấu hình thành công!" if action == 'configure' else "Đã xóa cấu hình thành công!"
        write_report("success", target_ip, "switch", msg, output)
        
    except Exception as e:
        print(f" Lỗi thực thi Switch: {e}")
        write_report("error", target_ip, "switch", "Lỗi kết nối hoặc đẩy lệnh", e)
        
    finally:
        if 'device' in locals():
            device.close()

if __name__ == "__main__":
    main()