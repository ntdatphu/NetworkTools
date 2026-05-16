"""
Device connector module for SSH/Telnet CLI access using Netmiko
"""
from netmiko import ConnectHandler
from netmiko.exceptions import NetmikoTimeoutException, NetmikoAuthenticationException, ConnectionException
import sys

class DeviceConnector:
    """Manages connection and interactive CLI to network devices"""
    
    def __init__(self, host, method, port, username, password, device_type='cisco_ios'):
        """Initialize device connector parameters"""
        self.host = host
        self.method = method.lower()
        self.port = int(port)
        self.username = username if username else ''
        self.password = password if password else ''
        self.device_type = device_type
        self.connection = None
        self.connected = False
    
    def connect(self):
        """Establish connection to the device"""
        try:
            # Prepare device parameters
            device_params = {
                'device_type': self.device_type,
                'host': self.host,
                'port': self.port,
                'username': self.username,
                'password': self.password,
            }
            
            # Adjust device type for telnet
            if self.method == 'telnet':
                device_params['device_type'] = f"{self.device_type}_telnet"
            
            print(f"\n[*] Connecting to {self.host} ({self.method.upper()})...")
            self.connection = ConnectHandler(**device_params)
            self.connected = True
            print(f"[✓] Successfully connected to {self.host}\n")
            return True
            
        except NetmikoTimeoutException:
            print(f"\n[✗] Connection timeout to {self.host}\n")
            return False
        except NetmikoAuthenticationException:
            print(f"\n[✗] Authentication failed for {self.host} (invalid credentials)\n")
            return False
        except ConnectionException as e:
            print(f"\n[✗] Connection error: {e}\n")
            return False
        except Exception as e:
            print(f"\n[✗] Unexpected error: {e}\n")
            return False
    
    def disconnect(self):
        """Close connection to device"""
        if self.connection:
            try:
                self.connection.disconnect()
                self.connected = False
                print(f"\n[✓] Disconnected from {self.host}\n")
            except Exception as e:
                print(f"[✗] Error disconnecting: {e}\n")
    
    def send_command(self, command):
        """Send command and return output"""
        if not self.connected or not self.connection:
            print("[✗] Not connected to device\n")
            return None
        
        try:
            output = self.connection.send_command(command)
            return output
        except Exception as e:
            print(f"[✗] Error executing command: {e}\n")
            return None
    
    def interactive_cli(self):
        """Interactive CLI mode"""
        if not self.connected:
            print("[✗] Not connected to device\n")
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
                        print("[*] Exiting interactive CLI...")
                        break
                    
                    if cmd.lower() == 'quit':
                        print("\nAvailable commands:")
                        print("  - Any CLI command for the device")
                        print("  - 'exit' to disconnect and return to main menu\n")
                        continue
                    
                    # Send command to device
                    print(f"\n[*] Executing: {cmd}")
                    output = self.send_command(cmd)
                    
                    if output is not None:
                        print(f"\n{output}\n")
                    
                except KeyboardInterrupt:
                    print("\n[*] Interrupted by user")
                    break
                except EOFError:
                    print("\n[*] Connection closed")
                    break
        
        except Exception as e:
            print(f"\n[✗] CLI Error: {e}\n")
        
        finally:
            self.disconnect()


def login_device(host, method, port, username, password, device_type='cisco_ios'):
    """
    Simplified login function that returns a DeviceConnector instance
    """
    connector = DeviceConnector(host, method, port, username, password, device_type)
    
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
