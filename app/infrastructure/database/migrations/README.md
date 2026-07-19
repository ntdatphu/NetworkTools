# Database migrations

Đặt migration có version tại đây khi schema cần nâng cấp dữ liệu runtime. Migration phải idempotent hoặc có bảng version, backup trước thay đổi phá vỡ và có test upgrade/rollback. Việc di chuyển schema trong đợt này không thay đổi schema nên chưa có migration SQL.
