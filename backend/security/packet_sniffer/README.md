# Thu nghiem PyShark va Scapy

Bo file nay giup ban test nhanh 2 thu vien:
- PyShark: doc packet thong qua tshark
- Scapy: sniff/goi packet truc tiep

## 1) Cai dat

Yeu cau:
- Python 3.10+
- Quyen admin (de sniff packet tren Windows)
- Wireshark/TShark (bat buoc cho PyShark)

Cai thu vien Python:

pip install -r requirements.txt

Neu pyshark bao loi khong tim thay tshark, hay cai Wireshark va dam bao co lenh tshark trong PATH.

## 2) Chay script PyShark

Liet ke interface:

python -c "import pyshark; print(pyshark.tshark.tshark.get_tshark_interfaces())"

Bat 10 packet:

python pyshark_live_capture.py --interface "Wi-Fi" --count 10

Bat packet co filter:

python pyshark_live_capture.py --interface "Wi-Fi" --count 10 --display-filter "tcp"

## 3) Chay script Scapy sniff

Bat 10 packet:

python scapy_sniff.py --count 10

Bat packet theo BPF filter:

python scapy_sniff.py --count 10 --bpf "icmp"

Neu can chi ro interface:

python scapy_sniff.py --count 10 --iface "Wi-Fi"

## 4) Chay script Scapy gui ICMP

python scapy_send_icmp.py 8.8.8.8

## 5) Ghi chu

- Tren Windows, nen chay terminal voi quyen admin de sniff packet.
- Neu ban muon thu vien "pyshack" (khac pyshark), noi ro ten package de minh bo sung dung thu vien.
