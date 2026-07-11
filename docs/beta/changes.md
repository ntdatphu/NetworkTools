# Đánh giá thay đổi: `refactor/frontend-beta` so với `frontend-beta`

Ngày đánh giá: 2026-07-12

Nhánh đang đánh giá: `refactor/frontend-beta` tại `f27ad97`

Baseline: `frontend-beta` tại `9e808c4`

Merge base: `9e808c4`

Phương pháp: `git diff frontend-beta...HEAD` (so sánh mọi commit kể từ điểm phân nhánh).
Trạng thái khảo sát code: worktree sạch trước khi bắt đầu cập nhật tài liệu.

## 1. Kết luận điều hành

Nhánh mới là một đợt **refactor UI beta có kiểm soát**, không phải một đợt bổ sung feature mạng hoàn chỉnh. So với `frontend-beta`, nhánh này làm UI đáng tin cậy và dễ kiểm chứng hơn ở bốn điểm chính:

1. Chuẩn hóa một phần nhập liệu network và áp dụng cho các form ACL, DHCP, Interface, NAT và Static Route.
2. Chuyển các màn hình/tabs nặng từ khởi tạo đồng loạt sang **tải ở lần truy cập đầu tiên rồi giữ cache**, nhằm giảm công việc khởi động nhưng vẫn giữ draft chưa lưu.
3. Đưa trạng thái cửa sổ sang `QSettings`, đồng thời sửa hợp đồng tham số giữa QML và NAT stub để tránh lỗi dispatch runtime.
4. Bổ sung smoke test QML, test contract Python/QML, và một bộ tài liệu beta/roadmap chi tiết.

Phạm vi thay đổi gồm **44 file: 2.596 dòng thêm và 189 dòng xoá**. Có 3 commit mới so với baseline:

| Commit | Nội dung |
|---|---|
| `14ffa08` | Tài liệu hóa refactor UI beta |
| `221eee0` | Đồng bộ cách trình bày DHCP với Routing |
| `f27ad97` | Hoàn thiện bộ `docs/beta/` và chuyển tài liệu lịch sử sang `docs/` |

Điểm cần phân biệt: đây là bước nâng nền UI, **không biến ACL/NAT thành backend hoạt động thật**. Các write stub vẫn trả thất bại có kiểm soát; capability-driven UI và persistence thực vẫn là việc tiếp theo.

## 2. Phạm vi và kiểm kê đầy đủ

### 2.1. Code ứng dụng và QML đã sửa/thêm

| Nhóm | File | Thay đổi chính |
|---|---|---|
| Component nền | `app/UI/components/base/BaseButton.qml`, `BaseCard.qml` | Gắn nhãn legacy/deprecation và làm rõ `BaseCard` thực chất là process card của routing, không phải card primitive. |
| Control chuẩn | `app/UI/components/standard/StandardButton.qml`, `StandardTextField.qml` | Thêm tên, role và mô tả accessibility cơ bản. |
| Control mới | `app/UI/components/standard/StandardNetworkField.qml` | Thêm control nhập IPv4/subnet/wildcard, normalize shorthand ở lúc kết thúc chỉnh sửa. |
| Component cần dọn | `app/UI/components/standard/StandardSideBar.qml` | Ghi rõ là duplicate legacy, không thêm consumer mới. |
| Validation | `app/UI/components/utils/ValidationUtils.js` | Thêm `prefixToWildcard()` và parser wildcard `-/prefix`; giữ `/prefix` cho subnet mask. |
| ACL | `app/UI/qml/acl/AclRuleInputStandard.qml`, `AclRuleInputExtended.qml` | Dùng `StandardNetworkField`; wildcard chấp nhận ví dụ `-/24`. |
| DHCP | `app/UI/qml/dhcp/DhcpPoolForm.qml`, `DhcpExcludedForm.qml`, `DhcpHelperForm.qml`, `DhcpView.qml` | Chuẩn hóa field IP/mask; header DHCP đồng nhất hơn; các tab Pool/Excluded/Helper load-on-first-visit. |
| Interface | `app/UI/qml/interface/InterfaceView.qml` | Chuẩn hóa IP, subnet mask và secondary address fields. |
| NAT | `app/UI/qml/nat/NatAclForm.qml`, `NatDynamicForm.qml`, `NatView.qml` | Chuẩn hóa field network/wildcard; sáu tab NAT chuyển sang `Loader` và cache sau lần mở đầu. |
| Routing | `app/UI/qml/routing/RoutingView.qml`, `static/StaticRouteRow.qml`, `eigrp/EigrpNetworksSection.qml`, `ospf/OspfNetworksSection.qml` | Tabs Info/Static/OSPF/EIGRP được lazy-load; Static Route dùng field network chuẩn; các section protocol cập nhật field liên quan. |
| App shell | `app/UI/qml/app/StatefulWindow.qml`, `app/UI/qml/content/ContentArea.qml`, `app/UI/qmldir` | Lưu geometry/maximized state qua backend; lazy-load các feature chính, Settings và Database Browser; export component mới. |
| Backend/runtime | `app/backend.py`, `app/core/database_stubs.py`, `app/core/runtime.py`, `app/main.py` | Expose `WindowSettings`; dùng `QSettings` persistent; mở rộng chữ ký NAT stubs để khớp lời gọi QML và fail có kiểm soát. |
| Kiểm thử mới | `app/tests/qml/NetworkFieldHarness.qml`, `app/tests/test_qml_smoke.py`, `app/tests/test_ui_contracts.py` | Smoke toàn module/view/tabs, test normalize prefix và test persistence/arity contract. |

