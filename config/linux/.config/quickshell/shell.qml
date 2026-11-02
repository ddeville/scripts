import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray

ShellRoot {
    id: root

    readonly property bool preview: Quickshell.env("QS_BAR_PREVIEW") === "1"
    readonly property bool offline: Quickshell.env("QS_BAR_OFFLINE") === "1"
    property var stats: ({
    })
    property var previousCpu: null
    property int cpu: 0
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink ? sink.audio : null
    property bool notificationsPaused: false

    function command(args) {
        Quickshell.execDetached(args);
    }

    function toggleNotifications() {
        if (notificationAction.running)
            return ;

        notificationsPaused = !notificationsPaused;
        notificationAction.command = ["dunstctl", "set-paused", notificationsPaused ? "true" : "false"];
        notificationAction.running = true;
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Bspwm {
        id: bspwm
    }

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    CommandPoll {
        command: ["bash", Quickshell.shellPath("scripts/status.sh"), "stats"]
        interval: 1000
        onOutputChanged: {
            if (output === "")
                return ;

            const next = JSON.parse(output);
            if (root.previousCpu && next.cpu[0] > root.previousCpu[0])
                root.cpu = Math.round(100 * (1 - (next.cpu[1] - root.previousCpu[1]) / (next.cpu[0] - root.previousCpu[0])));

            root.previousCpu = next.cpu;
            root.stats = next;
        }
    }

    CommandPoll {
        id: notifications

        command: ["timeout", "3", "dunstctl", "is-paused"]
        interval: 2000
        onOutputChanged: {
            if (!notificationAction.running)
                root.notificationsPaused = output === "true";

        }
    }

    Process {
        id: notificationAction

        onExited: (code, status) => {
            if (code !== 0 || status !== 0)
                root.notificationsPaused = notifications.output === "true";

            notifications.refresh();
        }
    }

    CommandPoll {
        id: updates

        enabled: !root.offline
        command: ["bash", Quickshell.shellPath("scripts/status.sh"), "updates"]
        interval: 300000
    }

    CommandPoll {
        id: email

        enabled: !root.offline
        command: ["bash", Quickshell.shellPath("scripts/status.sh"), "email"]
        interval: 60000
    }

    CommandPoll {
        id: github

        enabled: !root.offline
        command: ["bash", Quickshell.shellPath("scripts/status.sh"), "github"]
        interval: 60000
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel

            required property var modelData
            property bool powerOpen: false
            property string pendingPowerAction: ""

            function power(action) {
                if (pendingPowerAction === action) {
                    root.command(["systemctl", action]);
                    powerOpen = false;
                    pendingPowerAction = "";
                } else {
                    pendingPowerAction = action;
                }
            }

            screen: modelData
            implicitHeight: Theme.height
            color: Theme.background
            exclusionMode: root.preview ? ExclusionMode.Ignore : ExclusionMode.Auto

            anchors {
                left: true
                right: true
                top: root.preview
                bottom: !root.preview
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: Theme.border
            }

            RowLayout {
                spacing: 12

                anchors {
                    fill: parent
                    leftMargin: 10
                    rightMargin: 10
                }

                StatusGroup {
                    Layout.minimumWidth: implicitWidth
                    visible: workspaces.width > 0

                    WorkspaceStrip {
                        id: workspaces

                        backend: bspwm
                        monitor: panel.screen.name
                    }

                }

                Item {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 110
                    Layout.fillHeight: true

                    Column {
                        anchors.centerIn: parent
                        spacing: 0

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatDateTime(clock.date, "h:mm AP")
                            color: Theme.foreground
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            renderType: Text.QtRendering
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatDateTime(clock.date, "ddd · d MMM")
                            color: Theme.muted
                            font.family: Theme.font
                            font.pixelSize: 9
                            renderType: Text.QtRendering
                        }

                    }

                }

                Item {
                    Layout.preferredWidth: rightGroup.implicitWidth
                    Layout.minimumWidth: rightGroup.implicitWidth
                    Layout.fillHeight: true

                    Row {
                        id: rightGroup

                        spacing: 12

                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }

                        StatusGroup {
                            visible: !root.offline && panel.width >= 1000
                            color: "transparent"

                            BarButton {
                                visible: github.output !== ""
                                icon: "\uf09b"
                                iconFont: "Font Awesome 7 Brands"
                                text: github.output === "offline" ? "ERR" : github.output
                                foreground: github.output === "offline" ? Theme.alert : Number.parseInt(github.output) > 0 ? Theme.selected : Theme.muted
                                interactive: true
                                onClicked: root.command(["xdg-open", "https://github.com/notifications"])
                            }

                            BarButton {
                                visible: email.output !== ""
                                symbol: "mail"
                                text: email.output === "offline" ? "ERR" : email.output
                                foreground: email.output === "offline" ? Theme.alert : Number.parseInt(email.output) > 0 ? Theme.selected : Theme.muted
                                interactive: true
                                onClicked: root.command(["xdg-open", "https://app.fastmail.com/"])
                            }

                            BarButton {
                                symbol: "updates"
                                text: updates.output === "unavailable" ? "ERR" : updates.output || "…"
                                foreground: updates.output === "unavailable" ? Theme.alert : Number.parseInt(updates.output) > 0 ? Theme.selected : Theme.muted
                                interactive: true
                                onClicked: updates.refresh()
                            }

                        }

                        StatusGroup {
                            visible: !panel.powerOpen && panel.width >= 1150
                            color: "transparent"

                            Metric {
                                label: "CPU"
                                value: String(root.cpu).padStart(2, "0") + "%"
                            }

                            Metric {
                                label: "MEM"
                                value: (root.stats.memory ?? 0) + "%"
                            }

                            Metric {
                                visible: typeof root.stats.temperature === "number"
                                label: "TEMP"
                                value: root.stats.temperature + "°F"
                                alert: root.stats.temperature >= 140
                            }

                        }

                        StatusGroup {
                            visible: !panel.powerOpen

                            BarButton {
                                visible: typeof root.stats.battery === "number"
                                symbol: root.stats.plugged ? "plug" : "battery"
                                level: (root.stats.battery ?? 0) / 100
                                text: root.stats.battery + "%"
                                textWidth: 30
                                foreground: root.stats.battery <= 10 ? Theme.alert : Theme.foreground
                            }

                            BarButton {
                                visible: typeof root.stats.backlight === "number" && panel.width >= 900
                                symbol: "sun"
                                text: root.stats.backlight + "%"
                                textWidth: 30
                                interactive: true
                                onScrolled: (delta) => {
                                    if (delta !== 0)
                                        root.command(["brightnessctl", "set", delta > 0 ? "+5%" : "5%-"]);

                                }
                            }

                            BarButton {
                                symbol: "volume"
                                level: root.audio ? root.audio.volume : 0
                                muted: !root.audio || root.audio.muted
                                text: !root.audio ? "—" : root.audio.muted ? "Muted" : Math.round(root.audio.volume * 100) + "%"
                                textWidth: 38
                                foreground: root.audio && root.audio.muted ? Theme.muted : root.audio && root.audio.volume > 1 ? Theme.alert : Theme.foreground
                                interactive: true
                                onClicked: (button) => {
                                    if (button === Qt.RightButton)
                                        root.command(["pavucontrol"]);
                                    else if (button === Qt.LeftButton && root.audio)
                                        root.audio.muted = !root.audio.muted;
                                }
                                onScrolled: (delta) => {
                                    if (root.audio && delta !== 0)
                                        root.audio.volume = Math.max(0, Math.min(1.5, root.audio.volume + (delta > 0 ? 0.01 : -0.01)));

                                }
                            }

                        }

                        StatusGroup {
                            visible: panel.powerOpen

                            Repeater {
                                model: ["suspend", "reboot", "poweroff"]

                                delegate: BarButton {
                                    required property string modelData

                                    text: (panel.pendingPowerAction === modelData ? "Confirm " : "") + modelData
                                    foreground: Theme.alert
                                    interactive: true
                                    onClicked: (button) => {
                                        if (button === Qt.LeftButton)
                                            panel.power(modelData);

                                    }
                                }

                            }

                        }

                        StatusGroup {
                            BarButton {
                                symbol: root.notificationsPaused ? "bell-off" : "bell"
                                active: root.notificationsPaused
                                foreground: root.notificationsPaused ? Theme.selected : Theme.muted
                                interactive: true
                                onClicked: (button) => {
                                    if (button === Qt.LeftButton)
                                        root.toggleNotifications();

                                }
                            }

                            BarButton {
                                symbol: panel.powerOpen ? "close" : "power"
                                foreground: panel.powerOpen ? Theme.alert : Theme.muted
                                interactive: true
                                onClicked: (button) => {
                                    if (button === Qt.LeftButton) {
                                        panel.powerOpen = !panel.powerOpen;
                                        panel.pendingPowerAction = "";
                                    }
                                }
                            }

                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            Repeater {
                                model: SystemTray.items

                                delegate: Item {
                                    id: trayItem

                                    required property var modelData

                                    width: visible ? 24 : 0
                                    height: Theme.height - 10
                                    visible: modelData.status !== Status.Passive

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 5
                                        color: trayMouse.containsMouse ? Theme.hover : "transparent"
                                    }

                                    Image {
                                        anchors.centerIn: parent
                                        width: Theme.iconSize
                                        height: Theme.iconSize
                                        sourceSize.width: width * panel.devicePixelRatio
                                        sourceSize.height: height * panel.devicePixelRatio
                                        source: trayItem.modelData.icon
                                        fillMode: Image.PreserveAspectFit
                                    }

                                    MouseArea {
                                        id: trayMouse

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                        onClicked: (event) => {
                                            const item = trayItem.modelData;
                                            if (event.button === Qt.RightButton || item.onlyMenu) {
                                                const pos = trayItem.mapToItem(panel.contentItem, 0, 0);
                                                item.display(panel, pos.x, pos.y);
                                            } else if (event.button === Qt.MiddleButton) {
                                                item.secondaryActivate();
                                            } else {
                                                item.activate();
                                            }
                                        }
                                        onWheel: (event) => {
                                            return trayItem.modelData.scroll(event.angleDelta.y, false);
                                        }
                                    }

                                }

                            }

                        }

                    }

                }

            }

        }

    }

}
