"""
Device connector module for SSH/Telnet CLI access using Netmiko
"""
import json
from netmiko import ConnectHandler
from netmiko.exceptions import NetmikoTimeoutException, NetmikoAuthenticationException, ConnectionException
import os
import shlex
import sys


NETWORK_CODE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATABASE_PATHS_JSON = os.path.join(NETWORK_CODE_DIR, "database_paths.json")


def load_default_db_path():
    """Load the app-created database path for network_code helpers."""
    try:
        with open(DATABASE_PATHS_JSON, "r", encoding="utf-8") as f:
            data = json.load(f)
        db_path = data.get("device_network_db")
        if db_path:
            return os.path.abspath(os.path.expanduser(db_path))
    except Exception:
        pass
    return None

class DeviceConnector:
    """Manages connection and interactive CLI to network devices"""
    
    def __init__(self, host, method, port, username, password, device_type='cisco_ios', start_config_mode=False, db_path=None):
        """Initialize device connector parameters"""
        self.host = host
        self.method = method.lower()
        self.port = int(port)
        self.username = username if username else ''
        self.password = password if password else ''
        self.device_type = device_type
        self.start_config_mode = start_config_mode
        self.db_path = db_path or load_default_db_path()
        self.connection = None
        self.connected = False
        self.last_error = ""
    
    def connect(self):
        """Establish connection to the device"""
        self.last_error = ""
        try:
            # Prepare device parameters
            device_params = {
                'device_type': self.device_type,
                'host': self.host,
                'port': self.port,
                'username': self.username,
                'password': self.password,
                'secret': self.password,
            }
            
            # Adjust device type for telnet
            if self.method == 'telnet':
                device_params['device_type'] = f"{self.device_type}_telnet"
            
            print(f"\n[INFO] Connecting to {self.host} ({self.method.upper()})...")
            self.connection = ConnectHandler(**device_params)
            self.connected = True
            print(f"[SUCCESS] Successfully connected to {self.host}\n")
            if self.start_config_mode:
                self.enter_config_mode()
            return True
            
        except NetmikoTimeoutException:
            self.last_error = "connection timeout"
            print(f"\n[ERROR] Connection timeout to {self.host}\n")
            return False
        except NetmikoAuthenticationException:
            self.last_error = "authentication failed (invalid credentials)"
            print(f"\n[ERROR] Authentication failed for {self.host} (invalid credentials)\n")
            return False
        except ConnectionException as e:
            self.last_error = f"connection error: {e}"
            print(f"\n[ERROR] Connection error: {e}\n")
            return False
        except Exception as e:
            self.last_error = f"unexpected error: {e}"
            print(f"\n[ERROR] Unexpected error: {e}\n")
            return False

    def enter_config_mode(self):
        """Enter global configuration mode on the connected device."""
        if not self.connected or not self.connection:
            print("[ERROR] Not connected to device\n")
            return False

        try:
            if hasattr(self.connection, "check_enable_mode") and not self.connection.check_enable_mode():
                self.connection.enable()

            if not self.connection.check_config_mode():
                self.connection.config_mode()

            if not self.connection.check_config_mode():
                print("[ERROR] Could not enter configuration mode: prompt is not in config mode\n")
                return False

            print("[SUCCESS] Entered configuration terminal mode\n")
            return True
        except Exception as e:
            print(f"[ERROR] Could not enter configuration mode: {e}\n")
            return False
    
    def disconnect(self):
        """Close connection to device"""
        if self.connection:
            try:
                self.connection.disconnect()
                self.connected = False
                print(f"\n[SUCCESS] Disconnected from {self.host}\n")
            except Exception as e:
                print(f"[ERROR] Error disconnecting: {e}\n")
    
    def send_command(self, command):
        """Send command and return output"""
        if not self.connected or not self.connection:
            print("[ERROR] Not connected to device\n")
            return None
        
        try:
            output = self.connection.send_command(command)
            return output
        except Exception as e:
            print(f"[ERROR] Error executing command: {e}\n")
            return None

    def save_running_config(self, file_path):
        """Run 'do show running-config' and save the output to a text file."""
        if not file_path:
            print("[ERROR] Missing file path. Usage: output rcfg <file_path>\n")
            return False

        try:
            in_config_mode = bool(self.connection and self.connection.check_config_mode())
        except Exception:
            in_config_mode = False

        command = "do show running-config" if in_config_mode else "show running-config"
        output = self.send_command(command)
        if output is None:
            return False

        try:
            file_path = os.path.expanduser(file_path.strip().strip('"'))
            if os.path.isdir(file_path) or file_path.endswith(("\\", "/")):
                safe_host = self.host.replace(":", "_").replace("/", "_").replace("\\", "_")
                file_path = os.path.join(file_path, f"{safe_host}_running-config.txt")

            parent_dir = os.path.dirname(os.path.abspath(file_path))
            if parent_dir:
                os.makedirs(parent_dir, exist_ok=True)

            with open(file_path, "w", encoding="utf-8") as f:
                f.write(output)
                if not output.endswith("\n"):
                    f.write("\n")

            print(f"[SUCCESS] Running-config saved to {os.path.abspath(file_path)}\n")
            return True
        except Exception as e:
            print(f"[ERROR] Could not save running-config: {e}\n")
            return False

    def handle_local_command(self, cmd):
        """Handle local helper commands before sending input to the device."""
        lowered = cmd.lower()
        for prefix in ("ouput rcfg ", "output rcfg "):
            if lowered.startswith(prefix):
                file_path = cmd[len(prefix):].strip()
                self.save_running_config(file_path)
                return True

        if lowered in ("ouput rcfg", "output rcfg"):
            print("[ERROR] Missing file path. Usage: output rcfg <file_path>\n")
            return True

        if lowered == "ospf help":
            self.show_ospf_help()
            return True

        if lowered == "ospf list":
            self.handle_ospf_list()
            return True

        if lowered.startswith("ospf "):
            self.handle_ospf_command(cmd)
            return True

        return False

    def _ospf_api(self):
        if not self.db_path:
            print("[ERROR] OSPF DB commands are only available when logged in from database.\n")
            return None

        try:
            from routing.ospf_api import OspfApi
            return OspfApi(self.db_path, self.host, self.connection)
        except Exception as e:
            print(f"[ERROR] Could not load OSPF API: {e}\n")
            return None

    def show_ospf_help(self):
        print("\nOSPF commands:")
        print("  ospf list")
        print("  ospf pending [process_id]")
        print("  ospf apply [process_id]\n")
        print("OSPF data must be created/edited by the Qt app in device_network.db.")

    def handle_ospf_list(self):
        api = self._ospf_api()
        if not api:
            return

        try:
            rows = api.list_processes()
        except Exception as e:
            print(f"[ERROR] Could not list OSPF data: {e}\n")
            return

        if not rows:
            print("[INFO] No OSPF process found for this host.\n")
            return

        print("\nOSPF processes:")
        for row in rows:
            print(
                f"  process={row['process_id']} router_id={row['router_id'] or '-'} "
                f"ref_bw={row['reference_bandwidth'] or '-'} networks={row['network_count']} "
                f"areas={row['area_count']} passive={row['passive_count']} "
                f"success={row['success']}"
            )
        print()

    def handle_ospf_command(self, cmd):
        api = self._ospf_api()
        if not api:
            return

        try:
            parts = shlex.split(cmd)
            if len(parts) < 2:
                self.show_ospf_help()
                return

            action = parts[1].lower()

            if action == "list" and len(parts) == 2:
                self.handle_ospf_list()
                return

            if action == "pending" and len(parts) in (2, 3):
                process_id = int(parts[2]) if len(parts) == 3 else None
                commands, _ = api.build_pending_commands(process_id)
                if not commands:
                    print("No pending OSPF changes.\n")
                    return
                print("\nPending OSPF commands:")
                for command in commands:
                    print(f"  {command}")
                print()
                return

            if action == "apply" and len(parts) in (2, 3):
                process_id = int(parts[2]) if len(parts) == 3 else None
                print("[INFO] Applying pending OSPF changes...")
                output = api.apply_pending(process_id)
                print(f"\n{output}\n")
                return

            self.show_ospf_help()
        except Exception as e:
            print(f"[ERROR] OSPF command failed: {e}\n")
    
    def interactive_cli(self):
        """Interactive CLI mode"""
        if not self.connected:
            print("[ERROR] Not connected to device\n")
            return
        
        print("="*60)
        print(f" Connected to: {self.host}")
        print(f" Type 'exit' to disconnect or 'quit' for help")
        print("="*60 + "\n")
        
        try:
            while self.connected:
                try:
                    # Custom prompt with host
                    cmd = input(f">>({self.host})> ").strip()
                    
                    if not cmd:
                        continue
                    
                    if cmd.lower() == 'exit':
                        print("[INFO] Exiting interactive CLI...")
                        break
                    
                    if cmd.lower() == 'quit':
                        print("\nAvailable commands:")
                        print("  - Any CLI command for the device")
                        print("  - ouput rcfg <file_path> to save 'do show running-config'")
                        print("  - ospf help for DB-backed OSPF apply")
                        print("  - 'exit' to disconnect and return to main menu\n")
                        continue

                    if self.handle_local_command(cmd):
                        continue
                    
                    # Send command to device
                    print(f"\n[INFO] Executing: {cmd}")
                    output = self.send_command(cmd)
                    
                    if output is not None:
                        print(f"\n{output}\n")
                    
                except KeyboardInterrupt:
                    print("\n[INFO] Interrupted by user")
                    break
                except EOFError:
                    print("\n[*] Connection closed")
                    break
        
        except Exception as e:
            print(f"\n[ERROR] CLI Error: {e}\n")
        
        finally:
            self.disconnect()


def login_device(host, method, port, username, password, device_type='cisco_ios', start_config_mode=False, db_path=None):
    """
    Simplified login function that returns a DeviceConnector instance
    """
    connector = DeviceConnector(
        host,
        method,
        port,
        username,
        password,
        device_type,
        start_config_mode=start_config_mode,
        db_path=db_path,
    )
    
    if connector.connect():
        connector.interactive_cli()
        return True
    
    return False


# Example usage
if __name__ == "__main__":
    # Test parameters
    test_host = "192.168.1.1"
    test_method = "ssh"
    test_port = "22"
    test_user = "admin"
    test_pass = "cisco123"
    
    login_device(test_host, test_method, test_port, test_user, test_pass)
