# UI resources

SVG active được chia theo ý nghĩa trong `actions/`, `devices/`, `files/`, `navigation/` và `status/`. QML chỉ tham chiếu asset qua các property ngữ nghĩa trong `../qml/shared/AppAssets.qml`; không ghi literal SVG path ở consumer.

Asset không có runtime consumer phải được xóa thay vì lưu trong cây nguồn. Các icon file/folder của SFTP dùng Material Icon Theme; bản quyền bên thứ ba được giữ trong `licenses/`.
