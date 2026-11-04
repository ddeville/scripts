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
    readonly property bool wayland: Quickshell.env("XDG_SESSION_TYPE") === "wayland"
    readonly property var anchorWindow: anchorItem.QsWindow.window
    property point anchorPosition: Qt.point(0, 0)
    readonly property var host: hostLoader.item

    function toggle() {
        if (visible)
            close();
        else
            open();
    }

    function open() {
        if (wayland) {
            anchorPosition = anchorItem.mapToItem(anchorWindow.contentItem, 0, 0);
            host.visible = true;
            Qt.callLater(() => {
                if (host.visible)
                    root.visible = true;
            });
        } else {
            visible = true;
        }
    }

    parent: wayland ? host?.contentItem ?? null : anchorItem
    x: wayland ? 0 : popupX
    y: wayland ? 0 : popupY
    padding: 0
    margins: -1
    popupType: wayland ? Controls.Popup.Item : Controls.Popup.Window
    focus: true
    closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutsideParent

    // Layer-shell positions are screen-relative and do not rely on X11 window coordinates.
    property Loader popupHostLoader: Loader {
        id: hostLoader

        active: root.wayland
        sourceComponent: PanelWindow {
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
                active: root.wayland && root.visible
                onCleared: root.close()
            }
        }
    }

    Connections {
        target: root

        function onClosed() {
            if (root.host)
                root.host.visible = false;
        }
    }
}