### 2.2. Tài liệu beta và file kế hoạch mới

Các file dưới đây đều là phần của thay đổi và phải được xem như kế hoạch đi kèm code, không phải tài liệu phụ:

| File | Vai trò |
|---|---|
| `docs/beta/README.md` | Mục lục và quy tắc duy trì bộ tài liệu beta. |
| `docs/beta/change.md` | Báo cáo so sánh Git cập nhật này. |
| `docs/beta/UI_BETA_PLAN.md` | Audit, pattern, capability, backlog, roadmap và quality gate thống nhất. |

Sáu tài liệu lịch sử được **di chuyển nguyên vẹn** từ `app/md_by_old/` sang `docs/md_by_old/`: `project_summary.md`, `rule.md`, `qml/routing/eigrp/EIGRP_QML_ROLES.en.md`, `EIGRP_QML_ROLES.vi.md`, `qml/routing/ospf/OSPF_QML_ROLES.en.md`, và `OSPF_QML_ROLES.vi.md`. Chúng chỉ có giá trị tham khảo lịch sử, không phải source of truth cho UI beta.

## 3. So sánh theo khía cạnh

| Khía cạnh | `frontend-beta` (cũ) | `refactor/frontend-beta` (mới) | Đánh giá |
|---|---|---|---|
| Khởi tạo UI | Nhiều view/tabs được tạo dù đang ẩn. | Feature chính, Routing/DHCP/NAT tabs, Settings và Database Browser dùng `Loader` ở lần ghé thăm đầu tiên. | Giảm chi phí khởi động dự kiến; cần benchmark để định lượng. |
| Trạng thái form | View ẩn đã tồn tại; state được giữ nhưng tốn tài nguyên từ đầu. | Cache sau lần load đầu tiên, nên giữ được state/draft khi đổi tab. | Cân bằng tốt hơn giữa UX và startup; bộ nhớ vẫn tăng khi người dùng đã mở nhiều view. |
| Nhập subnet/wildcard | Nhiều field text tự do; Static Route có parser `/prefix` riêng và hành vi không thống nhất. | `StandardNetworkField` dùng chung; `/24` chuẩn hóa subnet mask, `-/24` chuẩn hóa wildcard. | Giảm trùng lặp, nhưng mới là normalize chứ chưa phải validation đầy đủ. |
| Accessibility | Không có contract accessibility ở standard controls. | `StandardButton` và `StandardTextField` có role/name/description cơ bản. | Tiến bộ nền tảng, chưa đủ keyboard order, focus trap hay i18n. |
| Cửa sổ ứng dụng | `StatefulWindow` giữ state trong process; không khôi phục sau mở lại. | `WindowSettings` lưu/đọc qua `QSettings`. | Sửa đúng kỳ vọng UX; vẫn cần QA đa màn hình/DPI thủ công. |
| NAT QML/backend | Một số lời gọi QML không khớp arity slot Python, có thể lỗi runtime. | Stub signatures khớp lời gọi hiện tại; test contract phát hiện regression. | Fail rõ ràng hơn, nhưng chưa có persistence hay push thực. |
| Độ tin cậy kiểm thử | Không có smoke/contract test cho QML trong baseline. | Có smoke module, feature/tabs, network-field harness và test WindowSettings/NAT arity. | Tăng test seam rõ rệt; chưa có visual regression hay benchmark. |
| Tài liệu vận hành | Tài liệu UI beta phân tán/hạn chế. | Có audit, pattern system, kế hoạch feature, roadmap, backlog và definition of done. | Nâng khả năng ra quyết định; cần kỷ luật cập nhật cùng code. |

## 4. Ưu điểm của nhánh mới

