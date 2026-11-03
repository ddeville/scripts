import QtQuick
import QtQuick.Controls as Controls

Controls.Popup {
    id: root

    required property Item anchorItem
    property bool below: false
    property var pendingAction: null

    signal actionRequested(string action)

    function choose(action) {
        pendingAction = action;
        cancelButton.forceActiveFocus();
    }

    function confirm() {
        const action = pendingAction.action;
        visible = false;
        actionRequested(action);
    }

    implicitWidth: 250
    implicitHeight: body.implicitHeight + 24
    parent: anchorItem
    x: anchorItem.width - width
    y: below ? anchorItem.height + 8 : -height - 8
    padding: 0
    margins: -1
    popupType: Controls.Popup.Window
    focus: true
    closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutsideParent
    onVisibleChanged: {
        pendingAction = null;
        if (visible)
            actions.itemAt(0).forceActiveFocus();

    }

    FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: (event) => {
            root.visible = false;
            event.accepted = true;
        }

        Column {
            id: body

            x: 12
            y: 12
            width: root.width - 24
            spacing: 8

            Item {
                width: parent.width
                height: 28

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Session"
                    color: Theme.foreground
                    font.family: Theme.font
                    font.pixelSize: 14
                    renderType: Text.QtRendering
                }

                ActionButton {
                    anchors.right: parent.right
                    width: 28
                    height: 28
                    padding: 6
                    symbol: "close"
                    foreground: Theme.muted
                    Accessible.name: "Close session menu"
                    onClicked: root.visible = false
                }

            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
            }

            Column {
                visible: root.pendingAction === null
                width: parent.width
                spacing: 4

                Repeater {
                    id: actions

                    model: [{
                        "action": "suspend",
                        "label": "Suspend",
                        "detail": "Put this session to sleep",
                        "symbol": "moon"
                    }, {
                        "action": "reboot",
                        "label": "Restart",
                        "detail": "Restart this computer",
                        "symbol": "restart"
                    }, {
                        "action": "poweroff",
                        "label": "Shut Down",
                        "detail": "Turn off this computer",
                        "symbol": "power"
                    }]

                    delegate: ActionButton {
                        required property var modelData

                        width: parent.width
                        text: modelData.label
                        detail: modelData.detail
                        symbol: modelData.symbol
                        foreground: modelData.action === "poweroff" ? Theme.alert : Theme.foreground
                        onClicked: root.choose(modelData)
                    }

                }

            }

            Column {
                visible: root.pendingAction !== null
                width: parent.width
                spacing: 14

                Text {
                    x: 8
                    width: parent.width - 16
                    topPadding: 6
                    text: root.pendingAction ? root.pendingAction.label + "?" : ""
                    color: Theme.foreground
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    renderType: Text.QtRendering
                }

                Row {
                    width: parent.width
                    spacing: 8

                    ActionButton {
                        id: cancelButton

                        width: (parent.width - parent.spacing) / 2
                        text: "Cancel"
                        onClicked: {
                            root.pendingAction = null;
                            actions.itemAt(0).forceActiveFocus();
                        }
                    }

                    ActionButton {
                        width: (parent.width - parent.spacing) / 2
                        text: root.pendingAction ? root.pendingAction.label : ""
                        foreground: Theme.alert
                        onClicked: root.confirm()
                    }

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

    component ActionButton: Controls.Button {
        id: control

        property string symbol: ""
        property string detail: ""
        property color foreground: Theme.foreground

        implicitHeight: detail === "" ? 34 : 46
        padding: 10
        hoverEnabled: true

        background: Rectangle {
            radius: 6
            color: control.down ? Theme.selectionSurface : control.hovered || control.visualFocus ? Theme.hover : "transparent"
            border.width: control.visualFocus ? 1 : 0
            border.color: Theme.selected
        }

        contentItem: Row {
            spacing: 10

            BarIcon {
                visible: control.symbol !== ""
                name: control.symbol
                color: control.foreground
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Text {
                    text: control.text
                    color: control.foreground
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    renderType: Text.QtRendering
                }

                Text {
                    visible: control.detail !== ""
                    text: control.detail
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 9
                    renderType: Text.QtRendering
                }

            }

        }

    }

}
