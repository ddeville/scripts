import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../ui"

Scope {
    id: root

    property bool available: false
    property var counts: ({})
    property string statusError: "Loading agents…"
    property string actionError: ""
    property Toplevel terminal: null
    property alias agents: agentModel
    // ObjectModel is opaque in Quickshell's installed QML metadata.
    readonly property var terminals: ToplevelManager.toplevels.values.filter(window => window.appId === "com.mitchellh.ghostty") // qmllint disable missing-property
    readonly property bool busy: action.running
    readonly property int attention: counts.attention ?? 0
    readonly property string indicatorState: !available ? "unavailable" : ["approval", "input", "error", "ready", "working"].find(state => (counts[state] ?? 0) > 0) || "idle"
    readonly property string summary: !available ? statusError : attention > 0 ? attention + " need your attention" : (counts.working ?? 0) > 0 ? counts.working + " working" : agentModel.count > 0 ? "All agents are idle" : "No agents running in tmux"
    readonly property string tooltip: "Agents · " + summary + (available && agentModel.count > 0 ? "\n" + agentModel.count + " agents · " + (counts.working ?? 0) + " working · " + (counts.ready ?? 0) + " unread" : "")

    signal agentOpened

    function label(state) {
        return ({
                approval: "Approve",
                input: "Reply",
                error: "Check error",
                ready: "Read result",
                working: "Working",
                idle: "Idle"
            })[state] || "Check status";
    }

    function color(state) {
        switch (state) {
        case "approval":
        case "input":
            return Theme.alert;
        case "error":
            return "#d485ad";
        case "ready":
            return Theme.primary;
        case "working":
            return Theme.tertiary;
        case "unavailable":
            return Theme.secondary;
        default:
            return Theme.muted;
        }
    }

    function syncAgents(next) {
        // Keep delegates alive across refreshes so clicks and focus are not interrupted.
        for (let i = 0; i < next.length; ++i) {
            const agent = next[i];
            let existing = i;
            while (existing < agentModel.count && agentModel.get(existing).threadId !== agent.id)
                ++existing;
            const row = {
                threadId: agent.id,
                agentType: agent.agent_type,
                title: agent.title,
                project: agent.project || agent.cwd,
                path: agent.cwd,
                status: agent.status,
                error: agent.error || "",
                section: agent.needs_attention ? "Needs you" : "Other agents"
            };
            if (existing === agentModel.count)
                agentModel.insert(i, row);
            else {
                if (existing !== i)
                    agentModel.move(existing, i, 1);
                agentModel.set(i, row);
            }
        }
        if (agentModel.count > next.length)
            agentModel.remove(next.length, agentModel.count - next.length);
    }

    function open(threadId) {
        if (busy || !available)
            return;
        actionError = "";
        if (terminals.length !== 1) {
            actionError = terminals.length === 0 ? "Open a Ghostty window attached to tmux first." : "More than one Ghostty window is open. Use the tmux picker to choose.";
            return;
        }
        terminal = terminals[0];
        action.command = ["tmux-agent-status", "open", threadId];
        action.running = true;
    }

    ListModel {
        id: agentModel
    }

    Process {
        id: watcher

        command: ["tmux-agent-status", "status", "--watch", "--interval", "1"]
        running: true
        onExited: {
            root.available = false;
            root.counts = {};
            root.syncAgents([]);
            root.statusError = watchErrors.text.trim() || "Agent status stopped. Retrying…";
        }

        stdout: SplitParser {
            onRead: data => {
                try {
                    const next = JSON.parse(data);
                    root.available = next.connection.status === "connected";
                    root.counts = root.available ? next.counts : {};
                    root.statusError = root.available ? "" : next.connection.error || "Agent status unavailable";
                    root.syncAgents(root.available ? next.agents : []);
                } catch (error) {
                    root.available = false;
                    root.counts = {};
                    root.syncAgents([]);
                    root.statusError = "Could not read agent status.";
                }
            }
        }
        stderr: StdioCollector {
            id: watchErrors
        }
    }

    Timer {
        interval: 2000
        running: !watcher.running
        repeat: true
        onTriggered: watcher.running = true
    }

    Process {
        id: action

        onExited: (code, status) => {
            if (code !== 0 || status !== 0) {
                root.actionError = actionErrors.text.trim() || "Could not open the agent.";
                root.terminal = null;
                return;
            }
            root.agentOpened();
            // Let the popup release its focus grab before activating Ghostty.
            Qt.callLater(() => {
                if (root.terminal)
                    root.terminal.activate();
                root.terminal = null;
            });
        }

        stdout: StdioCollector {}
        stderr: StdioCollector {
            id: actionErrors
        }
    }
}
