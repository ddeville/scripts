import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property list<string> command
    property int interval: 3000
    property string output: ""
    property bool enabled: true

    function refresh() {
        if (enabled && !process.running)
            process.running = true;

    }

    Component.onCompleted: refresh()

    Process {
        id: process

        command: root.command
        onExited: (code, status) => {
            if (code !== 0 || status !== 0)
                root.output = "";

        }

        stdout: StdioCollector {
            onStreamFinished: root.output = text.trim()
        }

        stderr: StdioCollector {
        }

    }

    Timer {
        interval: root.interval
        running: root.enabled
        repeat: true
        onTriggered: root.refresh()
    }

}
