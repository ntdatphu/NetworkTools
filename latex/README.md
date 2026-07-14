# Template báo cáo NCKH sinh viên LaTeX

## Cách build

```powershell
./build.ps1
```

Dọn file trung gian:

```powershell
./build.ps1 -Clean
```

Xóa cả PDF và thư mục build:

```powershell
./build.ps1 -CleanAll
```

## Trang bìa

Trang bìa làm riêng. Nếu muốn chèn vào báo cáo, đặt file:

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

Đặt ảnh vào `figures/`, ví dụ:

```text
figures/gui/main_window.png
```

Chèn ảnh:

```latex
\insertimage{0.8\textwidth}{main_window}{Giao diện chính}{fig:main-window}
```
