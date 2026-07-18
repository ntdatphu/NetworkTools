import QtQuick
import UI

Item {
    width: 1000
    height: 400

    ListModel {
        id: rows
        ListElement {
            idValue: 1
            device_host: "192.0.2.1"
            source_ip: "192.0.2.1"
            received_at: "2026-07-18T10:00:00"
            facility: "SYS"
            severity: 5
            mnemonic: "CONFIG_I"
            message: "Configured"
        }
    }

    SyslogLogTable {
        anchors.fill: parent
        model: rows
    }
}
