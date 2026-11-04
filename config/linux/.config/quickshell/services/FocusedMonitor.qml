import Quickshell
import Quickshell.Io

Process {
    signal resolved(string name)

    command: ["timeout", "1", "bash", Quickshell.shellPath("services/scripts/focused-monitor.sh")]
    onExited: {
        const name = output.text.trim();
        const screen = Quickshell.screens.find(screen => screen.name === name) || Quickshell.screens[0];
        if (screen)
            resolved(screen.name);
    }

    stdout: StdioCollector { id: output }
    stderr: StdioCollector {}
}
