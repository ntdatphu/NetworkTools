# Device Guard Readiness Tool v3.6

> **Mục đích:** Lưu trữ công cụ của Microsoft dùng để kiểm tra, bật hoặc tắt **Virtualization-Based Security (VBS)**, **Credential Guard**, **Device Guard** và **HVCI (Memory Integrity)**.

> **Lưu ý:** Thư mục này được giữ lại vì có thể cần trong quá trình nghiên cứu hoặc khắc phục lỗi trên Windows 11.

---

# Tại sao lưu công cụ này?

Trong quá trình làm **Nghiên cứu Khoa học (NCKH)** với các dự án mạng như:

- EVE-NG
- GNS3
- VMware Workstation
- VirtualBox
- Hyper-V
- Nested Virtualization

Windows 11 đôi khi tự kích hoạt các tính năng bảo mật dựa trên ảo hóa như:

- Virtualization Based Security (VBS)
- Credential Guard
- Device Guard
- HVCI (Memory Integrity)

Các tính năng này có thể làm VMware hoặc VirtualBox **không sử dụng trực tiếp VT-x/AMD-V**, dẫn đến nhiều vấn đề.

Ví dụ:

- Không bật được **Virtualize Intel VT-x/EPT or AMD-V/RVI**.
- Nested Virtualization bị khóa.
- EVE-NG chạy rất chậm.
- Không khởi động được máy ảo IOSv, CSR1000v, Fortigate...
- VMware báo:

```
Module 'HV' power on failed.
```

hoặc

```
Virtualized Intel VT-x/EPT is disabled for this ESX VM.
```

hoặc

```
VMware and Device/Credential Guard are not compatible.
```

---

# Bộ công cụ gồm

| File | Chức năng |
|------|-----------|
| DG_Readiness_Tool_v3.6.ps1 | Script PowerShell kiểm tra/bật/tắt Device Guard, Credential Guard và HVCI |
| DefaultWindows_Audit.xml | Chính sách WDAC ở chế độ Audit |
| DefaultWindows_Audit_sipolicy.p7b | Policy Audit dạng nhị phân |
| DefaultWindows_Enforced.xml | Chính sách WDAC ở chế độ Enforced |
| DefaultWindows_Enforced_sipolicy.p7b | Policy Enforced dạng nhị phân |
| ReadMe.txt | Tài liệu Microsoft |

---

# Khi nào nên dùng?

Chỉ sử dụng khi nghi ngờ Windows đang bật các cơ chế bảo mật làm ảnh hưởng tới ảo hóa.

Ví dụ:

- Không bật được Nested Virtualization.
- VMware báo đang chạy trên Hyper-V.
- Memory Integrity không thể tắt.
- Credential Guard tự bật lại.
- Hyper-V đã gỡ nhưng VMware vẫn báo lỗi.

---

# Kiểm tra khả năng hỗ trợ

```powershell
.\DG_Readiness_Tool_v3.6.ps1 -Capable
```

---

# Kiểm tra trạng thái hiện tại

```powershell
.\DG_Readiness_Tool_v3.6.ps1 -Ready
```

---

# Bật HVCI

```powershell
.\DG_Readiness_Tool_v3.6.ps1 -Enable -HVCI
```

---

# Bật Device Guard

```powershell
.\DG_Readiness_Tool_v3.6.ps1 -Enable
```

---

# Tắt Device Guard / Credential Guard

```powershell
.\DG_Readiness_Tool_v3.6.ps1 -Disable
```

Khởi động lại máy sau khi hoàn thành.

---

# Quan trọng

Script này **không phải** là công cụ tắt Hyper-V thông thường.

Nó chỉ hỗ trợ quản lý:

- Device Guard
- Credential Guard
- HVCI
- Virtualization-Based Security (VBS)

Nếu Hyper-V vẫn còn được cài đặt thì cần gỡ hoặc vô hiệu hóa bằng các phương pháp khác.

---

# Khi nào nên sử dụng trong NCKH?

Đối với các đề tài:

- Quản trị mạng
- Mô phỏng mạng
- Network Automation
- SDN
- EVE-NG
- GNS3
- VMware Lab
- Cisco IOSv
- Cisco CSR1000v
- Fortigate VM
- Palo Alto VM
- Ubuntu Server Lab

nên kiểm tra VBS trước nếu:

- Nested Virtualization không bật được.
- Máy ảo chạy cực chậm.
- VMware báo đang dùng Hyper-V.
- Không thể chạy các router/firewall ảo.

---

# Khuyến nghị

Nếu sau này cài lại Windows 11 và gặp lỗi:

- Không tick được **Virtualize Intel VT-x/EPT or AMD-V/RVI**
- VMware báo đang chạy trên Hyper-V
- EVE-NG không chạy được nested virtualization

hãy nhớ kiểm tra theo thứ tự:

1. BIOS đã bật Intel VT-x / AMD-V.
2. Hyper-V đã được tắt.
3. Memory Integrity đã tắt.
4. VBS đã tắt.
5. Credential Guard đã tắt.
6. Device Guard đã tắt.
7. Nếu vẫn lỗi, sử dụng **DG_Readiness_Tool v3.6** để kiểm tra hoặc vô hiệu hóa các thành phần bảo mật còn sót lại.

---

# Nguồn

Microsoft Device Guard Readiness Tool v3.6