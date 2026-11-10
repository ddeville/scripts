pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import "../../ui"
import "../../services"

ShellPopup {
    id: root

    required property Tailscale backend
    readonly property var state: backend.state
    property bool exitNodesExpanded: false
    property bool accountsExpanded: false
    property bool devicesExpanded: false
    property string copiedAddress: ""

    function copyAddress(address) {
        Quickshell.clipboardText = address;
        copiedAddress = address;
        copyFeedback.restart();
    }

    implicitWidth: 340
    padding: 12
    onOpened: {
        backend.refresh();
        closeButton.forceActiveFocus(Qt.PopupFocusReason);
    }

    component Label: Text {
        width: parent.width
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: Theme.foreground
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        renderType: Text.QtRendering
    }

    component Rule: Rectangle {
        width: parent.width
        height: 1
        color: Theme.border
    }

    component MenuButton: Button {
        width: parent.width
        height: 32
        textWidth: width - (symbol !== "" ? 38 : 12)
        onActiveFocusChanged: {
            if (activeFocus) {
                const view = scroll.contentItem as Flickable;
                const position = mapToItem(body, 0, 0);
                view.contentY = Math.max(0, Math.min(position.y, Math.max(view.contentY, position.y + height - view.height)));
            }
        }
    }

    Timer {
        id: copyFeedback
        interval: 2000
        onTriggered: root.copiedAddress = ""
    }

    contentItem: Controls.ScrollView {
        id: scroll
        implicitHeight: Math.min(body.implicitHeight, 520 - root.topPadding - root.bottomPadding)
        contentWidth: availableWidth
        clip: true
        Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff

        Column {
            id: body

            width: scroll.availableWidth
            spacing: 10

            Row {
                width: parent.width

                Label {
                    width: parent.width - closeButton.width
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Tailscale"
                    font.pixelSize: 14
                }

                Button {
                    id: closeButton
                    symbol: "close"
                    tooltip: "Close Tailscale"
                    foreground: Theme.muted
                    onClicked: root.close()
                }
            }

            Row {
                width: parent.width
                spacing: 10

                TailscaleIcon {
                    width: 28
                    height: 28
                    connected: root.state.connected
                    exitNode: root.backend.usingExitNode
                    exitNodeOnline: root.state.exitNode?.online ?? true
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    width: parent.width - 28 - connectionSwitch.width - 20
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Label {
                        text: root.backend.statusText
                        color: root.backend.warning ? Theme.alert : root.state.connected ? Theme.selected : Theme.muted
                    }

                    Label {
                        text: root.state.tailnet || "Private network"
                        color: Theme.muted
                        font.pixelSize: 10
                    }
                }

                Controls.Switch {
                    id: connectionSwitch
                    checked: root.state.connected
                    enabled: root.state.available && !root.backend.busy && root.state.backend !== "NeedsMachineAuth"
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 36
                    implicitHeight: 24
                    padding: 0
                    Accessible.name: "Tailscale connection"
                    onClicked: root.backend.setConnected(checked)

                    indicator: Rectangle {
                        y: 4
                        width: 32
                        height: 16
                        radius: 8
                        color: connectionSwitch.checked ? Theme.selected : Theme.hover
                        border.width: connectionSwitch.visualFocus ? 1 : 0
                        border.color: Theme.foreground

                        Rectangle {
                            x: connectionSwitch.checked ? 18 : 2
                            y: 2
                            width: 12
                            height: 12
                            radius: 6
                            color: connectionSwitch.checked ? Theme.background : Theme.muted
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 3
                visible: root.state.account !== "" || root.state.device !== ""

                Label {
                    visible: text !== ""
                    text: root.state.account
                    color: Theme.muted
                    font.pixelSize: 10
                }

                MenuButton {
                    visible: root.state.device !== ""
                    text: root.state.device + (root.state.address ? " · " + root.state.address : "")
                    tooltip: root.copiedAddress === root.state.address && root.state.address ? "Copied" : "Copy device IP address"
                    enabled: root.state.address !== ""
                    foreground: root.copiedAddress === root.state.address && root.state.address ? Theme.selected : Theme.foreground
                    onClicked: root.copyAddress(root.state.address)
                }
            }

            Rule {}

            Column {
                width: parent.width
                spacing: 4

                Label {
                    text: "EXIT NODE"
                    color: Theme.muted
                    font.pixelSize: 9
                    font.letterSpacing: 0.5
                }

                MenuButton {
                    symbol: root.exitNodesExpanded ? "chevron-down" : "chevron-right"
                    text: root.state.exitNode ? root.state.exitNode.name + (root.state.exitNode.online ? "" : " · offline") : "None · Direct internet"
                    tooltip: root.state.exitNode ? root.state.exitNode.name : "Route internet traffic through another device"
                    enabled: root.state.connected && !root.backend.busy
                    foreground: root.state.connected ? Theme.foreground : Theme.muted
                    onClicked: root.exitNodesExpanded = !root.exitNodesExpanded
                }

                Label {
                    visible: !root.state.connected
                    text: "Connect to choose an exit node"
                    color: Theme.muted
                    font.pixelSize: 10
                }

                Column {
                    visible: root.exitNodesExpanded && root.state.connected
                    width: parent.width
                    spacing: 4

                    Controls.TextField {
                        id: exitSearch
                        visible: root.state.exitNodes.length > 8
                        width: parent.width
                        placeholderText: "Find an exit node…"
                        color: Theme.foreground
                        placeholderTextColor: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 11
                        selectByMouse: true
                        background: Rectangle {
                            color: Theme.surface
                            radius: 5
                            border.width: 1
                            border.color: exitSearch.activeFocus ? Theme.selected : Theme.border
                        }
                    }

                    MenuButton {
                        text: "None · Direct internet"
                        selected: !root.state.exitNode
                        enabled: !root.backend.busy
                        onClicked: {
                            root.backend.selectExitNode("");
                            root.exitNodesExpanded = false;
                        }
                    }

                    Repeater {
                        model: root.state.exitNodes.filter(node => !exitSearch.visible || (node.name + " " + node.location).toLowerCase().includes(exitSearch.text.toLowerCase()))

                        MenuButton {
                            required property var modelData
                            text: (modelData.location ? modelData.location + " · " : "") + modelData.name + (modelData.online ? "" : " · offline")
                            selected: root.state.exitNode?.id === modelData.id
                            foreground: modelData.online ? Theme.foreground : Theme.muted
                            tooltip: modelData.name + "\n" + modelData.address
                            enabled: modelData.online && !!modelData.address && !root.backend.busy
                            onClicked: {
                                root.backend.selectExitNode(modelData.address);
                                root.exitNodesExpanded = false;
                            }
                        }
                    }

                    Label {
                        visible: root.state.exitNodes.length === 0
                        text: "No exit nodes available"
                        color: Theme.muted
                        font.pixelSize: 10
                    }
                }
            }

            Rule {}

            Column {
                width: parent.width
                spacing: 4

                MenuButton {
                    text: "Accounts · " + root.state.profiles.length
                    symbol: root.accountsExpanded ? "chevron-down" : "chevron-right"
                    enabled: root.state.profiles.length > 0
                    onClicked: root.accountsExpanded = !root.accountsExpanded
                }

                Repeater {
                    model: root.accountsExpanded ? root.state.profiles : []

                    MenuButton {
                        required property var modelData
                        text: (modelData.nickname || modelData.account) + " · " + modelData.tailnet
                        tooltip: modelData.account + "\n" + modelData.tailnet
                        selected: modelData.selected
                        enabled: !modelData.selected && !root.backend.busy
                        onClicked: {
                            root.backend.switchAccount(modelData.id);
                            root.accountsExpanded = false;
                        }
                    }
                }

                MenuButton {
                    text: "Devices · " + root.state.peers.filter(peer => peer.online).length + " online"
                    symbol: root.devicesExpanded ? "chevron-down" : "chevron-right"
                    enabled: root.state.connected
                    onClicked: root.devicesExpanded = !root.devicesExpanded
                }

                Repeater {
                    model: root.devicesExpanded && root.state.connected ? root.state.peers : []

                    MenuButton {
                        required property var modelData
                        text: modelData.name + (modelData.online ? "" : " · offline")
                        tooltip: (root.copiedAddress === modelData.address ? "Copied: " : "Copy: ") + modelData.address
                        foreground: root.copiedAddress === modelData.address ? Theme.selected : modelData.online ? Theme.foreground : Theme.muted
                        enabled: !!modelData.address
                        onClicked: root.copyAddress(modelData.address)
                    }
                }
            }

            Label {
                visible: text !== ""
                text: root.backend.message || root.state.error || (root.state.backend === "NeedsMachineAuth" ? "Approve this device in the Tailscale admin console." : root.state.health.join("\n"))
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                color: root.backend.failed || root.state.error || root.state.health.length > 0 ? Theme.alert : Theme.muted
                font.pixelSize: 10
            }

            MenuButton {
                visible: !!(root.backend.loginUrl || root.state.authUrl) && !root.state.connected
                text: "Open sign-in page…"
                onClicked: {
                    root.close();
                    root.backend.openLogin();
                }
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
