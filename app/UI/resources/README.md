# UI resources

SVG active được chia theo ý nghĩa trong `actions/`, `devices/`, `files/`, `navigation/` và `status/`. QML chỉ tham chiếu asset qua các property ngữ nghĩa trong `../qml/shared/AppAssets.qml`; không ghi literal SVG path ở consumer.

`_unused/` là khu vực cách ly để duyệt xóa, không phải nguồn asset runtime. Inventory và quy tắc bảo trì đầy đủ ở `docs/resources/SVG_RESOURCES.md`.

Các icon file/folder của SFTP dùng Material Icon Theme; nguồn, phiên bản và 54 luật loại file được ghi tại `docs/resources/SFTP_FILE_TYPE_ICONS.md`. Bản quyền bên thứ ba được giữ trong `licenses/`.
