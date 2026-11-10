pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../services"
import "LauncherSearch.js" as Search

Scope {
    id: root

    property bool opened: false
    readonly property var applications: DesktopEntries.applications.values
    readonly property var history: historyData.usage

    signal showRequested(string monitor)
    signal closeRequested()

    function toggle() {
        if (opened) {
            closeRequested();
        } else {
            showRequested(Hyprland.focusedMonitor?.name ?? Quickshell.screens[0]?.name ?? "");
        }
    }

    function launch(entry) {
        closeRequested();
        Applications.launch(Search.launchContext(entry, Quickshell.env("HOME")));
        const usage = Object.assign({}, historyData.usage);
        usage[entry.id] = {count: (usage[entry.id]?.count || 0) + 1, lastUsed: Date.now()};
        historyData.usage = usage;
        historyFile.writeAdapter();
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.toggle();
        }
    }

    Process {
        command: ["mkdir", "-p", Quickshell.stateDir]
        running: true
        onExited: (code) => {
            if (code === 0)
                historyFile.path = Quickshell.statePath("launcher-history.json");
        }
    }

    FileView {
        id: historyFile

        printErrors: false
        onSaveFailed: console.warn("Could not save launcher history")

        // Quickshell 0.3.2 omits the C++ namespace from FileView.adapter's type metadata.
        adapter: historyData // qmllint disable missing-type
    }

    JsonAdapter {
        id: historyData

        property var usage: ({})
    }
}
