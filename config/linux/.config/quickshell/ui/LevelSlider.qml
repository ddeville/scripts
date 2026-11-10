import QtQuick
import QtQuick.Controls as Controls

Controls.Slider {
    id: root

    property real reportedValue: 0
    property color accent: Theme.selected
    property real markerValue: -1

    function syncValue() {
        if (!pressed)
            value = reportedValue;
    }

    implicitHeight: 28
    padding: 6
    hoverEnabled: true
    snapMode: Controls.Slider.SnapAlways
    Component.onCompleted: syncValue()
    onReportedValueChanged: syncValue()
    onPressedChanged: syncValue()

    background: Rectangle {
        x: root.leftPadding
        y: root.topPadding + (root.availableHeight - height) / 2
        width: root.availableWidth
        height: 4
        radius: 2
        color: Theme.hover

        Rectangle {
            width: root.visualPosition * parent.width
            height: parent.height
            radius: 2
            color: root.accent
        }

        Rectangle {
            visible: root.markerValue >= root.from && root.markerValue <= root.to
            x: (root.markerValue - root.from) / (root.to - root.from) * parent.width - width / 2
            y: -2
            width: 1
            height: 8
            color: Theme.muted
        }

    }

    handle: Rectangle {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + (root.availableHeight - height) / 2
        implicitWidth: 12
        implicitHeight: 12
        radius: 6
        color: root.pressed || root.hovered ? root.accent : Theme.foreground
        border.width: root.visualFocus ? 2 : 0
        border.color: root.accent
    }

}
