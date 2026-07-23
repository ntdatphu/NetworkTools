# Context menu and shortcut inventory

## Nguyên tắc chọn bề mặt

Menu chuột phải chỉ được thêm khi đối tượng có từ hai thao tác theo ngữ cảnh
trở lên. Mọi lệnh trong menu phải gọi đúng cùng function với nút/shortcut đang
hiển thị; không tạo lệnh giả hoặc một đường xử lý nghiệp vụ thứ hai.

Các collection command dùng quy ước Windows/Explorer: `F2` Rename/Edit,
`Delete` xóa, `F5` refresh, `Shift+F10` mở menu của selection. Các lệnh quản lý
tab dùng quy ước VS Code: `Ctrl+W`/`Ctrl+F4` đóng, `Ctrl+Shift+T` mở lại tab vừa
đóng và `Ctrl+K Ctrl+W` đóng tất cả.

## Bề mặt đã có hoặc đã bổ sung

| Bề mặt | Menu | Pointer/keyboard |
|---|---|---|
| SFTP file rows | Open/Transfer, Rename, Delete, New folder, Select all, Refresh | Right-click, Shift+F10, Enter, F2, Delete, Ctrl+Shift+N, Ctrl+A, F5 |
| Device tabs | Close, Close Others, Close to the Right, Close All, Reopen Closed, New Device | Right-click, Shift+F10, Ctrl+W, Ctrl+F4, Ctrl+K Ctrl+W, Ctrl+Shift+T, Ctrl+T |
| Open Editors | Activate editor, Close, Close All | Click, icon actions; dùng chung Ctrl+W và Ctrl+K Ctrl+W của DeviceTabs |
| Interface saved rows | Edit, Delete, Refresh | Right-click, Shift+F10, F2, Delete, F5 |
| Device sidebar | Edit, status actions, CLI, Delete | Existing right-click menu and contextual shortcuts |
| Syslog device list | Existing source actions | Existing right-click menu |
| Config text viewer | Copy, Find | Existing right-click menu and Ctrl+C/Ctrl+F |
| Application command reference | Keyboard Shortcuts | Ctrl+/ |

## Bề mặt không gắn menu

- ActivityBar và FeatureBar là điều hướng toàn cục, không phải collection item;
  thêm menu trùng click chính sẽ làm tăng nhiễu mà không thêm command.
- Form input tiếp tục dùng native text editing behavior của control; shortcut
  collection bị tắt khi focus đang ở `TextInput`/`TextEdit`.
- Panel hoặc workspace đang ẩn không được giữ shortcut enabled; mỗi sequence
  chỉ có một owner trong ngữ cảnh đang active.
- Các saved table chỉ có một thao tác hoặc có nghiệp vụ riêng chưa đủ contract
  chung được giữ nguyên; không áp một menu generic có thể xóa sai domain.

## Nguồn đối chiếu

- [Windows contextual commanding](https://learn.microsoft.com/en-us/windows/apps/develop/ui/controls/collection-commanding)
- [Windows keyboard UI guidelines](https://learn.microsoft.com/en-us/previous-versions/windows/desktop/dnacc/guidelines-for-keyboard-user-interface-design)
- [VS Code default keyboard shortcuts](https://code.visualstudio.com/docs/reference/default-keybindings)
- [VS Code tabs](https://code.visualstudio.com/docs/editing/userinterface#_tabs)
