import QtQuick
import Quickshell
import Quickshell.Hyprland

Scope {
    readonly property var workspaces: Hyprland.workspaces.values
        .filter(workspace => workspace.id > 0 && workspace.monitor)
        .sort((a, b) => a.id - b.id)
        .map(workspace => ({
            id: workspace.id,
            name: workspace.name,
            monitor: workspace.monitor.name,
            focused: workspace.active,
            occupied: workspace.lastIpcObject.windows > 0,
            urgent: workspace.urgent
        }))

    // Window events use workspace IDs even when the displayed workspaces have names.
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            // Hyprland 0.57 reports workspace addresses in focusedmon, which Quickshell reads as names.
            if (event.name === "focusedmonv2")
                Hyprland.refreshMonitors();

            if (["openwindow", "closewindow", "movewindowv2"].includes(event.name))
                Hyprland.refreshWorkspaces();
        }
    }

    function focus(id) {
        Hyprland.dispatch("hl.dsp.focus({ workspace = " + Number(id) + " })");
    }
}
