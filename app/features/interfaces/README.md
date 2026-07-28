# Interfaces

Router interface persistence và workspace. **partial**: `repository.py` sở hữu API load/save/edit/delete `t02_*`; `core/interface_slots.py` giữ contract QML. Shim `features/dhcp/interfaces.py` chỉ còn để tương thích import cũ.

UI được tách theo trách nhiệm:

- `InterfaceView.qml`: điều phối host, model, selection, context menu và shortcut.
- `InterfaceEditorPane.qml`: form L3/WAN/Tunnel và tạo payload.
- `InterfaceSavedPanel.qml`: danh sách, badge và row action.

Header có View & Push nhưng hiện hiển thị `Coming soon`. Worker backend được khảo sát mới render/push các trường interface cơ bản, chưa xử lý đầy đủ secondary IP, L3 tuning, WAN và Tunnel nên app chủ động không gửi cấu hình thiếu xuống thiết bị.

Test chính: `test_switching_workspace.py`, `test_dhcp_acl_persistence.py`, QML smoke. Backlog: hoàn thiện collector/template/worker interface cho toàn bộ bảng con rồi bật preview/push thật.
