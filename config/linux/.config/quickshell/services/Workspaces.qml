import QtQuick
import Quickshell

Scope {
    id: root

    readonly property var workspaces: backend.item ? backend.item.workspaces : []

    function focus(id) {
        if (backend.item)
            backend.item.focus(id);
    }

    function cycle(monitor, delta) {
        const desktops = workspaces.filter(workspace => workspace.monitor === monitor);
        const current = desktops.findIndex(workspace => workspace.focused);
        if (current >= 0 && delta !== 0)
            focus(desktops[(current + (delta > 0 ? -1 : 1) + desktops.length) % desktops.length].id);
    }

    Loader {
        id: backend

        source: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ? "hyprland/Workspaces.qml" : "Bspwm.qml"
    }
}
