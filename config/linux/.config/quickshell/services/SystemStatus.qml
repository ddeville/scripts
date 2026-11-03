import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property bool offline: false
    property int pendingBrightness: -1
    readonly property string updates: updatesPoll.output
    readonly property string email: emailPoll.output
    readonly property string github: githubPoll.output
    property var stats: ({
    })
    property var previousCpu: null
    property int cpu: 0
    property real downloadRate: 0
    property real uploadRate: 0

    function setBrightness(percent) {
        pendingBrightness = percent;
    }

    function refreshUpdates() {
        updatesPoll.refresh();
    }

    Process {
        id: brightnessAction
    }

    Timer {
        interval: 60
        repeat: true
        running: root.pendingBrightness >= 0
        onTriggered: {
            if (!brightnessAction.running) {
                brightnessAction.command = ["brightnessctl", "set", root.pendingBrightness + "%"];
                root.pendingBrightness = -1;
                brightnessAction.running = true;
            }
        }
    }

    CommandPoll {
        command: ["bash", Quickshell.shellPath("services/scripts/status.sh"), "stats"]
        interval: 1000
        onOutputChanged: {
            if (output === "")
                return ;

            const next = JSON.parse(output);
            if (root.previousCpu && next.cpu[0] > root.previousCpu[0])
                root.cpu = Math.round(100 * (1 - (next.cpu[1] - root.previousCpu[1]) / (next.cpu[0] - root.previousCpu[0])));

            root.previousCpu = next.cpu;
            const elapsed = next.uptime - (root.stats.uptime ?? next.uptime);
            let received = 0;
            let sent = 0;
            if (elapsed > 0 && elapsed < 10) {
                for (const device in next.network) {
                    const previous = root.stats.network?.[device];
                    if (previous) {
                        received += Math.max(0, next.network[device][0] - previous[0]) / elapsed;
                        sent += Math.max(0, next.network[device][1] - previous[1]) / elapsed;
                    }
                }
            }
            root.downloadRate = received;
            root.uploadRate = sent;
            root.stats = next;
        }
    }

    CommandPoll {
        id: updatesPoll

        enabled: !root.offline
        command: ["bash", Quickshell.shellPath("services/scripts/status.sh"), "updates"]
        interval: 300000
    }

    CommandPoll {
        id: emailPoll

        enabled: !root.offline
        command: ["bash", Quickshell.shellPath("services/scripts/status.sh"), "email"]
        interval: 60000
    }

    CommandPoll {
        id: githubPoll

        enabled: !root.offline
        command: ["bash", Quickshell.shellPath("services/scripts/status.sh"), "github"]
        interval: 60000
    }

}
