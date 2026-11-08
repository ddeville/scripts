import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

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

    Process {
        id: statsProcess

        command: ["python3", Quickshell.shellPath("services/scripts/system-stats.py")]
        running: true

        stdout: SplitParser {
            onRead: data => {
                const next = JSON.parse(data);
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
    }

    Timer {
        interval: 1000
        running: !statsProcess.running
        repeat: true
        onTriggered: statsProcess.running = true
    }

    CommandPoll {
        id: updatesPoll

        command: ["bash", Quickshell.shellPath("services/scripts/status.sh"), "updates"]
        interval: 300000
    }

    CommandPoll {
        id: emailPoll

        command: ["bash", Quickshell.shellPath("services/scripts/status.sh"), "email"]
        interval: 60000
    }

    CommandPoll {
        id: githubPoll

        command: ["bash", Quickshell.shellPath("services/scripts/status.sh"), "github"]
        interval: 60000
    }

}
