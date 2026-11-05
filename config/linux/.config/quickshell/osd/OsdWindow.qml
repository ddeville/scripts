import QtQuick
import Quickshell
import "../ui"

// Quickshell chooses a concrete PanelWindow backend at runtime.
PanelWindow { // qmllint disable uncreatable-type
    id: root

    required property Osd backend
    required property string monitorName
    readonly property color accent: backend.muted ? Theme.muted : backend.value > 100 ? Theme.alert : Theme.selected

    visible: backend.visible && monitorName === backend.monitorName
    implicitWidth: 300
    implicitHeight: 74
    anchors.bottom: true
    // Quickshell 0.3.2 exports margins as opaque in its window metadata.
    margins.bottom: Theme.height + 24 // qmllint disable missing-property
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    color: "transparent"
    mask: Region {}

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: Theme.background
        border.width: 1
        border.color: Theme.border

        Row {
            anchors.centerIn: parent
            width: parent.width - 32
            spacing: 14

            Icon {
                name: root.backend.symbol
                level: root.backend.value / 100
                muted: root.backend.muted
                color: root.accent
                width: 24
                height: 24
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                width: parent.width - 38
                spacing: 10

                Row {
                    width: parent.width

                    Text {
                        width: parent.width - percentage.implicitWidth
                        text: root.backend.label
                        color: Theme.foreground
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                    }

                    Text {
                        id: percentage

                        text: root.backend.value + "%"
                        color: root.accent
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 5
                    radius: 2.5
                    color: Theme.hover

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, root.backend.value / 100))
                        height: parent.height
                        radius: parent.radius
                        color: root.accent

                        Behavior on width {
                            NumberAnimation { duration: 70 }
                        }
                    }
                }
            }
        }
    }
}
