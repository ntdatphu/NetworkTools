# Icon loại file của SFTP

Cập nhật ngày **2026-07-18**. Tài liệu này mô tả bộ icon trong
`app/UI/resources/files/`, nguồn upstream và luật chọn icon ở runtime.

## 1. Nguồn và phiên bản

- Nguồn: [Material Icon Theme](https://github.com/material-extensions/vscode-material-icon-theme), phiên bản `5.36.1`.
- Snapshot được dùng: commit [`cf0df2b786de4eca01b06cb7118435c6d195a0d1`](https://github.com/material-extensions/vscode-material-icon-theme/tree/cf0df2b786de4eca01b06cb7118435c6d195a0d1).
- Danh sách liên kết tên/đuôi file được đối chiếu từ
  [`fileIcons.ts`](https://github.com/material-extensions/vscode-material-icon-theme/blob/cf0df2b786de4eca01b06cb7118435c6d195a0d1/src/core/icons/fileIcons.ts).
- 54 SVG trong `files/types/` được sao chép nguyên trạng từ thư mục
  [`icons/`](https://github.com/material-extensions/vscode-material-icon-theme/tree/cf0df2b786de4eca01b06cb7118435c6d195a0d1/icons).
- `files/file.svg` và `files/folder.svg` dùng đúng path do
  [`fileGenerator.ts`](https://github.com/material-extensions/vscode-material-icon-theme/blob/cf0df2b786de4eca01b06cb7118435c6d195a0d1/src/core/generator/fileGenerator.ts)
  và [`folderGenerator.ts`](https://github.com/material-extensions/vscode-material-icon-theme/blob/cf0df2b786de4eca01b06cb7118435c6d195a0d1/src/core/generator/folderGenerator.ts)
  sinh ra, với màu mặc định `#90a4ae` từ `defaultConfig.ts`.
- Giấy phép upstream là MIT và được giữ nguyên tại
  `app/UI/resources/licenses/MATERIAL-ICON-THEME.txt`.

Material Icon Theme có nhiều icon chuyên biệt hơn bộ được nhập. NetworkTools chỉ
giữ những nhóm có khả năng xuất hiện trong SFTP hoặc luồng cấu hình mạng để tránh
đưa toàn bộ hơn 900 SVG upstream vào runtime.

## 2. Cách runtime chọn icon

Mọi đường dẫn và luật ánh xạ nằm trong
`app/UI/qml/shared/AppAssets.qml`. `SftpFilePanel.qml` chỉ gọi:

```qml
AppAssets.fileTypeIcon(fileName)
```

Thứ tự xử lý:

1. So khớp tên file đặc biệt trước, ví dụ `Dockerfile`, `.env.production`,
   `LICENSE.md`, `requirements.txt`.
2. Nếu không khớp, so đuôi file không phân biệt hoa/thường.
3. Nếu chưa có luật, trả về chuỗi rỗng và SFTP hiển thị `files/file.svg`.
4. Directory luôn hiển thị `files/folder.svg`. UI hiện không có trạng thái folder
   mở nên không giữ thêm `folder-open.svg` trong runtime.

Icon được render bằng `Image` để giữ màu gốc của Material Icon Theme. Không dùng
`ThemedIcon`/ColorOverlay cho nhóm này vì thao tác đó sẽ biến icon nhiều màu thành
một màu của theme.

## 3. Inventory 54 icon loại file

| Property trong `AppAssets` | SVG trong `files/types/` | Tên/đuôi file tiêu biểu |
|---|---|---|
| `fileTypeArchive` | `zip.svg` | `zip`, `7z`, `rar`, `tar`, `gz`, `xz`, `zst`, `iso`, `dmg` |
| `fileTypeAudio` | `audio.svg` | `mp3`, `wav`, `flac`, `aac`, `ogg`, `m4a`, `opus`, `midi` |
| `fileTypeBinary` | `hex.svg` | `bin`, `dat`, `hex`; NetworkTools mở rộng cho `cap`, `pcap`, `pcapng` |
| `fileTypeC` | `c.svg` | `c`, `i`, `mi` |
| `fileTypeCertificate` | `certificate.svg` | `cer`, `cert`, `crt`, `csr`, `p12`, `pfx` |
| `fileTypeCpp` | `cpp.svg` | `cc`, `cpp`, `cxx`, `c++` |
| `fileTypeCppHeader` | `hpp.svg` | `hh`, `hpp`, `hxx`, `h++`, `tcc`, `inl` |
| `fileTypeCHeader` | `h.svg` | `h` |
| `fileTypeCss` | `css.svg` | `css`; dùng cùng nhóm cho `scss`, `sass`, `less`, `styl` |
| `fileTypeDatabase` | `database.svg` | `sql`, `sqlite`, `db`, `mdb`, `accdb`, `dump` |
| `fileTypeDocker` | `docker.svg` | `Dockerfile`, `Containerfile`, `.dockerignore`, Compose YAML |
| `fileTypeEmail` | `email.svg` | `eml`, `msg`, `mbox`, `emlx` |
| `fileTypeEnvironment` | `tune.svg` | `.env`, `.env.*` |
| `fileTypeExecutable` | `exe.svg` | `exe`, `msi`, `com`, `appimage` |
| `fileTypeFont` | `font.svg` | `ttf`, `otf`, `woff`, `woff2`, `eot` |
| `fileTypeGit` | `git.svg` | `.gitignore`, `.gitattributes`, `.gitmodules`, `patch`, `diff` |
| `fileTypeGo` | `go.svg` | `go` |
| `fileTypeHtml` | `html.svg` | `html`, `htm`, `xhtml`, `shtml`, `asp`, `aspx` |
| `fileTypeImage` | `image.svg` | `png`, `jpg`, `gif`, `webp`, `tiff`, `avif`, `heic`, `raw` |
| `fileTypeJava` | `java.svg` | `java`, `jav`, `jsp` |
| `fileTypeJavaScript` | `javascript.svg` | `js`, `mjs`, `cjs`, `es6`, `pac` |
| `fileTypeJson` | `json.svg` | `json`, `jsonc`, `json5`, `jsonl`, `geojson`, `har`, `webmanifest` |
| `fileTypeKey` | `key.svg` | `key`, `pem`, `pub`, `ppk`, `asc`, `gpg` |
| `fileTypeKotlin` | `kotlin.svg` | `kt`, `kts` |
| `fileTypeLicense` | `license.svg` | `LICENSE`, `LICENCE`, `COPYING` và biến thể có đuôi |
| `fileTypeLog` | `log.svg` | `log` |
| `fileTypeLua` | `lua.svg` | `lua` |
| `fileTypeMarkdown` | `markdown.svg` | `md`, `markdown`, `mdown`, `mkd`, `rst` |
| `fileTypePdf` | `pdf.svg` | `pdf` |
| `fileTypePhp` | `php.svg` | `php`, `php3`, `php4`, `php5`, `phtml` |
| `fileTypePowerPoint` | `powerpoint.svg` | `ppt`, `pptx`, `pptm`, `potx`, `ppsx`, `odp` |
| `fileTypePowerShell` | `powershell.svg` | `ps1`, `psm1`, `psd1`, `ps1xml`, `pssc` |
| `fileTypeProtobuf` | `proto.svg` | `proto` |
| `fileTypePython` | `python.svg` | `py`, `pyi`, `pyw`, `pyx`, `rpy`; tên file dự án Python |
| `fileTypeReact` | `react.svg` | `jsx` |
| `fileTypeReactTypeScript` | `react_ts.svg` | `tsx` |
| `fileTypeRuby` | `ruby.svg` | `rb`, `ruby`, `rake`, `gemspec` |
| `fileTypeRust` | `rust.svg` | `rs`, `ron` |
| `fileTypeSettings` | `settings.svg` | `ini`, `cfg`, `conf`, `config`, `properties`, dotfile cấu hình |
| `fileTypeShell` | `console.svg` | `sh`, `bash`, `zsh`, `fish`, `bat`, `cmd`, shell dotfile |
| `fileTypeSpreadsheet` | `table.svg` | `xls`, `xlsx`, `xlsm`, `csv`, `tsv`, `psv`, `ods` |
| `fileTypeSvelte` | `svelte.svg` | `svelte` |
| `fileTypeSvg` | `svg.svg` | `svg`; được kiểm tra trước nhóm ảnh |
| `fileTypeSwift` | `swift.svg` | `swift` |
| `fileTypeText` | `document.svg` | `txt`, `text`, `nfo` |
| `fileTypeToml` | `toml.svg` | `toml` |
| `fileTypeTypeScript` | `typescript.svg` | `ts`, `mts`, `cts` |
| `fileTypeVideo` | `video.svg` | `mp4`, `mkv`, `avi`, `mov`, `webm`, `mpeg`, `3gp` |
| `fileTypeVirtualMachine` | `virtual.svg` | `vdi`, `vbox`, `vhd`, `vhdx`, `vmdk`, `ova`, `ovf` |
| `fileTypeVue` | `vue.svg` | `vue` |
| `fileTypeWord` | `word.svg` | `doc`, `docx`, `docm`, `rtf`, `odt` |
| `fileTypeXml` | `xml.svg` | `xml`, `xsd`, `xsl`, `xslt`, `plist`, `wsdl` |
| `fileTypeYaml` | `yaml.svg` | `yaml`, `yml` |

Các association phổ biến bám theo upstream. Một số đuôi gần nghĩa được gom vào
icon sẵn có để phù hợp dữ liệu thực tế của NetworkTools, ví dụ packet capture dùng
`hex.svg`, SCSS/Less dùng `css.svg`, và định dạng máy ảo dùng `virtual.svg`. Không
sửa nội dung SVG cho các association mở rộng này.

## 4. Tài nguyên cũ chờ duyệt

Sáu icon bị thay thế không bị xóa ngay:

- `_unused/legacy/files/lucide-file.svg` và `lucide-folder.svg`;
- `_unused/legacy/files/vscode-icons/cpp.svg`, `markdown.svg`, `python.svg`,
  `text.svg`.

Chúng không có mapping trong `AppAssets.qml` và không được đóng gói như tài nguyên
runtime. Có thể xóa sáu file này sau khi kiểm tra giao diện hoàn tất; khi đó vẫn
giữ `VSCODE-ICONS.txt` nếu còn SVG vscode-icons khác, hoặc xóa license đó nếu không
còn tài sản tương ứng.

## 5. Quy trình bảo trì

1. Kiểm tra icon/association upstream và giấy phép trước khi nhập.
2. Chỉ thêm SVG cần thiết vào `files/types/`.
3. Thêm một property semantic và luật tương ứng trong `AppAssets.qml`.
4. Không ghi đường dẫn SVG trực tiếp trong `SftpFilePanel.qml` hay consumer khác.
5. Cập nhật bảng trên và contract count trong `app/tests/test_ui_contracts.py`.
6. Chạy `tests.test_ui_contracts` và smoke test QML cho file-type mapping.
