pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import UI

Item {
    id: root
    objectName: "openEditorsSection"

    property var editors: []
    property string activeUid: ""
    property bool expanded: true

    readonly property int editorCount: editors ? editors.length : 0
    readonly property int visibleEditorCount: Math.min(editorCount, Theme.openEditorsMaxCount)
    readonly property int headerHeight: Theme.listItemHeight

    signal editorSelected(string uid)
    signal editorCloseRequested(string uid)
    signal closeAllRequested()

    implicitHeight: headerHeight
                    + (expanded ? visibleEditorCount * Theme.listItemHeight : 0)
    clip: true

    function activeEditorIndex() {
        for (let i = 0; i < editorCount; i++) {
            if (String(editors[i].uid || "") === activeUid)
                return i
        }
        return -1
    }

    function revealActiveEditor() {
        const index = activeEditorIndex()
        editorList.currentIndex = index
        if (index >= 0)
            editorList.positionViewAtIndex(index, ListView.Contain)
    }

    function deviceIcon(deviceType) {
        const type = String(deviceType || "").toLowerCase()
        if (type === "router")
            return AppAssets.deviceRouter
        if (type === "switch")
            return AppAssets.deviceSwitch
        return AppAssets.navigationDashboard
    }

    function statusColor(status) {
        const value = String(status || "").toLowerCase()
        if (value === "connected")
            return Theme.statusConnected
        if (value === "waiting")
            return Theme.statusWaiting
        return Theme.statusDisconnected
    }

    Rectangle {
        id: sectionHeader
        objectName: "openEditorsHeader"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.headerHeight
        color: Theme.panelSideBarBackground

        Item {
            id: headerToggle
            anchors.left: parent.left
            anchors.right: closeAllButton.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            ThemedIcon {
                id: expansionIcon
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacing8
                anchors.verticalCenter: parent.verticalCenter
                iconSource: root.expanded
                            ? AppAssets.navigationChevronDown
                            : AppAssets.navigationChevronRight
                iconSize: Theme.iconSizeSmall
                iconColor: Theme.panelSideBarTextSecondary
            }

            Text {
                anchors.left: expansionIcon.right
                anchors.leftMargin: Theme.spacing4
                anchors.right: editorCountBadge.left
                anchors.rightMargin: Theme.spacing8
                anchors.verticalCenter: parent.verticalCenter
                text: "OPEN EDITORS"
                elide: Text.ElideRight
                color: Theme.panelSideBarTextPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.capitalization: Font.AllUppercase
                font.weight: Font.DemiBold
            }

            StandardBadge {
                id: editorCountBadge
                objectName: "openEditorsCountBadge"
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacing4
                anchors.verticalCenter: parent.verticalCenter
                text: String(root.editorCount)
                badgeColor: Theme.accentEmphasis
            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: root.expanded = !root.expanded
            }
        }

        IconButton {
            id: closeAllButton
            objectName: "openEditorsCloseAllButton"
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacing8
            anchors.verticalCenter: parent.verticalCenter
            buttonSize: Theme.sideBarFeatureIcon
            iconSize: Theme.iconSizeSmall
            iconSource: AppAssets.actionClose
            idleColor: Theme.panelSideBarTextSecondary
            activeColor: Theme.panelSideBarTextPrimary
            selectedBackground: Theme.panelSideBarItemSelected
            hoverBackground: Theme.panelSideBarItemHover
            tooltip: "Close All Editors (Ctrl+K Ctrl+W)"
            enabled: root.editorCount > 0
            onClicked: root.closeAllRequested()
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Theme.borderWidth
            color: Theme.panelSideBarBorderColor
        }
    }

    ListView {
        id: editorList
        objectName: "openEditorsList"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: sectionHeader.bottom
        anchors.bottom: parent.bottom
        visible: root.expanded
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.editors
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        delegate: Item {
            id: editorRow
            required property int index
            required property var modelData

            readonly property string editorUid: String(modelData.uid || "")
            readonly property bool activeEditor: root.activeUid === editorUid
            readonly property bool hovered: rowHover.hovered

            objectName: "openEditorRow" + index
            width: ListView.view.width
            height: Theme.listItemHeight

            Rectangle {
                anchors.fill: parent
                color: editorRow.activeEditor
                       ? Theme.panelSideBarItemSelected
                       : (editorRow.hovered ? Theme.panelSideBarItemHover : "transparent")
            }

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 2
                color: Theme.accentEmphasis
                visible: editorRow.activeEditor
            }

            ThemedIcon {
                id: deviceTypeIcon
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacing12
                anchors.verticalCenter: parent.verticalCenter
                iconSource: root.deviceIcon(editorRow.modelData.deviceType)
                iconSize: Theme.iconSizeSmall
                iconColor: root.statusColor(editorRow.modelData.status)
            }

            Text {
                anchors.left: deviceTypeIcon.right
                anchors.leftMargin: Theme.spacing8
                anchors.right: closeEditorButton.left
                anchors.rightMargin: Theme.spacing4
                anchors.verticalCenter: parent.verticalCenter
                text: String(editorRow.modelData.title || editorRow.editorUid)
                elide: Text.ElideRight
                color: editorRow.activeEditor
                       ? Theme.panelSideBarTextPrimary
                       : Theme.panelSideBarTextSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeNormal
            }

            CloseButton {
                id: closeEditorButton
                objectName: "openEditorCloseButton" + editorRow.index
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacing4
                anchors.verticalCenter: parent.verticalCenter
                variant: "tab"
                buttonSize: 22
                tooltip: "Close " + String(editorRow.modelData.title || editorRow.editorUid)
                visible: editorRow.activeEditor || editorRow.hovered || activeFocus
                onClicked: root.editorCloseRequested(editorRow.editorUid)
            }

            HoverHandler {
                id: rowHover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: root.editorSelected(editorRow.editorUid)
            }

            ToolTip {
                visible: editorRow.hovered && !closeEditorButton.hovered
                text: String(editorRow.modelData.title || editorRow.editorUid)
                      + "\n" + editorRow.editorUid
                delay: 650
            }
        }
    }

    onEditorsChanged: Qt.callLater(revealActiveEditor)
    onActiveUidChanged: Qt.callLater(revealActiveEditor)
    onExpandedChanged: if (expanded) Qt.callLater(revealActiveEditor)
    Component.onCompleted: Qt.callLater(revealActiveEditor)
}
