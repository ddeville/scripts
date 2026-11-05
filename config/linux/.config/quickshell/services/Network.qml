import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property var state: ({
        "available": false,
        "enabled": false,
        "device": "",
        "current": null,
        "networks": [],
        "wired": []
    })
    property string message: ""
    property bool failed: false
    readonly property bool busy: action.running
    readonly property var wiredConnection: state.wired.find(connection => connection.connected) ?? null

    function refresh() {
        poll.refresh();
    }

    function run(args, description) {
        if (busy)
            return ;

        message = description;
        failed = false;
        action.command = ["nmcli", "--wait", "30"].concat(args);
        action.running = true;
    }

    CommandPoll {
        id: poll

        command: ["python3", Quickshell.shellPath("services/scripts/network.py")]
        interval: 5000
        onOutputChanged: {
            if (output !== "")
                root.state = JSON.parse(output);

        }
    }

    Process {
        id: action

        environment: ({
            "LC_ALL": "C"
        })
        onExited: (code, status) => {
            root.failed = code !== 0 || status !== 0;
            root.message = root.failed ? (errors.text.trim() || "Network action failed") : "";
            poll.refresh();
        }

        stdout: StdioCollector {
        }

        stderr: StdioCollector {
            id: errors
        }

    }

}
