import os

dir_path = r'E:\NetworkTools\backend\sql\sql_new'
file1 = os.path.join(dir_path, '02_interface.sql')
file2 = os.path.join(dir_path, '10_router_interface.sql')
output_file = os.path.join(dir_path, '02_router_interface.sql')

with open(file1, 'r', encoding='utf-8') as f1, open(file2, 'r', encoding='utf-8') as f2:
    content = f1.read() + '\n' + f2.read()

with open(output_file, 'w', encoding='utf-8') as fout:
    fout.write(content)

os.remove(file1)
os.remove(file2)
print("Merged 02 and 10 into 02_router_interface.sql and deleted the original files.")