- **Đúng contract hơn:** NAT không còn phụ thuộc vào việc PyQt tự dispatch slot sai số tham số. Việc write vẫn thất bại, nhưng thất bại có chủ đích và có thể test.
- **Nhất quán hơn cho dữ liệu mạng:** một control chuyên dụng thay thế logic `/prefix` cục bộ, đồng thời thêm quy ước rõ cho wildcard `-/prefix`.
- **Khởi động nhẹ hơn theo thiết kế:** lazy-load tránh tạo những feature/tabs chưa được mở, còn cache tránh mất form state khi người dùng quay lại.
- **Trải nghiệm cửa sổ đúng cam kết hơn:** kích thước, vị trí và trạng thái maximized được lưu qua các lần chạy.
- **Dễ bảo trì hơn:** comment phân biệt primitive/component legacy với adapter domain hợp lệ, hạn chế xóa/merge component sai mục đích.
- **Có hàng rào regression mới:** QML được instantiate offscreen; hành vi prefix, WindowSettings và arity NAT đều có test cụ thể.
- **Có định hướng triển khai:** kế hoạch đã mô tả dependency, ownership, capability, acceptance gate và rủi ro trước khi mở rộng thêm feature.

## 5. Nhược điểm và đánh đổi của nhánh mới

| Đánh đổi | Tác động | Cách kiểm soát |
|---|---|---|
| First visit có thể chậm hơn | Lần mở feature/tab đầu tiên mới tạo QML và nạp dữ liệu. | Đo first-open latency và hiển thị loading state nhất quán. |
| Cache làm bộ nhớ tăng dần | Sau khi người dùng đã mở nhiều feature, các view vẫn sống để bảo toàn draft. | Benchmark all-visited session; chỉ unload view khi đã có quy tắc dirty-state an toàn. |
| Lifecycle `Loader` phức tạp hơn | Mã reload/host propagation phải làm việc với `loader.item`; lỗi có thể chỉ lộ khi mở tab muộn. | Giữ smoke test đi qua mọi feature/tab; bổ sung test đổi host và draft. |
| Normalize không thay validation | Chuỗi được chuẩn hóa khi hợp lệ nhưng invalid/cross-field input vẫn có thể xuống backend ở các form chưa migrate validation. | Thực hiện validation matrix và chặn submit trước backend. |
| Tài liệu nhiều hơn | Tài liệu có thể cũ nhanh nếu PR code không cập nhật đồng thời. | Dùng `SCHEMA_for_UI.md`/Definition of Done như quality gate trong mọi PR. |
| Accessibility mới ở mức tối thiểu | Có accessible name/role nhưng chưa bảo đảm điều hướng bàn phím, focus restore hay ngôn ngữ. | Thực hiện P2 keyboard/focus, `qsTr()` và visual/a11y QA. |

## 6. Các hạn chế còn tồn tại ở cả hai nhánh

### Năng lực sản phẩm/backend

- ACL và toàn bộ write path NAT vẫn dựa trên `StubSlotsMixin`; UI không nên thể hiện chúng như tính năng ghi cấu hình end-to-end.
- Interface có local CRUD nhưng chưa chốt owner preview/push riêng.
- BGP, VLAN, VRF, STP, QoS, SNMP, NTP, AAA, MPLS, VPN, Firewall, Monitor và Topology chưa có vertical slice hoàn chỉnh; DHCP/NAT Info cũng chưa hoàn thiện.
- Chưa có Capability API trả read/write level và lý do theo device/feature, vì vậy chưa thể capability-gate nhất quán.

### Điều hướng và dữ liệu

- `FeatureBar` khai báo index 4 là BGP nhưng `ContentArea` diễn giải index 4 là VRF. Đây là lỗi source-of-truth/navigation còn tồn tại, không thuộc phần đã sửa.
- Chưa có feature registry stable ID; các mapping song song vẫn có nguy cơ lệch khi thêm feature.
- Reference integrity/stable ID giữa Interface, VLAN, VRF, ACL/route-map và NAT chưa được chốt.

### Chất lượng UI

- Các collection lớn ở Static Route, OSPF/EIGRP và Routing Info vẫn cần benchmark/virtualization có chọn lọc.
- Responsive layout, DPI, high contrast, keyboard order, focus restoration, localization và loading/error/unsupported state chưa có contract hoàn chỉnh.
- Một số component còn rỗng/chưa có owner (`SectionCard`, `StandardValidationDialog`) hoặc cần migration có thời hạn (`StandardSideBar`, `BaseCard`).

### Chất lượng kiểm chứng

- Chưa có performance baseline, visual snapshot hoặc QML lint trong CI.
- `git diff --check frontend-beta...HEAD` báo trailing whitespace trong các tài liệu beta cũ (`CONTINUATION_ROADMAP.md`, `FEATURE_UI_DESIGN_PLAN.md`, `UI_AUDIT_REPORT.md`, `UI_PATTERN_SYSTEM.md`, `changes.md`). Đây là nợ format nhỏ, không phải lỗi logic.
- Trong môi trường đánh giá hiện tại, `python` không có trên `PATH`; runtime Python đi kèm thiếu `requests`, `jinja2` và `PyQt6`, nên test suite không thể thực thi tại đây. Đây là giới hạn môi trường kiểm tra, không thể dùng để khẳng định test pass/fail của nhánh.

