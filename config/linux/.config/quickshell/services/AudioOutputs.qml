import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "AudioOutputs.js" as OutputData

Scope {
    id: root

    property bool available: false
    property string error: ""
    readonly property bool busy: selection.running
    readonly property bool loading: query.running && !available
    readonly property string defaultSinkName: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.name : ""
    property alias items: outputs
    property var outputData: []
    readonly property var currentOutput: outputData.find(output => output.sinkName === defaultSinkName && output.activePort) ?? null

    function refresh() {
        if (!query.running && !selection.running)
            query.running = true;

    }

    function select(sink, port) {
        if (busy)
            return ;

        error = "";
        selection.command = ["timeout", "5", "bash", Quickshell.shellPath("services/scripts/audio-output.sh"), sink, port];
        selection.running = true;
    }

    function sync(sinks) {
        const rows = OutputData.rowsForSinks(sinks);
        outputData = rows;
        for (let i = 0; i < rows.length; ++i) {
            if (i >= outputs.count) {
                outputs.append(rows[i]);
            } else if (outputs.get(i).key === rows[i].key) {
                outputs.set(i, rows[i]);
            } else {
                outputs.remove(i);
                outputs.insert(i, rows[i]);
            }
        }
        if (outputs.count > rows.length)
            outputs.remove(rows.length, outputs.count - rows.length);

    }

    Component.onCompleted: refresh()

    ListModel {
        id: outputs
    }

    Process {
        id: query

        command: ["timeout", "5", "pactl", "--format=json", "list", "sinks"]
        onExited: (code, status) => {
            root.available = code === 0 && status === 0;
            if (!root.available)
                root.sync([]);

        }

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    root.sync(JSON.parse(text));

            }
        }

    }

    Process {
        id: selection

        onExited: (code, status) => {
            if (code !== 0 || status !== 0)
                root.error = errors.text.trim() || "Could not switch audio output.";

            root.refresh();
        }

        stderr: StdioCollector {
            id: errors
        }

    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

}
