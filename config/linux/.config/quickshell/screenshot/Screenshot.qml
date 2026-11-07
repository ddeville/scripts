import QtQuick
import Quickshell
import Quickshell.Io
import "../services"

Scope {
    id: root

    property string saveDirectory: Quickshell.env("HOME") + "/screenshots"
    property string imagePath: ""
    property string savedPath: ""
    property string message: ""
    property string error: ""
    property string mode: "region"
    property string actionName: ""
    // A closing popup may still refer to the capture being replaced.
    property int captureId: 0
    property bool discardAfterAction: false
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
        discardAfterAction = false;
    }

    function dismiss(shownCaptureId) {
        if (shownCaptureId !== captureId)
            return;
        if (action.running)
            discardAfterAction = true;
        else
            discard();
    }

    // prepareCapture handlers call this when they hide a visible window.
    function waitForWindows() {
        captureDelay.restart();
    }

    function capture(nextMode) {
        if (busy || (nextMode !== "full" && nextMode !== "region"))
            return;
        captureId++;
        discard();
        error = "";
        message = "";
        mode = nextMode;
        prepareCapture();
        if (!captureDelay.running)
            captureProcess.running = true;
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
        Applications.launch(["xdg-open", path]);
    }

    IpcHandler {
        target: "screenshot"

        function capture(mode: string): void {
            root.capture(mode);
        }
    }

    Timer {
        id: captureDelay

        // Allow the popup windows to disappear before capturing the screen.
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
            if (root.discardAfterAction) {
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
                    root.openSaved();
            }
        }

        stdout: StdioCollector { id: actionOutput }
        stderr: StdioCollector { id: actionErrors }
    }

    FocusedMonitor {
        id: monitorQuery

        onResolved: name => root.showRequested(name)
    }
}
