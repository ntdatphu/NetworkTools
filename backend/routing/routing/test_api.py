import requests
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# Bắn thẳng vào gốc của Area 40
url_delete_area = "https://192.168.121.17/restconf/data/Cisco-IOS-XE-native:native/router/Cisco-IOS-XE-ospf:router-ospf/ospf/process-id=1"

headers = {
    "Accept": "application/yang-data+json",
    "Content-Type": "application/yang-data+json"
}
auth = ("admin", "admin")

print("--- TEST RESTCONF THUẦN: XÓA TRẮNG AREA ĐỂ VỀ NORMAL ---")
res = requests.delete(url_delete_area, auth=auth, headers=headers, verify=False)

print(f"Status Code: {res.status_code}")
if res.status_code >= 400:
    print(f"Lỗi: {res.text}")
else:
    print("Thành công! Lên CLI gõ 'show run | sec ospf' check ngay xem NSSA bay chưa, và Network còn không!")