# NetworkTools Documentation

Tài liệu trong thư mục này được chuẩn hóa theo source hiện tại trên nhánh `main`.

## Tài liệu chính

| File | Nội dung |
|---|---|
| [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) | Tổng quan hệ thống, kiến trúc, module chính |
| [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) | Cấu trúc repository và path nhạy cảm |
| [GENERATED_FILES.md](GENERATED_FILES.md) | File/thư mục sinh ra khi build/runtime |
| [ROUTING_BACKEND_PLAN_VI.md](ROUTING_BACKEND_PLAN_VI.md) | Kế hoạch triển khai routing |

## Phân tích kỹ thuật

| File | Nội dung |
|---|---|
| [analysis/QML_ANALYSIS.md](analysis/QML_ANALYSIS.md) | Cấu trúc QML, component, theme, module UI |
| [analysis/DATA_SQL_ANALYSIS.md](analysis/DATA_SQL_ANALYSIS.md) | Phân tích schema SQLite |

## Tài liệu nghiên cứu khoa học

| File | Nội dung |
|---|---|
| [research/RESEARCH_SCOPE.md](research/RESEARCH_SCOPE.md) | Phạm vi đề tài nghiên cứu |
| [research/TEST_SCENARIOS.md](research/TEST_SCENARIOS.md) | Kịch bản kiểm thử đề xuất |
| [research/EVALUATION_CRITERIA.md](research/EVALUATION_CRITERIA.md) | Tiêu chí đánh giá kết quả |

## Quy tắc cập nhật tài liệu

- Ưu tiên đối chiếu với source thật trong `frontend/`, `python app kenel/` và `frontend/CMakeLists.txt`.
- Không dùng lại mô tả cũ về `NetworkUI/`, `data.sql`, `script/database/init_db.py` nếu source không còn dùng.
- Khi đổi build/runtime path, cập nhật đồng thời `README.md`, `docs/PROJECT_STRUCTURE.md` và `docs/GENERATED_FILES.md`.
- Khi đổi schema SQL, cập nhật `docs/analysis/DATA_SQL_ANALYSIS.md`.
- Khi đổi QML module/component, cập nhật `docs/analysis/QML_ANALYSIS.md`.
