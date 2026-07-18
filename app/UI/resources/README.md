# UI resources

SVG active được chia theo ý nghĩa trong `actions/`, `devices/`, `files/`, `navigation/` và `status/`. QML chỉ tham chiếu asset qua các property ngữ nghĩa trong `../qml/shared/AppAssets.qml`; không ghi literal SVG path ở consumer.

`_unused/` là khu vực cách ly để duyệt xóa, không phải nguồn asset runtime. Inventory và quy tắc bảo trì đầy đủ ở `docs/resources/SVG_RESOURCES.md`.

