import QtQuick
import QtQuick.Controls as Controls
import "../../ui"
import "../../services"

ShellPopup {
    id: root

    required property Network backend
    readonly property var state: backend.state

    signal settingsRequested()

    implicitWidth: 300
    implicitHeight: body.implicitHeight + 24
    padding: 0
    closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutsideParent
    onOpened: {
        backend.refresh();
        closeButton.forceActiveFocus(Qt.PopupFocusReason);
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
            visible: root.state.wired.length > 0
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
                model: root.state.wired

                Column {
                    required property var modelData

                    width: parent.width
                    spacing: 4

                    Text {
                        width: parent.width
                        text: modelData.device + " · " + (modelData.connected ? "Connected" : "Not connected")
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: modelData.connected ? Theme.selected : Theme.muted
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        renderType: Text.QtRendering
                    }

                    Text {
                        visible: modelData.connected
                        width: parent.width
                        text: modelData.address || "Obtaining address…"
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
            visible: root.state.wired.length > 0
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

                checked: root.state.enabled
                enabled: root.state.available && root.state.device !== "" && !root.backend.busy
                implicitWidth: 36
                implicitHeight: 24
                padding: 0
                Accessible.name: "Wi-Fi radio"
                onClicked: root.backend.run(["radio", "wifi", checked ? "on" : "off"], checked ? "Enabling Wi-Fi…" : "Disabling Wi-Fi…")

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
                text: !root.state.available ? "NetworkManager unavailable" : !root.state.device ? "No Wi-Fi adapter" : !root.state.enabled ? "Wi-Fi is off" : root.state.current ? root.state.current.ssid : "Not connected"
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: root.state.current ? Theme.selected : Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                renderType: Text.QtRendering
            }

            Text {
                visible: !!root.state.current
                width: parent.width
                text: root.state.current ? root.state.current.signal + "% signal · " + (root.state.address || "Obtaining address…") : ""
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 9
                renderType: Text.QtRendering
            }

            Button {
                visible: !!root.state.current
                text: "Disconnect"
                foreground: Theme.muted
                interactive: !root.backend.busy
                onClicked: root.backend.run(["device", "disconnect", root.state.device], "Disconnecting…")
            }

        }

        Rectangle {
            visible: root.state.enabled && root.state.device !== ""
            width: parent.width
            height: 1
            color: Theme.border
        }

        Row {
            visible: root.state.enabled && root.state.device !== ""
            width: parent.width

            Text {
                width: parent.width - 28
                anchors.verticalCenter: parent.verticalCenter
                text: "NEARBY NETWORKS"
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 9
                font.letterSpacing: 0.5
                renderType: Text.QtRendering
            }

            Button {
                symbol: "restart"
                tooltip: "Scan for networks"
                foreground: Theme.muted
                interactive: !root.backend.busy
                onClicked: root.backend.run(["device", "wifi", "rescan", "ifname", root.state.device], "Scanning…")
            }

        }

        Controls.ScrollView {
            visible: root.state.enabled && root.state.networks.length > 0
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
                    model: root.state.networks

                    Controls.Control {
                        id: networkRow

                        required property var modelData

                        function connectNetwork() {
                            if (root.backend.busy || modelData.active)
                                return ;

                            // Let NetworkManager's credential dialog take focus if needed.
                            root.close();
                            root.backend.run(["device", "wifi", "connect", modelData.bssid, "ifname", root.state.device], "Connecting to " + modelData.ssid + "…");
                        }

                        width: networks.width
                        height: 40
                        activeFocusOnTab: (!root.backend.busy && !modelData.active) || activeFocus
                        Accessible.role: Accessible.Button
                        Accessible.name: modelData.ssid + (modelData.active ? " · Connected" : " · Connect")
                        Accessible.onPressAction: connectNetwork()
                        Keys.onReturnPressed: connectNetwork()
                        Keys.onEnterPressed: connectNetwork()
                        Keys.onSpacePressed: connectNetwork()

                        Icon {
                            x: 6
                            anchors.verticalCenter: parent.verticalCenter
                            name: "wifi"
                            level: networkRow.modelData.signal / 100
                            color: networkRow.modelData.active ? Theme.selected : Theme.foreground
                        }

                        Column {
                            x: 32
                            width: parent.width - x - 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                width: parent.width
                                text: networkRow.modelData.ssid
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                color: networkRow.modelData.active ? Theme.selected : Theme.foreground
                                font.family: Theme.font
                                font.pixelSize: 11
                                renderType: Text.QtRendering
                            }

                            Text {
                                width: parent.width
                                text: (networkRow.modelData.active ? "Connected · " : "") + (networkRow.modelData.security || "Open")
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                color: Theme.muted
                                font.family: Theme.font
                                font.pixelSize: 8
                                renderType: Text.QtRendering
                            }

                        }

                        MouseArea {
                            id: networkMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !root.backend.busy && !networkRow.modelData.active
                            cursorShape: Qt.PointingHandCursor
                            onClicked: networkRow.connectNetwork()
                        }

                        background: Rectangle {
                            radius: 5
                            color: networkMouse.containsMouse || networkRow.visualFocus ? Theme.hover : networkRow.modelData.active ? Theme.surface : "transparent"
                            border.width: networkRow.visualFocus ? 1 : 0
                            border.color: Theme.selected
                        }

                    }

                }

            }

        }

        Text {
            visible: root.state.enabled && root.state.networks.length === 0 && !!root.state.device
            text: "No networks found · try scanning"
            color: Theme.muted
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
            color: root.backend.failed ? Theme.alert : Theme.muted
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
