pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NetworkUI

Rectangle {
    id: staticRoutingForm
    color: Theme.contentBackground

    property string currentHostIp: ""
    property bool isLoading: false
    property bool isSaving: false
    property bool hasPendingLocalChanges: false
    property string lastError: ""
    property bool defaultRouteEnabled: false
    property bool suppressDirty: false
    property bool showValidationDialog: false
    property string validationMessage: ""
    property string loadedDefaultRouteText: ""
    property string loadedStaticRoutesSignature: "[]"

    ListModel {
        id: routeModel
    }

    function notify(message, type) {
        if (typeof statusBar !== "undefined") {
            statusBar.showMessage(message, type)
        }
    }

    function markDirty() {
        if (staticRoutingForm.isLoading || staticRoutingForm.isSaving || staticRoutingForm.suppressDirty)
            return

        staticRoutingForm.refreshDirtyFlag()
    }

    function normalizeRouteText(text) {
        return String(text || "").trim()
    }

    function currentDefaultRouteText() {
        if (typeof defaultRouteCard === "undefined")
            return ""
        return normalizeRouteText(defaultRouteCard.routeText)
    }

    function staticRoutesSignature() {
        const normalized = []
        for (let i = 0; i < routeModel.count; i++) {
            const row = routeModel.get(i)
            normalized.push({
                routeId: row.routeId !== undefined ? Number(row.routeId) : 0,
                network: normalizeRouteText(row.network),
                mask: normalizeRouteText(row.mask),
                nexthop: normalizeRouteText(row.nexthop),
                ad: normalizeRouteText(row.ad)
            })
        }
        return JSON.stringify(normalized)
    }

    function hasDefaultChanges() {
        const current = staticRoutingForm.defaultRouteEnabled
            ? currentDefaultRouteText()
            : ""
        return current !== loadedDefaultRouteText
    }

    function hasStaticChanges() {
        return staticRoutesSignature() !== loadedStaticRoutesSignature
    }

    function canSaveDefaultOnly() {
        return !staticRoutingForm.isSaving && !staticRoutingForm.isLoading && hasDefaultChanges()
    }

    function canSaveStaticOnly() {
        return !staticRoutingForm.isSaving && !staticRoutingForm.isLoading && hasStaticChanges()
    }

    function refreshDirtyFlag() {
        staticRoutingForm.hasPendingLocalChanges = hasDefaultChanges() || hasStaticChanges()
    }

    function cancelDefaultChanges() {
        if (typeof defaultRouteCard === "undefined")
            return

        staticRoutingForm.suppressDirty = true
        defaultRouteCard.routeText = loadedDefaultRouteText
        staticRoutingForm.defaultRouteEnabled = loadedDefaultRouteText !== ""
        staticRoutingForm.suppressDirty = false
        staticRoutingForm.refreshDirtyFlag()
    }

    function showValidation(message) {
        staticRoutingForm.validationMessage = message
        staticRoutingForm.showValidationDialog = true
    }

    function isValidIPv4(ip) {
        const parts = String(ip).split(".")
        if (parts.length !== 4) return false
        for (let i = 0; i < 4; i++) {
            if (parts[i] === "") return false
            const num = parseInt(parts[i], 10)
            if (isNaN(num) || num < 0 || num > 255) return false
        }
        return true
    }

    function setRowErrors(index, networkError, maskError, nexthopError) {
        routeModel.setProperty(index, "networkError", networkError)
        routeModel.setProperty(index, "maskError", maskError)
        routeModel.setProperty(index, "nexthopError", nexthopError)
    }

    function canAddStaticRow() {
        for (let i = 0; i < routeModel.count; i++) {
            const row = routeModel.get(i)
            const network = String(row.network || "").trim()
            const mask = String(row.mask || "").trim()
            const nexthop = String(row.nexthop || "").trim()

            if (network === "" && mask === "" && nexthop === "") {
                setRowErrors(i, true, true, true)
                showValidation("Có dòng Static Route còn trống. Vui lòng điền đủ Network, Subnet Mask và Next-hop trước khi Add dòng mới.")
                return false
            }

            const missingNetwork = network === ""
            const missingMask = mask === ""
            const missingNexthop = nexthop === ""

            setRowErrors(i, missingNetwork, missingMask, missingNexthop)

            if (missingNetwork || missingMask || missingNexthop) {
                showValidation("Thiếu thông tin static route. Vui lòng nhập đủ Network, Subnet Mask và Next-hop trước khi Add dòng mới.")
                return false
            }
        }
        return true
    }

    function buildRoutesPayload(strictValidation) {
        const routes = []
        let hasMissingRequired = false
        let hasSpaceError = false
        let hasIpv4Error = false

        for (let i = 0; i < routeModel.count; i++) {
            const row = routeModel.get(i)
            const network = String(row.network || "").trim()
            const mask = String(row.mask || "").trim()
            const nexthop = String(row.nexthop || "").trim()
            const adText = String(row.ad || "").trim()

            if (network === "" && mask === "" && nexthop === "") {
                setRowErrors(i, false, false, false)
                continue
            }

            const missingNetwork = network === ""
            const missingMask = mask === ""
            const missingNexthop = nexthop === ""
            setRowErrors(i, missingNetwork, missingMask, missingNexthop)

            if (missingNetwork || missingMask || missingNexthop) {
                hasMissingRequired = true
                continue
            }

            // Kiểm tra dấu cách
            const networkHasSpace = network.includes(" ")
            const maskHasSpace = mask.includes(" ")
            const nexthopHasSpace = nexthop.includes(" ")
            if (networkHasSpace || maskHasSpace || nexthopHasSpace) {
                setRowErrors(i, networkHasSpace, maskHasSpace, nexthopHasSpace)
                hasSpaceError = true
                continue
            }

            // Kiểm tra IPv4 hợp lệ
            const networkInvalid = !isValidIPv4(network)
            const maskInvalid = !isValidIPv4(mask)
            const nexthopInvalid = !isValidIPv4(nexthop)
            if (networkInvalid || maskInvalid || nexthopInvalid) {
                setRowErrors(i, networkInvalid, maskInvalid, nexthopInvalid)
                hasIpv4Error = true
                continue
            }

            let adValue = parseInt(adText)
            if (isNaN(adValue) || adValue < 1 || adValue > 255) {
                adValue = 1
            }

            routes.push({
                id: row.routeId !== undefined ? Number(row.routeId) : (row.id !== undefined ? Number(row.id) : 0),
                network: network,
                mask: mask,
                nexthop: nexthop,
                ad: adValue,
                edited: row.edited === true
            })
        }

        if (hasSpaceError) {
            staticRoutingForm.lastError = "Không được có dấu cách trong ô nhập IP."
            if (strictValidation) {
                notify(staticRoutingForm.lastError, "error")
                showValidation("Các ô đánh dấu đỏ chứa dấu cách. Vui lòng xóa khoảng trắng và thử lại.")
            }
            return null
        }

        if (hasIpv4Error) {
            staticRoutingForm.lastError = "Địa chỉ IP không hợp lệ (phải là x.x.x.x, mỗi octet 0–255)."
            if (strictValidation) {
                notify(staticRoutingForm.lastError, "error")
                showValidation("Các ô đánh dấu đỏ không phải địa chỉ IPv4 hợp lệ.\nĐịnh dạng: x.x.x.x — mỗi octet từ 0 đến 255.")
            }
            return null
        }

        if (hasMissingRequired) {
            staticRoutingForm.lastError = "Static route requires Network, Mask, and Next-hop."
            if (strictValidation) {
                notify(staticRoutingForm.lastError, "error")
                showValidation("Có dòng Static Route còn thiếu Network / Mask / Next-hop. Vui lòng điền đủ các ô màu đỏ.")
            }
            return null
        }

        return routes
    }

    function saveToDatabase(manual) {
        if (staticRoutingForm.isLoading || staticRoutingForm.isSaving)
            return false

        const host = String(staticRoutingForm.currentHostIp || "").trim()
        if (host === "") {
            if (manual)
                notify("Select a device tab before saving Static/Default routing.", "warning")
            return false
        }

        const routesPayload = buildRoutesPayload(manual)
        if (routesPayload === null)
            return false

        if (staticRoutingForm.defaultRouteEnabled) {
            const defText = currentDefaultRouteText()
            if (defText.includes(" ")) {
                if (manual) {
                    notify("Default route next-hop không được chứa dấu cách.", "error")
                    showValidation("Next-hop của Default Route không được chứa dấu cách.")
                }
                return false
            }
            if (!isValidIPv4(defText)) {
                if (manual) {
                    notify("Default route next-hop không phải IPv4 hợp lệ.", "error")
                    showValidation("Next-hop của Default Route không phải địa chỉ IPv4 hợp lệ.\nĐịnh dạng: x.x.x.x — mỗi octet từ 0 đến 255.")
                }
                return false
            }
        }

        staticRoutingForm.isSaving = true

        const ok = dbManager.saveStaticRouting(
            host,
            staticRoutingForm.defaultRouteEnabled
            ? currentDefaultRouteText()
            : "",
            routesPayload
        )

        staticRoutingForm.isSaving = false

        if (ok) {
            staticRoutingForm.lastError = ""
            staticRoutingForm.hasPendingLocalChanges = false
            staticRoutingForm.loadFromDatabase()
            if (manual)
                notify("Static/Default routing saved for host " + host, "success")
            return true
        }

        staticRoutingForm.lastError = "Save static/default routing failed."
        if (manual)
            notify(staticRoutingForm.lastError, "error")
        return false
    }

    function saveDefaultOnly() {
        if (staticRoutingForm.isLoading || staticRoutingForm.isSaving)
            return false

        if (!staticRoutingForm.hasDefaultChanges())
            return false

        const host = String(staticRoutingForm.currentHostIp || "").trim()
        if (host === "") {
            notify("Select a device tab before saving Default route.", "warning")
            return false
        }

        // Preserve static routes currently in DB when saving default only.
        const current = dbManager.getStaticRouting(host)
        const currentOk = current && (current.ok === undefined || current.ok === true)
        if (!currentOk) {
            staticRoutingForm.lastError = "Cannot load current static routes before saving default."
            notify(staticRoutingForm.lastError, "error")
            return false
        }

        const routesPayload = current.routes ? current.routes : []
        const defaultValue = staticRoutingForm.defaultRouteEnabled
            ? currentDefaultRouteText()
                : ""

        if (staticRoutingForm.defaultRouteEnabled) {
            if (defaultValue.includes(" ")) {
                notify("Default route next-hop không được chứa dấu cách.", "error")
                showValidation("Next-hop của Default Route không được chứa dấu cách.")
                return false
            }
            if (!isValidIPv4(defaultValue)) {
                notify("Default route next-hop không phải IPv4 hợp lệ.", "error")
                showValidation("Next-hop của Default Route không phải địa chỉ IPv4 hợp lệ.\nĐịnh dạng: x.x.x.x — mỗi octet từ 0 đến 255.")
                return false
            }
        }

        staticRoutingForm.isSaving = true
        const ok = dbManager.saveStaticRouting(host, defaultValue, routesPayload)
        staticRoutingForm.isSaving = false

        if (ok) {
            staticRoutingForm.lastError = ""
            staticRoutingForm.hasPendingLocalChanges = false
            staticRoutingForm.loadFromDatabase()
            notify("Saved Default route for host " + host, "success")
            return true
        }

        staticRoutingForm.lastError = "Save Default route failed."
        notify(staticRoutingForm.lastError, "error")
        return false
    }

    function saveStaticOnly() {
        if (staticRoutingForm.isLoading || staticRoutingForm.isSaving)
            return false

        if (!staticRoutingForm.hasStaticChanges())
            return false

        const host = String(staticRoutingForm.currentHostIp || "").trim()
        if (host === "") {
            notify("Select a device tab before saving Static routes.", "warning")
            return false
        }

        const routesPayload = buildRoutesPayload(true)
        if (routesPayload === null)
            return false

        // Preserve current default route in DB when saving static only.
        const current = dbManager.getStaticRouting(host)
        const currentOk = current && (current.ok === undefined || current.ok === true)
        if (!currentOk) {
            staticRoutingForm.lastError = "Cannot load current default route before saving static."
            notify(staticRoutingForm.lastError, "error")
            return false
        }

        const defaultValue = current.default_route ? String(current.default_route) : ""

        staticRoutingForm.isSaving = true
        const ok = dbManager.saveStaticRouting(host, defaultValue, routesPayload)
        staticRoutingForm.isSaving = false

        if (ok) {
            staticRoutingForm.lastError = ""
            staticRoutingForm.hasPendingLocalChanges = false
            staticRoutingForm.loadFromDatabase()
            notify("Saved Static routes for host " + host, "success")
            return true
        }

        staticRoutingForm.lastError = "Save Static routes failed."
        notify(staticRoutingForm.lastError, "error")
        return false
    }

    function loadFromDatabase() {
        if (typeof defaultRouteCard === "undefined")
            return

        routeModel.clear()
        defaultRouteCard.routeText = ""
        staticRoutingForm.defaultRouteEnabled = false
        staticRoutingForm.lastError = ""
        staticRoutingForm.loadedDefaultRouteText = ""
        staticRoutingForm.loadedStaticRoutesSignature = "[]"
        staticRoutingForm.hasPendingLocalChanges = false

        const host = String(staticRoutingForm.currentHostIp || "").trim()
        if (host === "")
            return

        staticRoutingForm.isLoading = true

        const payload = dbManager.getStaticRouting(host)
        const ok = payload && (payload.ok === undefined || payload.ok === true)

        if (!ok) {
            staticRoutingForm.lastError = payload && payload.message
                    ? String(payload.message)
                    : "Load static/default routing failed."
            notify(staticRoutingForm.lastError, "error")
            staticRoutingForm.isLoading = false
            return
        }

        defaultRouteCard.routeText = payload.default_route ? String(payload.default_route) : ""
        staticRoutingForm.defaultRouteEnabled = String(defaultRouteCard.routeText || "").trim() !== ""
        staticRoutingForm.loadedDefaultRouteText = staticRoutingForm.defaultRouteEnabled
            ? currentDefaultRouteText()
            : ""

        const routes = payload.routes ? payload.routes : []
        for (let i = 0; i < routes.length; i++) {
            const r = routes[i]
            routeModel.append({
                id: r.id !== undefined ? r.id : 0,
                routeId: r.id !== undefined ? r.id : 0,
                network: r.network ? String(r.network) : "",
                mask: r.mask ? String(r.mask) : "",
                nexthop: r.nexthop ? String(r.nexthop) : "",
                ad: r.ad !== undefined ? String(r.ad) : "1",
                originalNetwork: r.network ? String(r.network) : "",
                originalMask: r.mask ? String(r.mask) : "",
                originalNexthop: r.nexthop ? String(r.nexthop) : "",
                originalAd: r.ad !== undefined ? String(r.ad) : "1",
                success: r.success !== undefined ? Number(r.success) : 0,
                edited: false,
                canEdit: r.id !== undefined ? false : true,
                networkError: false,
                maskError: false,
                nexthopError: false
            })
        }

        staticRoutingForm.loadedStaticRoutesSignature = staticRoutingForm.staticRoutesSignature()
        staticRoutingForm.refreshDirtyFlag()

        staticRoutingForm.isLoading = false
    }

    onCurrentHostIpChanged: {
        loadFromDatabase()
    }

    Component.onCompleted: {
        loadFromDatabase()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            color: Theme.contentBackground
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            Layout.topMargin: 12
            Layout.bottomMargin: 12
            radius: 6
            border.color: Theme.borderColor
            border.width: Theme.borderWidth
            implicitHeight: topBarLayout.implicitHeight + 16

            RowLayout {
                id: topBarLayout
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                Text {
                    text: "Static / Default Routing"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeLarge
                    font.family: Theme.fontFamily
                    font.bold: true
                }

                Rectangle {
                    radius: 10
                    color: Theme.sideBarItemHover
                    implicitHeight: hostText.implicitHeight + 6
                    implicitWidth: hostText.implicitWidth + 14

                    Text {
                        id: hostText
                        anchors.centerIn: parent
                        text: staticRoutingForm.currentHostIp !== ""
                              ? ("Host: " + staticRoutingForm.currentHostIp)
                              : "Host: (none)"
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontFamily
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    visible: staticRoutingForm.hasPendingLocalChanges
                    text: staticRoutingForm.isSaving ? "Saving..." : "Pending manual save"
                    color: staticRoutingForm.isSaving ? Theme.accentColor : Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                }
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: parent.width
                spacing: 16

                StaticRoutingDefaultCard {
                    id: defaultRouteCard
                    form: staticRoutingForm
                }

                StaticRoutingRoutesCard {
                    form: staticRoutingForm
                    routeModel: routeModel
                }

                Item { height: 8 }
            }
        }


        Rectangle {
            Layout.fillWidth: true
            height: Theme.borderWidth
            color: Theme.borderColor
        }

        Rectangle {
            Layout.fillWidth: true
            height: 56
            color: Theme.contentBackground

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                anchors.topMargin: 10
                anchors.bottomMargin: 10
                spacing: 8

                Text {
                    text: staticRoutingForm.lastError !== ""
                          ? staticRoutingForm.lastError
                          : "Static/Default are separated and auto-saved by host."
                    color: staticRoutingForm.lastError !== "" ? Theme.alertError : Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Rectangle {
                    Layout.preferredWidth: 92
                    Layout.preferredHeight: 34
                    radius: 4
                    color: reloadHover.hovered ? Theme.sideBarItemHover : "transparent"
                    border.color: Theme.borderColor
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Reload"
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeNormal
                        font.family: Theme.fontFamily
                    }

                    HoverHandler { id: reloadHover }
                    TapHandler {
                        onTapped: {
                            staticRoutingForm.loadFromDatabase()
                            notify("Static/Default reloaded for host " + staticRoutingForm.currentHostIp, "info")
                        }
                    }
                }

            }
        }
    }

    StaticRoutingValidationDialog {
        form: staticRoutingForm
    }
}
