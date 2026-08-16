# Third-party source (`vendor/`)

Cập nhật provenance/contract: **2026-08-16**. Markdown bên trong snapshot
Alacritty thuộc upstream và không phải tài liệu NetworkTools.

Thư mục `vendor/` chứa mã nguồn bên thứ ba được đưa trực tiếp vào repository
NetworkTools khi dự án cần build một phiên bản đã chỉnh sửa và không thể chỉ
dùng package hệ thống.

## `vendor/alacritty`

`vendor/alacritty` là snapshot từ repository upstream
<https://github.com/alacritty/alacritty>. NetworkTools giữ source trong cùng
repository để `networktools.sh setup` có thể build terminal companion đồng bộ
với contract Python/QML hiện tại, không phụ thuộc một binary cài sẵn trên máy.

Fork cục bộ này khác Alacritty upstream ở các điểm chính:

- binary release có tên `networktools-terminal`;
- nhận các tham số managed `--nt-*`;
- kết nối NTTP/1 qua Unix local socket;
- xử lý focus, close, title, ping và session info từ NetworkTools;
- giữ cửa sổ mở khi SSH child thoát để người dùng đọc lỗi;
- dùng Alacritty làm renderer/PTY cho interactive SSH child của NetworkTools.

Phần Python quản lý companion nằm tại `features/terminal/`. Cisco IOS legacy
dùng adapter `features/terminal/interactive_ssh.py` vì Fedora libcrypto có thể
từ chối chữ ký RSA/SHA-1 của IOS cũ. Password không được truyền qua argv,
environment hay NTTP.

## Build và kiểm tra

Từ thư mục `app/`:

```bash
./networktools.sh terminal-build
./networktools.sh terminal-check
```

Binary sinh ra tại:

```text
vendor/alacritty/target/release/networktools-terminal
```

Toàn bộ `vendor/alacritty/target/` là build artifact và đã được ignore bởi
`vendor/alacritty/.gitignore`. Không dùng `git add -f` cho thư mục này. Trước
khi push, nên kiểm tra:

```bash
git status --short
git check-ignore -v vendor/alacritty/target/release/networktools-terminal
```

## Có xóa `.builds` và `.github` không?

Không bắt buộc xóa:

- `vendor/alacritty/.builds/` là cấu hình CI của upstream;
- `vendor/alacritty/.github/` là workflow và pull-request template của upstream;
- vì chúng không nằm tại `.github/` ở root repository NetworkTools, GitHub
  không chạy các workflow lồng này cho NetworkTools;
- tổng dung lượng hai thư mục rất nhỏ và việc giữ lại giúp snapshot gần với
  upstream hơn khi đối chiếu hoặc cập nhật.

Chỉ xóa hai thư mục trên nếu dự án chủ động áp dụng chính sách "vendor tối
thiểu". Việc xóa không làm thay đổi runtime hoặc kết quả build, nhưng sẽ tạo
thêm khác biệt khi đồng bộ một phiên bản Alacritty upstream mới. Mặc định của
NetworkTools là **giữ lại**.

## License và cập nhật upstream

Phải giữ `LICENSE-APACHE`, `LICENSE-MIT` và các notice/license nằm trong source
Alacritty. Không thay thế chúng bằng license riêng của NetworkTools.

Khi cập nhật upstream:

1. ghi lại commit/tag Alacritty nguồn trong pull request;
2. cập nhật source nhưng không chép `.git/` của repository lồng vào đây;
3. áp dụng lại các thay đổi NetworkTools trong CLI, event loop và NTTP client;
4. chạy `./networktools.sh terminal-build` và test terminal contract;
5. kiểm tra chắc chắn `target/` không được Git track.

Nếu fork ngày càng khác upstream hoặc cần phát hành độc lập, nên chuyển nó sang
một repository fork riêng rồi tham chiếu bằng Git submodule. Với cách vendoring
hiện tại, mọi source cần thiết để build phải được commit trực tiếp trong
NetworkTools.
