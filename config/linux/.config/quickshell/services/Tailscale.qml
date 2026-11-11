import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    readonly property var emptyState: ({
            "available": false,
            "backend": "NoState",
            "connected": false,
            "account": "",
            "tailnet": "",
            "device": "",
            "address": "",
            "authUrl": "",
            "exitNode": null,
            "exitNodes": [],
            "peers": [],
            "profiles": [],
            "health": [],
            "error": ""
        })
    property var state: emptyState
    property string message: ""
    property string loginUrl: ""
    property bool failed: false
    readonly property bool busy: action.running
    readonly property bool usingExitNode: state.connected && !!state.exitNode
    readonly property bool warning: failed || !state.available || state.backend === "NeedsLogin" || state.backend === "NeedsMachineAuth" || (usingExitNode && !state.exitNode.online) || state.health.length > 0
    readonly property string statusText: {
        if (!state.available)
            return "Unavailable";
        if (state.backend === "NeedsLogin")
            return "Sign in required";
        if (state.backend === "NeedsMachineAuth")
            return "Device approval required";
        if (state.backend === "Starting")
            return "Connecting…";
        if (!state.connected)
            return "Disconnected";
        if (usingExitNode)
            return state.exitNode.online ? "Using exit node" : "Exit node offline";
        return "Connected";
    }
    readonly property string tooltip: ["Tailscale · " + statusText, state.tailnet, usingExitNode ? state.exitNode.name : "", message || state.error].filter(part => !!part).join("\n")

    function refresh() {
        watcher.running = true;
    }

    function unavailable(message) {
        state = Object.assign({}, emptyState, {
            backend: "Unavailable",
            error: message
        });
    }

    function run(args, description) {
        if (busy)
            return;
        message = description;
        failed = false;
        loginUrl = "";
        action.command = ["timeout", "--foreground", "30s", "tailscale"].concat(args);
        action.running = true;
    }

    function setConnected(connected) {
        // Only a flag-free `up` reconnects without revalidating saved preferences.
        run(connected ? ["up"] : ["down"], connected ? "Connecting…" : "Disconnecting…");
    }

    function selectExitNode(address) {
        run(["set", "--exit-node=" + address], address ? "Selecting exit node…" : "Disabling exit node…");
    }

    function switchAccount(id) {
        run(["switch", id], "Switching account…");
    }

    function openLogin() {
        const url = loginUrl || state.authUrl;
        if (url.startsWith("https://"))
            Applications.launch(["xdg-open", url]);
    }

    Process {
        id: watcher

        command: ["tailscale-status", "--watch"]
        running: true
        onExited: root.unavailable(watchErrors.text.trim() || "Tailscale status stopped. Retrying…")

        stdout: SplitParser {
            onRead: data => {
                try {
                    root.state = JSON.parse(data);
                } catch (error) {
                    root.unavailable("Could not read Tailscale status.");
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
            root.failed = code !== 0 || status !== 0;
            root.message = code === 124 ? "Tailscale timed out. Check the connection status and try again." : root.failed ? (errors.text.trim() || "Tailscale action failed") : "";
            root.refresh();
        }

        stdout: StdioCollector {}
        stderr: StdioCollector {
            id: errors
            waitForEnd: false

            onTextChanged: {
                const match = text.match(/https:\/\/[^\s]+/);
                if (match)
                    root.loginUrl = match[0];
            }
        }
    }
}
