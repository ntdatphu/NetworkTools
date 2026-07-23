# Network field focus and caret lifecycle

## Symptom

After entering subnet shorthand such as `/24` and clicking another field, the
old field could retain a blinking caret. More focus transfers could leave
multiple visual carets even though only one input actually received keyboard
events. Wildcard shorthand follows the same path and had the same risk.

## Cause and lifecycle

Subnet and wildcard inputs both inherit `StandardNetworkField`. The component
previously normalized shorthand only from `editingFinished`. Qt emits that
signal as part of focus-out handling, while Qt also owns and updates the
underlying `TextInput.cursorVisible` property.

The Qt contract explicitly says that `cursorVisible` is changed automatically
with active focus and that direct values can be overwritten. Qt's focus-out
source sets the cursor state and then emits `editingFinished`; the previous
normalization therefore replaced text from inside that same transaction. The
reported Windows symptom is consistent with a late cursor-state update after
focus has already moved, so the fix guards the observable focus invariant
instead of depending on one renderer's event order.

References:

- [Qt TextInput documentation](https://doc.qt.io/qt-6/qml-qtquick-textinput.html)
- [Qt TextInput focus/cursor source](https://github.com/qt/qtdeclarative/blob/dev/src/quick/items/qquicktextinput.cpp)

## Fix contract

- `StandardNetworkField` treats `inputActiveFocus` changing to false as the
  authoritative pointer focus-transfer boundary and normalizes immediately.
- `editingFinished` remains supported for Enter/Return commits.
- `StandardTextField` schedules an inactive-cursor cleanup with `Qt.callLater`.
  The deferred check runs after Qt's own focus bookkeeping and only writes
  `cursorVisible=false` when the input is still inactive.
- The newly focused input is never modified by the cleanup.

## Regression coverage

`NetworkFieldFocusHarness.qml` and
`test_network_shorthand_normalizes_on_focus_transfer_without_ghost_caret`
exercise real mouse and keyboard events. The test verifies:

- `/24` becomes `255.255.255.0` on the first focus transfer;
- `-/24` becomes `0.0.0.255` on the first focus transfer;
- exactly one cursor is visible;
- an emulated late cursor write on an inactive field is removed without
  hiding the active field's cursor.
