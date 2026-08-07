#import "../config/commands.typ": front-heading, todo

#front-heading[ABSTRACT]

This project develops *NetworkTools*, a desktop application for centralized management and partial automation of Cisco IOS network-device configuration in learning and laboratory environments. The application combines a Qt Quick/QML user interface, a PyQt6 bridge, SQLite persistence, and Python workers for collecting device state, generating candidate configuration, previewing changes, and pushing configuration to devices.

The current scope covers device management, partial connection and synchronization workflows, DHCP, static routing, OSPF, EIGRP, ACL persistence, NAT/PAT, and supporting utilities. Some modules provide user interfaces and persistence but do not yet have a complete end-to-end View & Push workflow. At the review point reflected in the project outline, 30 automated tests were discovered: 28 functional tests passed, while two OSPF/EIGRP database-contract tests failed because of schema naming mismatches.

The report presents the theoretical background, system architecture, data design, implementation, testing methodology, current limitations, and prioritized development roadmap. Results are explicitly separated into implemented features, existing foundations, and future work.

#todo[Update final test counts, laboratory evidence, and performance measurements before submission.]
