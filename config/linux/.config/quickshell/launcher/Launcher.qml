import QtQuick
import Quickshell
import Quickshell.Io
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
        } else if (!focusedMonitor.running) {
            focusedMonitor.running = true;
        }
    }

    function launch(entry) {
        closeRequested();
        Quickshell.execDetached(Search.launchContext(entry, Quickshell.env("HOME")));
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
        id: focusedMonitor

        command: ["bspc", "query", "-M", "-m", "focused", "--names"]
        onExited: {
            const name = monitorName.text.trim();
            const screen = Quickshell.screens.find(screen => screen.name === name) || Quickshell.screens[0];
            if (screen)
                root.showRequested(screen.name);
        }

        stdout: StdioCollector {
            id: monitorName
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

        JsonAdapter {
            id: historyData

            property var usage: ({})
        }
    }
}
