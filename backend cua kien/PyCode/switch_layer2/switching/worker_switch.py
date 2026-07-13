import os
from napalm import get_network_driver
from jinja2 import Environment, FileSystemLoader

# Import module báo cáo của sếp
try:
    from report.report_manager import write_report
except ImportError:
    def write_report(*args): pass 

class SwitchWorker:
    def __init__(self, template_dir='.'):
        self.env = Environment(loader=FileSystemLoader(template_dir))

    def execute(self, device_info, config_data, action='configure'):
        target_ip = device_info.get('host')
        print(f"\n [WORKER SWITCH] -> Bắt đầu xử lý cho {target_ip} (Chế độ: {action.upper()})...")
        
        # --- BƯỚC 1: RENDER TEMPLATE ---
        template_name = 'template_switch.j2'
        try:
            config_data['action'] = action 
            template = self.env.get_template(template_name)
            config_commands = template.render(config_data)
        except Exception as e:
            print(f" [-] Lỗi Template Jinja2: {e}")
            write_report("error", target_ip, "switch", f"Lỗi xử lý Template {template_name}", str(e))
            return False

        # --- BƯỚC 2: KẾT NỐI NAPALM ---
        driver = get_network_driver(device_info.get('os', 'ios'))
        device = driver(
            hostname=target_ip,
            username=device_info.get('username'),
            password=device_info.get('password'),
            optional_args={
                'secret': device_info.get('secret'),
                'global_delay_factor': 4,
                'fast_cli': False
            }
        )

        try:
            print(f"   -> Đang kết nối tới Switch {target_ip}...")
            device.open()
            
            raw_commands = config_commands.split('\n')
            clean_commands = [cmd.strip() for cmd in raw_commands if cmd.strip() and not cmd.strip().startswith('!')]
            
            final_commands = ['no logging console'] + clean_commands

            print(f"   -> Đang gửi {len(final_commands)} lệnh (Timeout=60s)...")
            output = device.device.send_config_set(final_commands, read_timeout=60)
            
            print(output)
            
            # Bật lại log
            device.device.send_config_set(['logging console'])
            
            # [TUYỆT ĐỐI KHÔNG LƯU]
            print("   -> (SAFE MODE) Đã đẩy lệnh xong. KHÔNG lưu cấu hình (write mem) theo lệnh sếp!")
            
            print(f"\n [+] [SWITCH] Thực thi lệnh '{action.upper()}' thành công!")
            
            msg = "Cấu hình thành công!" if action == 'configure' else "Đã xóa cấu hình thành công!"
            write_report("success", target_ip, "switch", msg, output)
            return True
            
        except Exception as e:
            print(f" [-] Lỗi thực thi Switch: {e}")
            write_report("error", target_ip, "switch", "Lỗi kết nối hoặc đẩy lệnh", str(e))
            return False
            
        finally:
            if 'device' in locals() and hasattr(device, 'close'):
                device.close()