# Infrastructure

Adapter kỹ thuật dùng chung cho SQLite, kết nối thiết bị, hệ điều hành và package
workspace. **implemented** theo bốn namespace: `database/` sở hữu path/schema/
connection; `network/` sở hữu connector, registry, runner và batch; `system/` sở
hữu desktop/network/resource/virtual-lab probe; `workspace/` sở hữu `.ntp`, crypto,
staging, save và snapshot. Lớp này không chứa validation/use case nghiệp vụ và
không import QML.
