import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property string saveDirectory: Quickshell.env("HOME") + "/data/Pictures/screenshots"
    property string imagePath: ""
    property string savedPath: ""
    property string message: ""
    property string error: ""
    property string mode: "region"
    property string actionName: ""
    property int revision: 0
    property bool discardWhenIdle: false
    readonly property bool busy: captureDelay.running || captureProcess.running || action.running || monitorQuery.running
    readonly property string helper: Quickshell.shellPath("services/scripts/screenshot.sh")

    signal prepareCapture()
    signal closeRequested()
    signal showRequested(string monitor)

    function discard() {
        if (imagePath !== "")
            Quickshell.execDetached(["bash", helper, "discard", imagePath]);
        imagePath = "";
        savedPath = "";
        discardWhenIdle = false;
    }

    function dismiss(shownRevision) {
        if (shownRevision !== revision)
            return;
        if (busy)
            discardWhenIdle = true;
        else
            discard();
    }

    function capture(nextMode) {
        if (busy || (nextMode !== "full" && nextMode !== "region"))
            return;
        revision++;
        closeRequested();
        discard();
        error = "";
        message = "";
        mode = nextMode;
        prepareCapture();
        captureDelay.restart();
    }

    function perform(name) {
        if (busy || imagePath === "" || !["copy", "save", "open"].includes(name))
            return;
        error = "";
        message = "";
        if (name === "open" && savedPath !== "") {
            openSaved();
            return;
        }
        if (name === "save" && savedPath !== "")
            return;
        actionName = name;
        action.command = ["bash", helper, name === "copy" ? "copy" : "save", imagePath];
        if (name !== "copy")
            action.command = action.command.concat([saveDirectory]);
        action.running = true;
    }

    function openSaved() {
        const path = savedPath;
        closeRequested();
        Quickshell.execDetached(["xdg-open", path]);
    }

    IpcHandler {
        target: "screenshot"

        function capture(mode: string): void {
            root.capture(mode);
        }
    }

    Timer {
        id: captureDelay

        interval: 100
        onTriggered: captureProcess.running = true
    }

    Process {
        id: captureProcess

        command: ["bash", root.helper, "capture", root.mode]
        onExited: (code, status) => {
            if (code === 2 && status === 0)
                return;
            if (code !== 0 || status !== 0 || captureOutput.text.trim() === "") {
                root.error = captureErrors.text.trim() || "Could not capture screenshot.";
                monitorQuery.running = true;
                return;
            }
            root.imagePath = captureOutput.text.trim();
            monitorQuery.running = true;
        }

        stdout: StdioCollector { id: captureOutput }
        stderr: StdioCollector { id: captureErrors }
    }

    Process {
        id: action

        onExited: (code, status) => {
            if (root.discardWhenIdle) {
                root.discard();
                return;
            }
            if (code !== 0 || status !== 0) {
                root.error = actionErrors.text.trim() || "Could not " + root.actionName + " screenshot.";
                return;
            }
            if (root.actionName === "copy") {
                root.message = "Copied to clipboard";
            } else {
                root.savedPath = actionOutput.text.trim();
                root.message = "Saved to " + root.savedPath;
                if (root.actionName === "open")
                    Qt.callLater(() => root.openSaved());
            }
        }

        stdout: StdioCollector { id: actionOutput }
        stderr: StdioCollector { id: actionErrors }
    }

    Process {
        id: monitorQuery

        command: ["timeout", "1", "bash", Quickshell.shellPath("services/scripts/focused-monitor.sh")]
        onExited: {
            const name = monitorOutput.text.trim();
            const screen = Quickshell.screens.find(screen => screen.name === name) || Quickshell.screens[0];
            if (screen)
                root.showRequested(screen.name);
        }

        stdout: StdioCollector { id: monitorOutput }
        stderr: StdioCollector {}
    }
}