## 7. Kế hoạch tiếp theo được đề xuất

Ưu tiên theo rủi ro, dependency và khả năng tạo vertical slice thật; không theo số lượng màn hình.

### Phase A — Sửa sự thật hệ thống (P0)

1. Thay mapping FeatureBar/ContentArea bằng **Feature Registry có stable ID**; chốt ownership BGP và VRF.
2. Lập backend inventory cho mọi feature: owner, storage, read/local/preview/push, test và thiết bị/vendor áp dụng.
3. Thiết kế Capability API (`none`, `read-only`, `local-only`, `preview`, `push`) kèm reason; đưa banner/gating vào ACL, NAT và Interface.
4. Hoàn thiện validation submit cho IPv4, subnet, wildcard, port, range và cross-field; invalid input không được gọi backend.

**Gate:** BGP/VRF không còn index lệch; không form nào hứa write/push ngoài capability thật; có test registry và capability cho router/switch/unknown device.

### Phase B — Củng cố foundation và đo lường (P1)

1. Tạo `FeaturePageShell` và contract chung cho loading/empty/error/unsupported/stale/dirty/saving/pushing.
2. Bổ sung dirty guard khi đổi host/tab/đóng cửa sổ và task feedback cho Preview/Push.
3. Đo startup, first-open, repeat-open, RSS, QML object count và scroll 100/1.000 rows trước/sau lazy-load.
4. Bổ sung QML lint, visual snapshot light/dark/high-contrast, keyboard/focus test, và QA 900x600 ở 100/150/200% DPI.
5. Dọn component rỗng/legacy theo migration plan; không tạo universal table khi chưa có consumer thật.

**Gate:** smoke và unit test pass trong environment có dependencies dự án; có benchmark baseline; DHCP và Routing Info chạy qua shared shell/state contract.

### Phase C — Pilot theo họ giao diện (P1)

1. **Entity Workspace:** DHCP Pool, Excluded, Helper; sau đó Interface list/detail responsive.
2. **Process Workspace:** OSPF và EIGRP với process context, section navigation và collection table/drawer.
3. **Policy Workspace:** ACL Standard/Extended, chỉ sau khi local CRUD/backend milestone và capability gate sẵn sàng.

**Gate:** draft/selection không mất khi đổi tab/host; collection lớn không render hàng loạt editor; Preview hiển thị add/change/delete rõ ràng; test valid/invalid/failure path có mặt.

### Phase D — Hoàn thiện feature end-to-end (P1/P2)

1. ACL Standard/Extended: persistence, binding, validation, preview/push; Dynamic/Reflexive/MAC chỉ mở theo capability.
2. NAT: chốt ownership ACL/route-map, rồi thực hiện Static -> Interfaces -> Dynamic/PAT -> shared policy -> Info/telemetry.
3. Interface: chốt owner save/push và reference integrity cho VRF/QoS/IPsec.
4. Sau nền tảng trên, triển khai VLAN -> VRF -> STP -> BGP IPv4 unicast theo dependency.

**Gate:** mỗi feature có ít nhất mức capability/read/local/preview được công bố chính xác; push chỉ enable khi controller thật; tất cả failure path đều có test.

## 8. Tiêu chí bàn giao cho đợt kế tiếp

- Mọi thay đổi code cập nhật đúng tài liệu liên quan trong `docs/beta/` và trạng thái item trong `SCHEMA_for_UI.md`.
- Không có mapping feature bằng index song song cho logic nghiệp vụ.
- Không có write action được enable nếu backend chỉ là stub.
- Test suite được chạy trong môi trường có đúng dependencies dự án; kết quả, môi trường và benchmark được ghi vào nhật ký kiểm chứng.
- Không phát sinh trailing whitespace trong tài liệu mới; xử lý nợ format hiện có trong một commit nhỏ riêng để tránh lẫn với refactor chức năng.

## 9. Nhận định cuối

`refactor/frontend-beta` tốt hơn `frontend-beta` về **an toàn contract, tính nhất quán nhập liệu, lifecycle UI, khả năng kiểm thử và định hướng thực hiện**. Đổi lại, nó thêm lifecycle cache/lazy-load cần được đo đạc và tăng yêu cầu duy trì tài liệu. Giá trị lớn nhất của nhánh mới là biến các rủi ro trước đây thành backlog có bằng chứng và quality gate rõ ràng; giá trị đó chỉ được bảo toàn nếu Phase A hoàn tất trước khi tiếp tục mở rộng số lượng feature.
