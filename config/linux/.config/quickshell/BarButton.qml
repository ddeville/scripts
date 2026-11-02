import QtQuick

Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    property string symbol: ""
    property real level: 1
    property bool muted: false
    property int textWidth: 0
    property Component indicator: null
    property string iconFont: Theme.iconFont
    property bool interactive: false
    property bool active: false
    property color foreground: Theme.foreground

    signal clicked(int button)
    signal scrolled(int delta)

    implicitWidth: contents.implicitWidth + 14
    implicitHeight: Theme.height - 10
    radius: 5
    color: active ? Theme.selectionSurface : interactive && mouse.containsMouse ? Theme.hover : "transparent"
    border.width: active ? 1 : 0
    border.color: Theme.selected

    Row {
        id: contents

        anchors.verticalCenter: parent.verticalCenter
        x: 7
        spacing: 6

        Loader {
            active: root.indicator !== null
            sourceComponent: root.indicator
            anchors.verticalCenter: parent.verticalCenter
        }

        BarIcon {
            visible: root.symbol !== ""
            name: root.symbol
            color: root.foreground
            level: root.level
            muted: root.muted
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            visible: root.icon !== ""
            text: root.icon
            color: root.foreground
            font.family: root.iconFont
            font.pixelSize: Theme.iconSize
            renderType: Text.QtRendering
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            visible: root.text !== ""
            width: root.textWidth > 0 ? root.textWidth : implicitWidth
            text: root.text
            textFormat: Text.PlainText
            color: root.foreground
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            renderType: Text.QtRendering
            anchors.verticalCenter: parent.verticalCenter
        }

    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: (event) => {
            return root.clicked(event.button);
        }
        onWheel: (event) => {
            return root.scrolled(event.angleDelta.y);
        }
    }

}
