# NetworkTools – Typst report

Bộ báo cáo NCKH đã được chuyển từ cấu trúc LaTeX modular sang Typst.

## Cấu trúc

```text
networktools_typst/
├── appendix/
├── chapters/
├── config/
├── cover/
├── docs/
├── figures/
├── build.ps1
├── build.sh
├── main.typ
└── networktools_references.bib
```

## Build

Cài Typst, sau đó chạy:

```bash
typst compile main.typ build/networktools.pdf
```

Hoặc trên Linux/macOS:

```bash
./build.sh
```

PowerShell:

```powershell
./build.ps1
```

Theo dõi và tự biên dịch khi sửa:

```bash
typst watch main.typ build/networktools.pdf
```

## Ảnh

Đặt ảnh vào `figures/`, ví dụ:

```text
figures/gui/main_window.png
```

Trong file `.typ`:

```typst
#insert-image(
  "figures/gui/main_window.png",
  width: 80%,
  caption: [Giao diện chính của NetworkTools],
) <fig-main-window>
```

Tham chiếu:

```typst
Xem @fig-main-window.
```

## Tài liệu tham khảo

Typst đọc trực tiếp BibLaTeX/BibTeX `.bib`:

```typst
Theo @tanenbaum2021computer, ...
```

Nếu project LaTeX gốc đã có `networktools_references.bib`, hãy chép đè file mẫu trong project này để giữ toàn bộ nguồn cũ.

## Lưu ý

- `packages.tex` và `latexmkrc` không còn cần thiết.
- Các chapter và appendix đã được tạo dựa trên đề cương hiện tại.
- Các vị trí `TODO` cần cập nhật bằng thông tin, ảnh, test và số đo thực tế trước khi nộp.
