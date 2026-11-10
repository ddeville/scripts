import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root

    property var audio: null
    property string outputSymbol: "volume"
    property bool visible: false
    property string monitorName: ""
    property string kind: "volume"
    property string requestedKind: "volume"
    property int brightnessValue: 0
    property bool brightnessPending: false
    readonly property real value: kind === "brightness" ? brightnessValue : audio ? Math.round(audio.volume * 100) : 0
    readonly property bool muted: kind === "volume" && audio !== null && audio.muted
    readonly property string symbol: kind === "brightness" ? "sun" : outputSymbol === "headphones" ? "headphones" : "volume"
    readonly property string label: kind === "brightness" ? "Brightness" : muted ? "Volume · muted" : "Volume"

    function show(nextKind) {
        kind = nextKind;
        monitorName = Hyprland.focusedMonitor?.name ?? Quickshell.screens[0]?.name ?? "";
        visible = true;
        hideTimer.restart();
    }

    IpcHandler {
        target: "osd"

        function volume(): void {
            root.requestedKind = "volume";
            if (root.audio)
                root.show("volume");
        }

        function brightness(): void {
            root.requestedKind = "brightness";
            if (brightnessQuery.running)
                root.brightnessPending = true;
            else
                brightnessQuery.running = true;
        }
    }

    Process {
        id: brightnessQuery

        command: ["timeout", "1", "brightnessctl", "--class=backlight", "--machine-readable"]
        onExited: (code, status) => {
            const value = Number.parseInt(brightnessOutput.text.split(",")[3]);
            if (code === 0 && status === 0 && Number.isFinite(value) && root.requestedKind === "brightness") {
                root.brightnessValue = value;
                root.show("brightness");
            }
            if (root.brightnessPending) {
                root.brightnessPending = false;
                if (root.requestedKind === "brightness")
                    brightnessQuery.running = true;
            }
        }

        stdout: StdioCollector {
            id: brightnessOutput
        }

        stderr: StdioCollector {}
    }

    Timer {
        id: hideTimer

        interval: 1500
        onTriggered: root.visible = false
    }
}
