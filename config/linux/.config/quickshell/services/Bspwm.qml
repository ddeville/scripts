import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property var workspaces: []
    property bool refreshPending: false
    property string lastSnapshot: ""
    readonly property bool enabled: Quickshell.env("XDG_SESSION_TYPE") !== "wayland" && Quickshell.env("DISPLAY") !== ""

    function focus(id) {
        Quickshell.execDetached(["bspc", "desktop", "-f", "0x" + Number(id).toString(16)]);
    }

    function refresh() {
        if (snapshot.running)
            refreshPending = true;
        else
            snapshot.running = true;
    }

    Process {
        id: snapshot

        command: ["bash", Quickshell.shellPath("services/scripts/status.sh"), "workspaces"]
        onExited: {
            if (root.refreshPending) {
                root.refreshPending = false;
                root.refresh();
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "" && text.trim() !== root.lastSnapshot) {
                    root.lastSnapshot = text.trim();
                    root.workspaces = JSON.parse(text);
                }
            }
        }

        stderr: StdioCollector {
        }

    }

    Process {
        id: events

        command: ["bspc", "subscribe", "report"]
        running: root.enabled
        onExited: {
            root.lastSnapshot = "";
            root.workspaces = [];
        }

        stdout: SplitParser {
            onRead: root.refresh()
        }

        stderr: StdioCollector {
        }

    }

    Timer {
        interval: 5000
        running: root.enabled
        repeat: true
        onTriggered: {
            if (!events.running)
                events.running = true;

        }
    }

}
