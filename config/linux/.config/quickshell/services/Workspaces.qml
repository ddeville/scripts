import QtQuick
import Quickshell
import "hyprland" as HyprlandBackend

Scope {
    id: root

    readonly property var workspaces: backend.workspaces

    function focus(id) {
        backend.focus(id);
    }

    function cycle(monitor, delta) {
        const desktops = workspaces.filter(workspace => workspace.monitor === monitor);
        const current = desktops.findIndex(workspace => workspace.focused);
        if (current >= 0 && delta !== 0)
            focus(desktops[(current + (delta > 0 ? -1 : 1) + desktops.length) % desktops.length].id);
    }

    HyprlandBackend.Workspaces {
        id: backend
    }
}
