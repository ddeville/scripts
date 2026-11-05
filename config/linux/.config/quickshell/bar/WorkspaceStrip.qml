pragma ComponentBehavior: Bound

import QtQuick
import "../ui"
import "../services"

Row {
    id: root

    required property Workspaces backend
    required property string monitor

    // Preserve button instances when focus changes, including during a click.
    function sync() {
        const next = backend.workspaces.filter((workspace) => {
            return workspace.monitor === monitor;
        });
        for (let i = 0; i < next.length; ++i) {
            const workspace = next[i];
            const entry = {
                "desktopId": workspace.id,
                "label": workspace.name,
                "focused": workspace.focused,
                "occupied": workspace.occupied,
                "urgent": workspace.urgent
            };
            if (i >= desktops.count) {
                desktops.append(entry);
            } else if (desktops.get(i).desktopId === workspace.id) {
                desktops.set(i, entry);
            } else {
                desktops.remove(i);
                desktops.insert(i, entry);
            }
        }
        if (desktops.count > next.length)
            desktops.remove(next.length, desktops.count - next.length);

    }

    spacing: 2
    Component.onCompleted: sync()
    onMonitorChanged: sync()

    Connections {
        function onWorkspacesChanged() {
            root.sync();
        }

        target: root.backend
    }

    ListModel {
        id: desktops
    }

    Repeater {
        model: desktops

        delegate: Button {
            required property int desktopId
            required property string label
            required property bool focused
            required property bool occupied
            required property bool urgent

            text: label
            interactive: true
            foreground: urgent ? Theme.alert : focused ? Theme.selected : occupied ? Theme.foreground : Theme.emptyDesktop
            selected: focused
            onClicked: (button) => {
                if (button === Qt.LeftButton)
                    root.backend.focus(desktopId);

            }
            onScrolled: (delta) => {
                return root.backend.cycle(root.monitor, delta);
            }
        }

    }

}
