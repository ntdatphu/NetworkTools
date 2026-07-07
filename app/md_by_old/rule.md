Bộ Rules tối ưu cho Google Antigravity — bao gồm các quy tắc không tự sửa toàn bộ code
Google Antigravity — Rules tối ưu
Dán vào: Agent Manager → ··· → Customizations → Rules

Bộ Rules
Copy & dán
Workflows
Tips agent

Copy toàn bộ Rules
## BẢO TOÀN CODE — KHÔNG TỰ Ý PHÁ HOẶC VIẾT LẠI (ƯU TIÊN CAO NHẤT)

- Chỉ chạm đúng phần được chỉ định. Khi được yêu cầu sửa hàm X, chỉ sửa đúng hàm X. Tuyệt đối không sửa bất kỳ dòng nào bên ngoài phạm vi, dù thấy chúng "có thể cải thiện".
- Cấm rewrite toàn bộ file khi không có lệnh. Không được viết lại toàn bộ file, class, hoặc module chỉ vì một bug nhỏ hay để "dọn dẹp". Nếu muốn rewrite, phải hỏi và được xác nhận rõ ràng trước.
- Không dập đi xây lại nếu không có chỉ định. Dù code cũ trông lộn xộn hay kiến trúc chưa tối ưu, không xóa và viết lại từ đầu. Sửa tăng dần, giữ nguyên những gì đang hoạt động.
- Luôn dùng diff tối thiểu. Mỗi thay đổi phải là patch nhỏ nhất có thể. Nếu task chỉ cần sửa 3 dòng, output chỉ được có 3 dòng thay đổi.
- Không tự refactor ngoài yêu cầu. Không đổi tên biến, không tách hàm, không thay đổi cấu trúc, không sắp xếp lại import — trừ khi được yêu cầu rõ. Phát hiện vấn đề thì báo cáo qua Artifact, không tự sửa.
- Đề xuất trước, hành động sau. Nếu để sửa đúng cần thay đổi nhiều hơn phạm vi ban đầu, phải dừng lại, tạo Artifact giải thích lý do, chờ xác nhận trước khi tiếp tục.

## Chất lượng code

- Dùng tên biến/hàm mô tả rõ ý định. Thêm type hints (Python) hoặc TypeScript types. Không dùng x, tmp, data2.
- Mỗi hàm public phải có docstring: mục đích, tham số, giá trị trả về.
- Mọi async call, I/O, API request phải có try/catch. Kiểm tra null trước khi dùng.
- Nếu hàm vượt 40 dòng, chỉ tách khi được yêu cầu refactor — không tự tách khi đang sửa bug.

## Bảo mật

- API key, password, token phải dùng biến môi trường. Không bao giờ ghi thẳng vào source code.
- Không cài thêm thư viện hoặc import mới mà không hỏi trước.

## Quy trình agent

- Với task hơn 2 file hoặc hơn 50 dòng thay đổi, tạo Plan Artifact và chờ xác nhận trước khi thực thi.
- Sau khi sửa code, tự chạy test suite hiện có. Không đánh dấu hoàn thành khi test còn fail.
- Sau khi thay đổi UI, dùng browser subagent chụp screenshot và đính kèm vào Artifact.
- Gemini 3.1 Pro cho planning phức tạp. Gemini 3 Flash cho tác vụ lặp lại. Claude Opus 4.6 cho logic phức tạp nhất.
 Vào Antigravity → Agent Manager → ··· → Customizations → Rules → dán vào ô Global Rules


Beta
0 / 0
used queries
1