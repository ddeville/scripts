pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

Controls.Popup {
    id: root

    required property Item anchorItem
    property real popupX: anchorItem.width - width
    property real popupY: -height - 8
    readonly property var anchorWindow: anchorItem.QsWindow.window
    property point anchorPosition: Qt.point(0, 0)

    function toggle() {
        if (visible)
            close();
        else
            open();
    }

    function open() {
        anchorPosition = anchorItem.mapToItem(anchorWindow.contentItem, 0, 0);
        host.visible = true;
        Qt.callLater(() => {
            if (host.visible)
                root.visible = true;
        });
    }

    parent: host.contentItem
    x: 0
    y: 0
    padding: 0
    margins: -1
    popupType: Controls.Popup.Item
    focus: true
    closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutsideParent

    property PanelWindow host: PanelWindow {
        id: hostWindow

        readonly property bool shellPopup: true

        visible: false
        screen: root.anchorWindow?.screen ?? null
        anchors {
            left: true
            bottom: true
        }
        margins.left: Math.max(8, Math.min(root.anchorPosition.x + root.popupX, (screen?.width ?? 0) - implicitWidth - 8))
        margins.bottom: Math.max(8, (root.anchorWindow?.height ?? 0) - root.anchorPosition.y - root.popupY - implicitHeight)
        implicitWidth: root.implicitWidth
        implicitHeight: root.implicitHeight
        exclusionMode: ExclusionMode.Ignore
        focusable: true
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay

        HyprlandFocusGrab {
            windows: [hostWindow, root.anchorWindow]
            active: root.visible
            onCleared: root.close()
        }
    }

    Connections {
        target: root

        function onClosed() {
            root.host.visible = false;
        }
    }
}
