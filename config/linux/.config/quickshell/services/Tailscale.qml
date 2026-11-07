import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property var state: ({
            "installed": false,
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
        poll.refresh();
    }

    function run(args, description) {
        if (busy)
            return;
        message = description;
        failed = false;
        loginUrl = "";
        action.command = ["tailscale"].concat(args);
        action.running = true;
    }

    function setConnected(connected) {
        run(connected ? ["up", "--timeout=30s"] : ["down"], connected ? "Connecting…" : "Disconnecting…");
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

    CommandPoll {
        id: poll

        command: ["python3", Quickshell.shellPath("services/scripts/tailscale-status.py")]
        interval: 5000
        onOutputChanged: {
            if (output !== "")
                root.state = JSON.parse(output);
            else
                root.state = Object.assign({}, root.state, {
                    available: false,
                    connected: false,
                    error: "Could not read Tailscale status"
                });
        }
    }

    Process {
        id: action

        onExited: (code, status) => {
            root.failed = code !== 0 || status !== 0;
            root.message = root.failed ? (errors.text.trim() || "Tailscale action failed") : "";
            poll.refresh();
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
