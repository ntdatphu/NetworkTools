# SpinBox inventory and domain contract

## Shared interaction contract

`StandardSpinBox` keeps Qt's integer `SpinBox` as the value/keyboard/wheel
owner. The two stacked indicators on the right have explicit mouse hit targets
that call `increase()` and `decrease()` exactly once. Each target disables at
its corresponding bound, so a click cannot wrap or pass `from`/`to`.

This is covered by an offscreen QML pointer test. The test clicks the rendered
upper and lower indicator, checks the configured step, and checks clamping at
both ends. A static contract also verifies that every current consumer declares
its domain rather than inheriting Qt's generic `0..99`, step `1` defaults.

## Consumer matrix

| Consumer | Unit | Min | Max | Default | Step | Rationale |
|---|---:|---:|---:|---:|---:|---|
| Syslog listener port | TCP/UDP port | 1 | 65535 | 5514 | 1 | Full valid port range; precise selection is required. |
| Syslog retention | days | 1 | 3650 | 30 | 1 | Product storage cap of ten years; daily precision. |
| SFTP quick-connect port | TCP port | 1 | 65535 | 22 | 1 | Full valid port range; standard SFTP default. |
| SFTP saved-profile port | TCP port | 1 | 65535 | 22 | 1 | Same contract as quick connect. |
| RAM warning threshold | percent | 1 | 100 | 85 | 5 | A warning threshold is tuned coarsely; typed input can still set any in-range integer. |
| NAT route-map sequence | ordering key | 1 | 65535 | 10 | 10 | Project schema requires `sequence > 0`; Cisco-style sequences conventionally start at 10. |
| Dynamic ACL timeout | minutes | 1 | 9999 | 5 | Cisco dynamic ACL syntax uses minutes. UI minutes are persisted in the shared seconds column. |
| Reflexive ACL timeout | seconds | 30 | 2147483 | 300 | Cisco documents 300 seconds as the default and 30 as the lower bound. |

NAT route-map documentation differs by Cisco platform: some current platforms
allow sequence `0`, while this project's existing SQLite CHECK constraint is
`sequence > 0`. UI-05 deliberately preserves the database contract instead of
silently requiring a destructive table migration. Backend validation now
rejects values outside `1..65535`.

## Persistence normalization

- Dynamic ACL displays minutes because the Cisco `dynamic ... timeout` syntax
  uses minutes. `buildRule()` multiplies by 60 for the existing
  `timeout_seconds` persistence field.
- Reflexive ACL displays and stores seconds. The default is explicit (`300`)
  rather than using a visually ambiguous zero.
- Backend ACL validation accepts only `60..599940` stored seconds for dynamic
  rules and `30..2147483` seconds for reflexive rules.
- Route-map sequence validation occurs before opening a write transaction.

## References

- [Qt SpinBox](https://doc.qt.io/qt-6/qml-qtquick-controls-spinbox.html)
- [Qt Quick Controls: Customizing SpinBox](https://doc.qt.io/qt-6/qtquickcontrols-customize.html#customizing-spinbox)
- [Cisco dynamic ACL command reference](https://www.cisco.com/E-Learning/bulk/public/tac/cim/cib/using_cisco_ios_software/cmdrefs/dynamic.htm)
- [Cisco lock-and-key dynamic ACL configuration](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/sec_data_acl/configuration/12-2sx/sec-data-acl-12-2sx-book/sec-lock-key-secrty.html)
- [Cisco reflexive ACL configuration](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-15/configuration_guide/sec/b_1715_sec_9300_cg/configuring_ip_session_filtering_reflexive_access_lists.pdf)
- [Cisco IOS XE NAT route-map example and range](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9600/software/release/17-14/configuration_guide/ip/b_1714_ip_9600_cg.pdf)
