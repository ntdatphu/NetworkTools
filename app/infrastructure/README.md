# Infrastructure

Adapter kỹ thuật dùng chung cho SQLite, kết nối thiết bị và probe hệ điều hành. `network/` sở hữu connector, registry duy nhất và ping; `system/` sở hữu process launcher, RAM và thông tin interface/SSID. Lớp này không chứa validation/use case nghiệp vụ và không import QML.
