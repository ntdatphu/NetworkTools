from netmiko import ConnectHandler
from netmiko.exceptions import NetmikoTimeoutException, NetmikoAuthenticationException

def login_to_router(host, method, port, username=None, password=None, device_type='cisco_ios'):
    """
    Login helper for router access.
    The default device_type is 'cisco_ios'; adjust it for the device OS when needed.
    """
    
    # Prepare device information.
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

    print(f"--- Connecting to {host} ({method}) ---")

    try:
        # Initialize the connection.
        connection = ConnectHandler(**device_params)
        
        print(f"Successfully logged into {host}")
        
        # Chạy thử lệnh kiểm tra
        output = connection.send_command("show ip interface brief")
        print("Command result for 'show ip interface brief':")
        print(output)

        # Close the connection after completion.
        connection.disconnect()
        return True

    except NetmikoTimeoutException:
        print(f"Error: Could not connect to {host} (timeout).")
    except NetmikoAuthenticationException:
        print(f"Error: Invalid username/password for {host}.")
    except Exception as e:
        print(f"Unexpected connection error for {host}: {e}")
    
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
