pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import "../../ui"
import "../../services"

ShellPopup {
    id: root

    required property Notifications backend

    implicitWidth: 280
    padding: 12
    closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutsideParent
    onOpened: closeButton.forceActiveFocus(Qt.PopupFocusReason)

    contentItem: Column {
        spacing: 10

        Row {
            width: parent.width

            Text {
                width: parent.width - 28
                anchors.verticalCenter: parent.verticalCenter
                text: "Notifications"
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: 14
            }

            Button {
                id: closeButton

                symbol: "close"
                tooltip: "Close notifications"
                foreground: Theme.muted
                onClicked: root.close()
            }

        }

        Text {
            width: parent.width
            text: root.backend.summary
            wrapMode: Text.Wrap
            color: root.backend.paused ? Theme.muted : Theme.selected
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }

        Button {
            visible: root.backend.paused
            width: parent.width
            height: 30
            text: "Resume now"
            symbol: "bell"
            enabled: root.backend.available && !root.backend.busy
            onClicked: root.backend.run(["resume"])
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.border
        }

        Text {
            text: root.backend.paused ? "CHANGE PAUSE DURATION" : "PAUSE NOTIFICATIONS"
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: 9
            font.letterSpacing: 0.5
        }

        Column {
            width: parent.width
            spacing: 4

            Repeater {
                model: [{
                    "label": "15 minutes",
                    "seconds": 900
                }, {
                    "label": "1 hour",
                    "seconds": 3600
                }, {
                    "label": "2 hours",
                    "seconds": 7200
                }, {
                    "label": "Until I resume",
                    "seconds": 0
                }]

                delegate: Button {
                    required property var modelData

                    width: parent.width
                    height: 30
                    text: modelData.label
                    enabled: root.backend.available && !root.backend.busy
                    onClicked: root.backend.run(["pause", String(modelData.seconds)])
                }

            }

        }

        Text {
            width: parent.width
            text: root.backend.error || "Notifications wait until you resume."
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: root.backend.error ? Theme.alert : Theme.muted
            font.family: Theme.font
            font.pixelSize: 10
        }

    }

    background: Rectangle {
        radius: 10
        color: Theme.background
        border.width: 1
        border.color: Theme.border
    }

}
