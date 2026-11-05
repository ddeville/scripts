import QtQuick
import QtQuick.Controls as Controls
import Quickshell

Controls.Control {
    id: root

    property string text: ""
    property string caption: ""
    property string symbol: ""
    property string glyph: ""
    property real glyphSize: Theme.iconSize
    property real level: 1
    property bool muted: false
    property bool plugged: false
    property string tooltip: ""
    property bool tooltipEnabled: true
    // QsWindow exposes QObject; ShellPopup adds the shellPopup property at runtime.
    readonly property bool tooltipInPopup: root.QsWindow.window?.shellPopup === true || !root.QsWindow.contentItem || root.Window.window !== root.QsWindow.contentItem.Window.window // qmllint disable missing-property
    property bool tooltipReady: false
    readonly property bool tooltipWanted: tooltipEnabled && tooltip !== "" && mouse.containsMouse && !mouse.pressed
    property int textWidth: 0
    property Component indicator: null
    property bool interactive: false
    property bool active: false
    property bool selected: false
    property bool stacked: false
    property color foreground: Theme.foreground

    signal clicked(int button)
    signal scrolled(int delta)

    onTooltipWantedChanged: {
        tooltipReady = false;
        if (tooltipWanted)
            tooltipDelay.restart();
        else
            tooltipDelay.stop();
    }
    implicitWidth: contentStack.implicitWidth + (stacked ? 8 : 12)
    implicitHeight: Theme.height - 10
    activeFocusOnTab: interactive || activeFocus
    Accessible.role: interactive ? Accessible.Button : Accessible.StaticText
    Accessible.name: tooltip || text || caption || symbol
    Accessible.onPressAction: {
        if (interactive)
            clicked(Qt.LeftButton);

    }
    Keys.onReturnPressed: {
        if (interactive)
            clicked(Qt.LeftButton);

    }
    Keys.onEnterPressed: {
        if (interactive)
            clicked(Qt.LeftButton);

    }
    Keys.onSpacePressed: {
        if (interactive)
            clicked(Qt.LeftButton);

    }

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

        Icon {
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

            Icon {
                visible: !root.stacked && root.symbol !== ""
                name: root.symbol
                color: root.foreground
                level: root.level
                muted: root.muted
                plugged: root.plugged
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                visible: root.glyph !== ""
                text: root.glyph
                color: root.foreground
                font.family: "Font Awesome 7 Brands"
                font.pixelSize: root.glyphSize
                renderType: Text.QtRendering
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                visible: root.text !== ""
                width: root.textWidth > 0 ? root.textWidth : implicitWidth
                text: root.text
                textFormat: Text.PlainText
                elide: Text.ElideRight
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
        enabled: root.interactive || root.tooltip !== ""
        hoverEnabled: true
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: (event) => {
            if (root.interactive) {
                root.forceActiveFocus(Qt.MouseFocusReason);
                root.clicked(event.button);
            }
        }
        onWheel: (event) => {
            if (root.interactive)
                root.scrolled(event.angleDelta.y);

        }
    }

    Timer {
        id: tooltipDelay

        interval: 500
        onTriggered: root.tooltipReady = true
    }

    PopupWindow {
        visible: !root.tooltipInPopup && root.tooltipReady && root.tooltipWanted
        implicitWidth: barTooltipText.implicitWidth + 16
        implicitHeight: barTooltipText.implicitHeight + 16
        color: "transparent"
        // Quickshell 0.3.2 exports PopupAnchor as opaque in its window metadata.
        // qmllint disable missing-property unresolved-type unqualified
        anchor.item: root
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        anchor.rect.y: -8
        anchor.rect.width: root.width
        anchor.rect.height: 1
        // qmllint enable missing-property unresolved-type unqualified

        Rectangle {
            anchors.fill: parent
            color: Theme.background
            radius: 6
            border.width: 1
            border.color: Theme.border
        }

        Text {
            id: barTooltipText

            anchors.centerIn: parent
            text: root.tooltip
            textFormat: Text.PlainText
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: 11
            renderType: Text.QtRendering
        }

    }

    Controls.ToolTip {
        parent: root
        visible: root.tooltipInPopup && root.tooltipReady && root.tooltipWanted
        popupType: Controls.Popup.Item
        padding: 8
        margins: 8
        x: (root.width - width) / 2
        y: -height - 8
        implicitWidth: Math.min(tooltipText.implicitWidth + 16, 400)
        implicitHeight: tooltipText.implicitHeight + 16

        background: Rectangle {
            color: Theme.background
            radius: 6
            border.width: 1
            border.color: Theme.border
        }

        contentItem: Text {
            id: tooltipText

            text: root.tooltip
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: 11
            renderType: Text.QtRendering
        }

    }

    background: Rectangle {
        radius: 5
        color: root.active || root.selected ? Theme.selectionSurface : root.interactive && (mouse.containsMouse || root.visualFocus) ? Theme.hover : "transparent"
        border.width: root.selected || (root.interactive && root.visualFocus) ? 1 : 0
        border.color: Theme.selected
    }

}
