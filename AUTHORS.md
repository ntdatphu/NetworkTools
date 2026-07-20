# Tác giả & Thành viên Nghiên cứu

Dự án nghiên cứu khoa học này được thực hiện bởi nhóm sinh viên Khoa Viễn thông 2, Học viện Công nghệ Bưu chính Viễn thông cơ sở tại Thành phố Hồ Chí Minh (PTIT), dưới sự hướng dẫn khoa học của giảng viên Bộ môn Mạng Viễn thông.


## Danh sách thành viên thực hiện

### 1. Nguyễn Quốc Việt — Trưởng nhóm, Kiến trúc dữ liệu & Tích hợp hệ thống

**Vai trò chính:** Định hướng kiến trúc dữ liệu và tổ chức tích hợp các thành phần của ứng dụng.

**Phạm vi trách nhiệm:**

- Thiết kế, chuẩn hóa và quản trị hệ thống cơ sở dữ liệu SQLite; xây dựng lược đồ, quy trình khởi tạo và tái cấu trúc dữ liệu cho thiết bị, interface, định tuyến, DHCP, ACL, NAT, Layer 2 và dữ liệu giám sát.
- Phát triển lớp liên kết giữa cơ sở dữ liệu, giao diện và các mô-đun xử lý mạng; tích hợp Python application kernel/network code vào ứng dụng và hoàn thiện luồng lấy Running Configuration, lưu dữ liệu và đẩy cấu hình lên thiết bị.
- Phát triển và tích hợp cơ chế đẩy cấu hình cho các nhóm chức năng Routing, DHCP và NAT; phối hợp xử lý các hợp đồng dữ liệu giữa UI và backend.
- Xây dựng mô-đun Syslog từ khâu thu nhận, phân tích, lưu trữ, quản lý vòng đời bản ghi đến cấu hình thiết bị và kiểm thử; phối hợp hoàn thiện, tích hợp mô-đun SFTP vào kiến trúc chung của ứng dụng.
- Điều phối kỹ thuật, rà soát việc hợp nhất mã nguồn và bảo đảm các thành phần dữ liệu, backend và giao diện hoạt động thống nhất.

- Email trường học: n24dcvt113@student.ptithcm.edu.vn
- Email liên hệ: quocviet15t12@gmail.com
- GitHub: [@viet15t12](https://github.com/viet15t12)

### 2. Nguyễn Phan Kiên — Thành viên nghiên cứu, Backend & Tự động hóa cấu hình

**Vai trò chính:** Phát triển nền tảng backend xử lý cấu hình, đồng bộ trạng thái thiết bị và tự động hóa cấu hình Cisco.

**Phạm vi trách nhiệm:**

- Xây dựng nền mã nguồn backend ban đầu và tổ chức các mô-đun xử lý kết nối, interface, định tuyến, dịch vụ mạng, bảo mật và chuyển mạch Layer 2.
- Phát triển, tái cấu trúc API, worker và logic nghiệp vụ cho Static Routing, OSPF, EIGRP, DHCP, ACL, NAT/Route Map, VLAN và interface Layer 2.
- Thiết kế và hoàn thiện các mẫu cấu hình Jinja cho thiết bị Cisco; xây dựng cơ chế sinh, kiểm tra và đẩy cấu hình lên thiết bị.
- Xây dựng cơ chế đọc Running Configuration, phân tích trạng thái thực tế và đồng bộ về cơ sở dữ liệu cho Routing, DHCP, ACL, NAT, VLAN và interface Layer 2.
- Kiểm thử tích hợp trên thiết bị/môi trường mô phỏng, xác minh kết quả cấu hình và xử lý lỗi phát sinh trong các luồng API, đồng bộ và đẩy cấu hình.

- Email trường học: n24dcvt046@student.ptithcm.edu.vn
- Email liên hệ: nguyenphankien863@gmail.com
- GitHub: [@Cherster0606](https://github.com/Cherster0606)

### 3. Nguyễn Trần Đạt Phú — Thành viên nghiên cứu, UI/UX & Tích hợp dự án

**Vai trò chính:** Thiết kế kiến trúc giao diện, tối ưu trải nghiệm người dùng, biên soạn tài liệu và quản lý tích hợp mã nguồn.

**Phạm vi trách nhiệm:**

- Thiết kế và phát triển giao diện PyQt6/QML; xây dựng hệ thống component dùng chung, bố cục, theme, màu sắc, biểu tượng và các mẫu tương tác nhất quán cho toàn ứng dụng.
- Thiết kế trải nghiệm cho quản lý thiết bị và các màn hình Routing, DHCP, ACL, NAT, Switching, Syslog, SFTP, Settings, External Tools, thông báo và trạng thái hệ thống.
- Tối ưu khả năng sử dụng và phản hồi của ứng dụng, gồm điều hướng, biểu mẫu nhập liệu, bảng dữ liệu, tiến trình tác vụ, thông báo lỗi, kết nối lại thiết bị và các luồng thao tác không chặn giao diện.
- Biên soạn, chuẩn hóa và duy trì README, tài liệu kiến trúc, tài liệu UI/UX, kịch bản nghiên cứu, tiêu chí đánh giá và báo cáo dự án.
- Quản lý tiến độ, cấu trúc kho mã và quy trình tích hợp nhánh trên GitHub; thực hiện di chuyển mã nguồn từ kho cũ, giải quyết xung đột và hợp nhất các mô-đun vào ứng dụng hiện tại.

- Email trường học: n24dcvt072@student.ptithcm.edu.vn
- Email liên hệ: nt.datphu@gmail.com
- GitHub: [@ntdatphu](https://github.com/ntdatphu)


## Giảng viên hướng dẫn

**ThS. Phan Thanh Toản**  
Bộ môn Mạng Viễn thông, Học viện Công nghệ Bưu chính Viễn thông cơ sở tại TP. Hồ Chí Minh

- **Hướng nghiên cứu:** Mạng máy tính, Mạng viễn thông, Định tuyến (Routing) và Chuyển mạch (Switching), Công nghệ mạng băng rộng, An ninh mạng, Ảo hóa và Điện toán đám mây (Cloud Computing).
- **Học phần giảng dạy:** Cơ sở kỹ thuật mạng truyền thông, Mạng máy tính, Internet và các giao thức.
- **Email:** phanthanhtoan@ptithcm.edu.vn
