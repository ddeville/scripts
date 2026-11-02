import QtQuick

Rectangle {
    id: root

    property string text: ""
    property string caption: ""
    property string symbol: ""
    property string glyph: ""
    property real level: 1
    property bool muted: false
    property int textWidth: 0
    property Component indicator: null
    property bool interactive: false
    property bool active: false
    property bool stacked: false
    property color foreground: Theme.foreground

    signal clicked(int button)
    signal scrolled(int delta)

    implicitWidth: contentStack.implicitWidth + (stacked ? 8 : 12)
    implicitHeight: Theme.height - 10
    radius: 5
    color: active ? Theme.selectionSurface : interactive && mouse.containsMouse ? Theme.hover : "transparent"
    border.width: active ? 1 : 0
    border.color: Theme.selected

    Column {
        id: contentStack

        anchors.verticalCenter: parent.verticalCenter
        x: root.stacked ? 4 : 6
        spacing: 0

        Text {
            visible: root.caption !== ""
            text: root.caption
            width: root.stacked ? contents.implicitWidth : implicitWidth
            horizontalAlignment: root.stacked ? Text.AlignHCenter : Text.AlignLeft
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: Theme.captionSize
            font.letterSpacing: 0.5
            renderType: Text.QtRendering
        }

        BarIcon {
            visible: root.stacked && root.symbol !== ""
            name: root.symbol
            color: root.foreground
            implicitWidth: 12
            implicitHeight: 12
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Row {
            id: contents

            spacing: 5

            Loader {
                active: root.indicator !== null
                sourceComponent: root.indicator
                anchors.verticalCenter: parent.verticalCenter
            }

            BarIcon {
                visible: !root.stacked && root.symbol !== ""
                name: root.symbol
                color: root.foreground
                level: root.level
                muted: root.muted
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                visible: root.glyph !== ""
                text: root.glyph
                color: root.foreground
                font.family: "Font Awesome 7 Brands"
                font.pixelSize: Theme.iconSize
                renderType: Text.QtRendering
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                visible: root.text !== ""
                width: root.textWidth > 0 ? root.textWidth : implicitWidth
                text: root.text
                textFormat: Text.PlainText
                horizontalAlignment: root.stacked ? Text.AlignHCenter : Text.AlignLeft
                color: root.foreground
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                renderType: Text.QtRendering
                anchors.verticalCenter: parent.verticalCenter
            }

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
