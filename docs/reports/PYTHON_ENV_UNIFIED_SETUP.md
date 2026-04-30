# PYTHON ENV UNIFIED SETUP

## Muc tieu
Dung mot moi truong Python chung cho toan bo thu muc `script/`, tranh tinh trang tach roi va cai trung lap.

## Cau truc hien tai
- `script/requirements.txt`: file trung tam de cai dependency chung.
- `script/login/requirements.txt`: dependency theo domain login/protocol.
- `script/database/init_db.py`: script tao DB tu `data.sql`, chi dung thu vien chuan (`sqlite3`).

## Nguyen tac su dung
1. Chi tao **mot** `.venv` tai root project.
2. Chi cai dependency qua `script/requirements.txt`.
3. Cac requirement theo domain duoc include tu file trung tam (hien tai include `login/requirements.txt`).

## Lenh cai dat de xuat (Windows PowerShell)
```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r script/requirements.txt
```

## Lien quan den C++ khoi tao DB
`DatabaseConnection` goi `script/database/init_db.py` qua `QProcess`.
De tranh loi alias `python` tren Windows, code da thu nhieu interpreter theo thu tu uu tien:
- `.venv/Scripts/python.exe` (gan thu muc app)
- `python` / `python3` tim duoc tu PATH
- `py -3`

Khuyen nghi: luon co `.venv` o root project va cai dependency bang file trung tam de han che sai lech moi truong.

## Ghi chu bao tri
Khi them module Python moi:
1. Neu dung chung cho nhieu nhom script, them truc tiep vao `script/requirements.txt`.
2. Neu chi thuoc domain login, them vao `script/login/requirements.txt`.
3. Van giu `script/requirements.txt` la diem vao duy nhat de cai dat.
