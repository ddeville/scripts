pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import Quickshell.Networking as Net
import "../../ui"
import "../../services"

ShellPopup {
    id: root

    required property Network backend
    readonly property bool canScan: Net.Networking.wifiEnabled && Net.Networking.wifiHardwareEnabled && backend.wifiDevice !== null
    // Quickshell 0.3.2 exposes incomplete ObjectModel metadata to qmllint.
    readonly property var wifiNetworks: backend.wifiDevice ? backend.wifiDevice.networks.values.slice().sort((a, b) => Number(b.connected) - Number(a.connected) || b.signalStrength - a.signalStrength || a.name.localeCompare(b.name)) : [] // qmllint disable missing-property

    signal settingsRequested()

    implicitWidth: 300
    implicitHeight: body.implicitHeight + 24
    padding: 0
    closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutsideParent
    onOpened: closeButton.forceActiveFocus(Qt.PopupFocusReason)

    Timer {
        interval: 5000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.backend.refreshAddresses()
    }

    Binding {
        target: root.backend.wifiDevice
        property: "scannerEnabled"
        value: true
        when: root.visible && root.canScan
    }

    Column {
        id: body

        x: 12
        y: 12
        width: root.width - 24
        spacing: 10

        Row {
            width: parent.width

            Text {
                width: parent.width - closeButton.width
                anchors.verticalCenter: parent.verticalCenter
                text: "Network"
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: 14
                renderType: Text.QtRendering
            }

            Button {
                id: closeButton

                symbol: "close"
                tooltip: "Close network"
                foreground: Theme.muted
                interactive: true
                onClicked: root.close()
            }
        }

        Column {
            visible: root.backend.wiredDevices.length > 0
            width: parent.width
            spacing: 8

            Text {
                text: "Ethernet"
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                renderType: Text.QtRendering
            }

            Repeater {
                model: root.backend.wiredDevices

                Column {
                    id: wiredConnection

                    required property Net.NetworkDevice modelData

                    width: parent.width
                    spacing: 4

                    Text {
                        width: parent.width
                        text: wiredConnection.modelData ? wiredConnection.modelData.name + " · " + Net.ConnectionState.toString(wiredConnection.modelData.state) : ""
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: wiredConnection.modelData?.connected ? Theme.selected : Theme.muted
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        renderType: Text.QtRendering
                    }

                    Text {
                        visible: wiredConnection.modelData?.connected ?? false
                        width: parent.width
                        text: root.backend.addresses[wiredConnection.modelData?.name] || "No IPv4 address"
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 9
                        renderType: Text.QtRendering
                    }
                }
            }
        }

        Rectangle {
            visible: root.backend.wiredDevices.length > 0
            width: parent.width
            height: 1
            color: Theme.border
        }

        Row {
            width: parent.width

            Text {
                width: parent.width - radio.width
                anchors.verticalCenter: parent.verticalCenter
                text: "Wi-Fi"
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                renderType: Text.QtRendering
            }

            Controls.Switch {
                id: radio

                checked: Net.Networking.wifiEnabled
                enabled: root.backend.wifiDevice !== null && Net.Networking.wifiHardwareEnabled && !root.backend.busy
                implicitWidth: 36
                implicitHeight: 24
                padding: 0
                Accessible.name: "Wi-Fi radio"
                onClicked: root.backend.setEnabled(checked)

                indicator: Rectangle {
                    y: 4
                    width: 32
                    height: 16
                    radius: 8
                    color: radio.checked ? Theme.selected : Theme.hover
                    border.width: radio.visualFocus ? 1 : 0
                    border.color: Theme.foreground

                    Rectangle {
                        x: radio.checked ? 18 : 2
                        y: 2
                        width: 12
                        height: 12
                        radius: 6
                        color: radio.checked ? Theme.background : Theme.muted
                    }

                }

            }

        }

        Column {
            width: parent.width
            spacing: 4

            Text {
                width: parent.width
                text: Net.Networking.backend === Net.NetworkBackendType.None ? "NetworkManager unavailable" : !root.backend.wifiDevice ? "No Wi-Fi adapter" : !Net.Networking.wifiHardwareEnabled ? "Wi-Fi is blocked by hardware" : !Net.Networking.wifiEnabled ? "Wi-Fi is off" : root.backend.current ? root.backend.current.name : "Not connected"
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: root.backend.current ? Theme.selected : Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                renderType: Text.QtRendering
            }

            Text {
                visible: !!root.backend.current
                width: parent.width
                text: root.backend.current ? Math.round(root.backend.current.signalStrength * 100) + "% signal · " + (root.backend.addresses[root.backend.wifiDevice.name] || "No IPv4 address") : ""
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 9
                renderType: Text.QtRendering
            }

            Button {
                visible: !!root.backend.current
                text: "Disconnect"
                foreground: Theme.muted
                interactive: !root.backend.busy
                onClicked: root.backend.disconnectNetwork()
            }

        }

        Rectangle {
            visible: root.canScan
            width: parent.width
            height: 1
            color: Theme.border
        }

        Text {
            visible: root.canScan
            width: parent.width
            text: "WI-FI NETWORKS"
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: 9
            font.letterSpacing: 0.5
            renderType: Text.QtRendering
        }

        Controls.ScrollView {
            visible: root.canScan && root.wifiNetworks.length > 0
            width: parent.width
            implicitHeight: Math.min(networks.implicitHeight, 200)
            contentWidth: availableWidth
            clip: true
            Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff

            Column {
                id: networks

                width: parent.width
                spacing: 2

                Repeater {
                    model: root.wifiNetworks

                    Controls.ItemDelegate {
                        id: networkRow

                        required property Net.WifiNetwork modelData
                        readonly property string networkName: modelData?.name ?? ""
                        readonly property bool connected: modelData?.connected ?? false
                        readonly property real signalStrength: modelData?.signalStrength ?? 0
                        readonly property string description: {
                            if (!modelData)
                                return "";
                            return [
                                connected ? "Connected" : modelData.known ? "Saved" : "",
                                // Quickshell 0.3.2 omits the enum namespace in its tooling metadata.
                                Net.WifiSecurityType.toString(modelData.security), // qmllint disable unresolved-type
                                signalStrength === 0 ? "No signal" : ""
                            ].filter(part => part !== "").join(" · ");
                        }

                        width: networks.width
                        height: 40
                        padding: 0
                        enabled: !root.backend.busy && !connected
                        hoverEnabled: true
                        Accessible.name: networkName + " · " + description + (connected ? "" : " · Connect")
                        onClicked: root.backend.connectNetwork(modelData)
                        Keys.onReturnPressed: clicked()
                        Keys.onEnterPressed: clicked()

                        contentItem: Item {
                            Icon {
                                x: 6
                                anchors.verticalCenter: parent.verticalCenter
                                name: "wifi"
                                level: networkRow.signalStrength
                                color: networkRow.connected ? Theme.selected : Theme.foreground
                            }

                            Column {
                                x: 32
                                width: parent.width - x - 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    width: parent.width
                                    text: networkRow.networkName
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    color: networkRow.connected ? Theme.selected : Theme.foreground
                                    font.family: Theme.font
                                    font.pixelSize: 11
                                    renderType: Text.QtRendering
                                }

                                Text {
                                    width: parent.width
                                    text: networkRow.description
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    color: Theme.muted
                                    font.family: Theme.font
                                    font.pixelSize: 8
                                    renderType: Text.QtRendering
                                }
                            }
                        }

                        HoverHandler {
                            enabled: networkRow.enabled
                            cursorShape: Qt.PointingHandCursor
                        }

                        background: Rectangle {
                            radius: 5
                            color: networkRow.hovered || networkRow.visualFocus ? Theme.hover : networkRow.connected ? Theme.surface : "transparent"
                            border.width: networkRow.visualFocus ? 1 : 0
                            border.color: Theme.selected
                        }

                    }

                }

            }

        }

        Text {
            visible: root.canScan && root.wifiNetworks.length === 0
            text: "No networks found. Scanning automatically…"
            width: parent.width
            wrapMode: Text.Wrap
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: 10
            renderType: Text.QtRendering
        }

        Text {
            visible: text !== "" && root.backend.message === ""
            width: parent.width
            text: {
                const connected = root.backend.wiredConnection || (root.canScan && root.backend.current);
                if (!connected || !Net.Networking.connectivityCheckEnabled)
                    return "";
                switch (Net.Networking.connectivity) {
                case Net.NetworkConnectivity.Portal:
                    return "Sign in to this network to access the internet.";
                case Net.NetworkConnectivity.Limited:
                    return "Connected, but internet access is limited.";
                default:
                    return "";
                }
            }
            wrapMode: Text.Wrap
            color: Theme.selected
            font.family: Theme.font
            font.pixelSize: 10
            renderType: Text.QtRendering
        }

        Text {
            visible: root.backend.message !== ""
            width: parent.width
            text: root.backend.message
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: root.backend.error !== "" ? Theme.alert : Theme.muted
            font.family: Theme.font
            font.pixelSize: 10
            renderType: Text.QtRendering
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.border
        }

        Button {
            text: "Network settings…"
            foreground: Theme.muted
            interactive: true
            onClicked: {
                root.close();
                root.settingsRequested();
            }
        }

    }

    background: Rectangle {
        radius: 10
        color: Theme.background
        border.width: 1
        border.color: Theme.border
    }

}
