import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property bool paused: false
    property real until: 0
    property bool available: false
    property string error: ""
    readonly property bool busy: action.running
    readonly property string summary: !available ? "Notifications unavailable" : !paused ? "Notifications on" : until > 0 ? "Paused until " + Qt.formatDateTime(new Date(until * 1000), "h:mm AP") : "Paused until you resume"

    function run(args) {
        if (busy)
            return ;

        error = "";
        action.command = ["bash", Quickshell.shellPath("scripts/notifications.sh")].concat(args);
        action.running = true;
    }

    CommandPoll {
        id: poll

        command: ["timeout", "5", "bash", Quickshell.shellPath("scripts/notifications.sh"), "status"]
        interval: 2000
        onOutputChanged: {
            root.available = output !== "";
            if (root.available) {
                const state = JSON.parse(output);
                root.paused = state.paused;
                root.until = state.until;
            }
        }
    }

    Process {
        id: action

        onExited: (code, status) => {
            if (code !== 0 || status !== 0)
                root.error = errors.text.trim() || "Could not change notification settings.";

            poll.refresh();
        }

        stderr: StdioCollector {
            id: errors
        }

    }

}
