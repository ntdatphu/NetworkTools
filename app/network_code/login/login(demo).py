from netmiko import ConnectHandler
from netmiko.exceptions import NetmikoTimeoutException, NetmikoAuthenticationException

def login_to_router(host, method, port, username=None, password=None, device_type='cisco_ios'):
    """
    Hàm thực hiện login vào router.
    device_type mặc định là 'cisco_ios', bạn có thể thay đổi tùy theo OS của thiết bị.
    """
    
    # Chuẩn bị thông tin thiết bị
    device_params = {
        'device_type': device_type,
        'host': host,
        'port': port,
        'username': username if username else '', # Xử lý nếu username trống
        'password': password if password else '', # Xử lý nếu password trống
    }

    # Nếu method là telnet, netmiko cần biết để điều chỉnh giao thức
    if method.lower() == 'telnet':
        device_params['device_type'] = f"{device_type}_telnet"

    print(f"--- Đang kết nối tới {host} ({method}) ---")

    try:
        # Khởi tạo kết nối
        connection = ConnectHandler(**device_params)
        
        print(f"Successfully logged into {host}")
        
        # Chạy thử lệnh kiểm tra
        output = connection.send_command("show ip interface brief")
        print("Kết quả lệnh 'show ip interface brief':")
        print(output)

        # Đóng kết nối sau khi hoàn tất
        connection.disconnect()
        return True

    except NetmikoTimeoutException:
        print(f"Lỗi: Không thể kết nối tới {host} (Timeout).")
    except NetmikoAuthenticationException:
        print(f"Lỗi: Sai Username/Password cho {host}.")
    except Exception as e:
        print(f"Lỗi không xác định khi kết nối tới {host}: {e}")
    
    return False

# --- VÍ DỤ SỬ DỤNG ---
if __name__ == "__main__":
    # Giả sử đây là dữ liệu lấy từ bảng 'devices' của bạn
    test_host = "192.168.1.1"
    test_method = "ssh" # hoặc 'telnet'
    test_port = 22
    test_user = "admin"  # Có thể để None
    test_pass = "cisco123" # Có thể để None

    login_to_router(test_host, test_method, test_port, test_user, test_pass)