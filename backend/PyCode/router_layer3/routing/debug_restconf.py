import requests
import json
import urllib3

urllib3.disable_warnings()

# Đổi URL chĩa thẳng vào phần tử OSPF Process 1 thay vì Interface
url = "https://192.168.121.17/restconf/data/Cisco-IOS-XE-native:native/router/Cisco-IOS-XE-ospf:router-ospf/ospf/process-id=1"
headers = {"Accept": "application/yang-data+json"}

print("Đang nội soi cấu trúc OSPF Global (Process 1) YANG của C8K7...")
res = requests.get(url, auth=("admin", "admin"), headers=headers, verify=False)

if res.status_code == 200:
    parsed = json.loads(res.text)
    print("\n[+] JSON CHUẨN CỦA OSPF PROCESS 1 LÀ:")
    print(json.dumps(parsed, indent=4))
else:
    print(f"[-] Lỗi: {res.status_code} - {res.text}")