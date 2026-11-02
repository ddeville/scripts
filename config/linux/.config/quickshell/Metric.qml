import QtQuick

Column {
    id: root

    required property string label
    required property string value
    property bool alert: false

    width: 48
    spacing: 0

    Text {
        text: root.label
        color: Theme.muted
        font.family: Theme.font
        font.pixelSize: 8
        font.letterSpacing: 1
        renderType: Text.QtRendering
    }

    Text {
        text: root.value
        color: root.alert ? Theme.alert : Theme.foreground
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        renderType: Text.QtRendering
    }

}
