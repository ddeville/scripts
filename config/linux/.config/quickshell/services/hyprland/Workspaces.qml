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
            occupied: workspace.toplevels.values.length > 0,
            urgent: workspace.urgent
        }))

    function focus(id) {
        Hyprland.dispatch("hl.dsp.focus({ workspace = " + Number(id) + " })");
    }
}
