import os
import sqlite3

# Xác định đường dẫn tương đối để chạy mượt trên mọi máy
DB_DIR = os.path.dirname(os.path.abspath(__file__))
SQL_DIR = os.path.join(DB_DIR, "device_network")
DB_PATH = os.path.join(DB_DIR, "device_network.db")

def rebuild_database():
    print(f"[*] Đang chuẩn bị build lại Database: {DB_PATH}")
    
    # Kết nối tới file DB (nếu chưa có nó sẽ tự tạo)
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # Lấy danh sách file .sql trong thư mục device_network và sắp xếp theo tên (01 -> 09)
    try:
        sql_files = [f for f in os.listdir(SQL_DIR) if f.endswith('.sql')]
        sql_files.sort()
    except FileNotFoundError:
        print(f"[-] Không tìm thấy thư mục chứa SQL: {SQL_DIR}")
        return

    if not sql_files:
        print("[-] Không có file .sql nào để chạy!")
        return

    # Duyệt qua từng file và thực thi
    for file_name in sql_files:
        file_path = os.path.join(SQL_DIR, file_name)
        print(f"  [+] Đang nạp schema từ: {file_name} ...", end=" ")
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                sql_script = f.read()
            # Dùng executescript để chạy nhiều câu lệnh (CREATE TABLE, INSERT...) cùng lúc
            cursor.executescript(sql_script)
            print("OK")
        except Exception as e:
            print(f"LỖI!\n      Chi tiết: {e}")

    # Lưu lại thay đổi và đóng kết nối
    conn.commit()
    conn.close()
    print("\n[*] Đã build/cập nhật xong toàn bộ Database Letos!")

if __name__ == "__main__":
    rebuild_database()