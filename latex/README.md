# Template báo cáo NCKH sinh viên LaTeX

Tài liệu này hướng dẫn cách biên dịch dự án LaTeX bằng hai script phù hợp với hai hệ điều hành:

- Linux/macOS: [build.sh](build.sh)
- Windows PowerShell: [build.ps1](build.ps1)

## Yêu cầu

Trước khi build, hãy chắc chắn rằng bạn đã cài đặt:

- LaTeX
- `latexmk`
- `xelatex`

Chạy các lệnh này từ thư mục [latex](.) .

## Cách build

### Linux/macOS

Cấp quyền thực thi cho script trước lần chạy đầu tiên:

```bash
chmod +x build.sh
./build.sh
```

### Windows PowerShell

```powershell
./build.ps1
```

## Dọn file trung gian

### Linux/macOS

```bash
./build.sh --clean     # Chỉ xoá các file sau khi build
./build.sh --clean-all # Xoá toàn bộ file kể cả file PDF
```

### Windows PowerShell

```powershell
./build.ps1 -Clean     # Chỉ xoá các file sau khi build
./build.ps1 -CleanAll  # Xoá toàn bộ file kể cả file PDF
```

## Build với file LaTeX khác

Nếu bạn muốn build một file `.tex` khác thay vì `main.tex`, có thể dùng:

### Linux/macOS

```bash
./build.sh --file another_main.tex
```

### Windows PowerShell

```powershell
./build.ps1 -File "another_main.tex"
```

## Trang bìa

Trang bìa được tách riêng. Nếu muốn chèn vào báo cáo, hãy đặt file sau:

```text
cover/bia.pdf
```

Sau đó mở `main.tex` và bỏ comment khối `\includepdf`.

## Tài liệu tham khảo

Thêm nguồn vào `networktools_references.bib`, sau đó trích dẫn trong nội dung:

```latex
\cite{tanenbaum2021computer}
```

## Ảnh

Đặt ảnh vào thư mục `figures/`, ví dụ:

```text
figures/gui/main_window.png
```

Chèn ảnh bằng lệnh sau:

```latex
\insertimage{0.8\textwidth}{main_window}{Giao diện chính}{fig:main-window}
```
