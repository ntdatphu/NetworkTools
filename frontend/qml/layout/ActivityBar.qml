pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import NetworkUI

Rectangle {
    id: activityBar
    color: Theme.activityBarBackground

    property int activeIndex: 0
    property string appMode: "devices"
    
    property bool isPythonCheckRunning: false
    signal retryPythonCheckClicked()

    // ── Icons Khối Trên (Điều hướng chính) ──
    Column {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        ActivityBarItem {
            iconSource: "qrc:/qt/qml/NetworkUI/resources/activitybar/dashboard.svg"
            tooltipText: "Dashboard"
            isActive: activityBar.activeIndex === 0
            onClicked: {
                activityBar.activeIndex = 0
                activityBar.appMode = "devices"
            }
        }

        ActivityBarItem {
            iconSource: "qrc:/qt/qml/NetworkUI/resources/activitybar/devices.svg"
            tooltipText: "Devices (Coming soon)"
            isActive: false
            opacity: 0.5
        }

        ActivityBarItem {
            iconSource: "qrc:/qt/qml/NetworkUI/resources/activitybar/topology.svg"
            tooltipText: "Topology (Coming soon)"
            isActive: false
            opacity: 0.5
        }
    }

    // ── Icons Khối Dưới (Hệ thống & Cài đặt) ──
    Column {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter

        ActivityBarItem {
            iconSource: "qrc:/qt/qml/NetworkUI/resources/activitybar/logs-alerts.svg"
            tooltipText: "Logs & Alerts"
            isActive: activityBar.activeIndex === 3
            onClicked: {
                activityBar.activeIndex = 3
                activityBar.appMode = "logs"
            }
        }

        // Nút thực thi lệnh (Action)
        ActivityBarItem {
            iconSource: "qrc:/qt/qml/NetworkUI/resources/activitybar/python.svg"
            tooltipText: activityBar.isPythonCheckRunning ? "Python Check Running..." : "Retry Python Check"
            opacity: activityBar.isPythonCheckRunning ? 0.5 : 1.0
            enabled: !activityBar.isPythonCheckRunning
            isActive: false
            
            Behavior on opacity { 
                NumberAnimation { duration: Theme.animationDurationFast } 
            }
            
            onClicked: {
                activityBar.retryPythonCheckClicked()
            }
        }

        ActivityBarItem {
            iconSource: "qrc:/qt/qml/NetworkUI/resources/activitybar/settings.svg"
            tooltipText: "Settings"
            isActive: activityBar.activeIndex === 4
            onClicked: {
                activityBar.activeIndex = 4
                activityBar.appMode = "settings"
            }
        }
    }

    // Đường viền ngăn cách không gian layout
    Rectangle {
        anchors.right: parent.right
        width: Theme.borderWidth
        height: parent.height
        color: Theme.borderColor
    }
}