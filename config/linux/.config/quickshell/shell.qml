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
    property real downloadRate: 0
    property real uploadRate: 0
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink ? sink.audio : null
    property int pendingBrightness: -1

    function command(args) {
        Quickshell.execDetached(args);
    }

    function networkRate(bytes) {
        if (bytes >= 1048576)
            return (bytes / 1048576).toFixed(bytes < 10485760 ? 1 : 0) + "M";
        return Math.round(bytes / 1024) + "K";
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Bspwm {
        id: bspwm
    }

    Network {
        id: network
    }

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    Process {
        id: brightnessAction
    }

    Timer {
        interval: 60
        repeat: true
        running: root.pendingBrightness >= 0
        onTriggered: {
            if (!brightnessAction.running) {
                brightnessAction.command = ["brightnessctl", "set", root.pendingBrightness + "%"];
                root.pendingBrightness = -1;
                brightnessAction.running = true;
            }
        }
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
            const elapsed = next.uptime - (root.stats.uptime ?? next.uptime);
            let received = 0;
            let sent = 0;
            if (elapsed > 0 && elapsed < 10) {
                for (const device in next.network) {
                    const previous = root.stats.network?.[device];
                    if (previous) {
                        received += Math.max(0, next.network[device][0] - previous[0]) / elapsed;
                        sent += Math.max(0, next.network[device][1] - previous[1]) / elapsed;
                    }
                }
            }
            root.downloadRate = received;
            root.uploadRate = sent;
            root.stats = next;
        }
    }

    Notifications {
        id: notifications
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

            screen: modelData
            implicitHeight: Theme.height
            color: Theme.background
            // X11 reserves physical pixels; Wayland reserves logical pixels.
            exclusiveZone: Math.round(implicitHeight * (Quickshell.env("XDG_SESSION_TYPE") === "x11" ? devicePixelRatio : 1))
            exclusionMode: root.preview ? ExclusionMode.Ignore : ExclusionMode.Normal

            anchors {
                left: true
                right: true
                top: root.preview
                bottom: !root.preview
            }

            SessionPopup {
                id: sessionPopup

                anchorItem: powerButton
                below: root.preview
                onActionRequested: (action) => {
                    if (action === "lock")
                        root.command(["loginctl", "lock-session", Quickshell.env("XDG_SESSION_ID")]);
                    else
                        root.command(["systemctl", action]);
                }
            }

            DevicePopup {
                id: devicePopup

                anchorItem: deviceControls
                below: root.preview
                audio: root.audio
                brightness: root.stats.backlight ?? -1
                battery: root.stats.battery ?? -1
                plugged: root.stats.plugged ?? false
                batteryStatus: root.stats.batteryStatus ?? ""
                onBrightnessRequested: (percent) => {
                    return root.pendingBrightness = percent;
                }
                onMixerRequested: root.command(["pavucontrol"])
            }

            NetworkPopup {
                id: networkPopup
                anchorItem: wifiButton
                below: root.preview
                backend: network
                onSettingsRequested: root.command(["nm-connection-editor"])
            }

            CalendarPopup {
                id: calendarPopup

                anchorItem: clockButton
                below: root.preview
                today: clock.date
            }

            NotificationPopup {
                id: notificationPopup
                anchorItem: notificationButton
                below: root.preview
                backend: notifications
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                y: root.preview ? parent.height - height : 0
                height: 1
                color: Theme.border
            }

            RowLayout {
                spacing: 8

                anchors {
                    fill: parent
                    leftMargin: 10
                    rightMargin: 10
                }

                StatusGroup {
                    Layout.minimumWidth: implicitWidth

                    BarButton {
                        id: clockButton

                        caption: Qt.formatDateTime(clock.date, "ddd d MMM").toUpperCase()
                        text: Qt.formatDateTime(clock.date, "h:mm AP")
                        textWidth: 60
                        interactive: true
                        active: calendarPopup.visible
                        onClicked: calendarPopup.visible = !calendarPopup.visible
                    }

                }

                BarDivider {
                    Layout.alignment: Qt.AlignVCenter
                    visible: workspaces.width > 0
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
                }

                Item {
                    Layout.preferredWidth: rightGroup.implicitWidth
                    Layout.minimumWidth: rightGroup.implicitWidth
                    Layout.fillHeight: true

                    Row {
                        id: rightGroup

                        spacing: 8

                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }

                        StatusGroup {
                            id: machineStatus

                            visible: panel.width >= 1150

                            BarButton {
                                id: networkStatus

                                caption: "NET"
                                stacked: true
                                tooltip: "Download: " + (root.downloadRate / 1024).toFixed(1) + " KiB/s\nUpload: " + (root.uploadRate / 1024).toFixed(1) + " KiB/s\n" + (Object.keys(root.stats.network ?? {}).join(", ") || "No active physical link")
                                indicator: Row {
                                    spacing: 8

                                    Repeater {
                                        model: [{ arrow: "↓", rate: root.downloadRate }, { arrow: "↑", rate: root.uploadRate }]
                                        delegate: Row {
                                            required property var modelData
                                            spacing: 3
                                            Text {
                                                text: modelData.arrow
                                                color: Theme.muted
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontSize
                                            }
                                            Text {
                                                text: root.networkRate(modelData.rate)
                                                color: Theme.foreground
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontSize
                                            }
                                        }
                                    }
                                }
                            }

                            BarButton {
                                caption: "CPU"
                                stacked: true
                                text: root.cpu + "%"
                                textWidth: 30
                            }

                            BarButton {
                                caption: "MEM"
                                stacked: true
                                text: (root.stats.memory ?? 0) + "%"
                                textWidth: 30
                            }

                            BarButton {
                                visible: typeof root.stats.temperature === "number"
                                caption: "TEMP"
                                stacked: true
                                text: root.stats.temperature + "°F"
                                textWidth: 38
                                foreground: root.stats.temperature >= 140 ? Theme.alert : Theme.foreground
                            }

                        }

                        BarDivider {
                            visible: machineStatus.visible && accountStatus.visible
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StatusGroup {
                            id: accountStatus

                            visible: !root.offline && panel.width >= 1000

                            BarButton {
                                visible: github.output !== ""
                                glyph: "\uf09b"
                                glyphSize: 14
                                tooltip: github.output === "offline" ? "GitHub check unavailable" : "GitHub: " + github.output + " unread notifications"
                                foreground: github.output === "offline" ? Theme.alert : Number.parseInt(github.output) > 0 ? Theme.selected : Theme.muted
                                interactive: true
                                onClicked: root.command(["xdg-open", "https://github.com/notifications"])
                            }

                            BarButton {
                                visible: email.output !== ""
                                symbol: "mail"
                                tooltip: email.output === "offline" ? "Email check unavailable" : "Mail: " + email.output + " unread messages"
                                foreground: email.output === "offline" ? Theme.alert : Number.parseInt(email.output) > 0 ? Theme.selected : Theme.muted
                                interactive: true
                                onClicked: root.command(["xdg-open", "https://app.fastmail.com/"])
                            }

                            BarButton {
                                symbol: "updates"
                                tooltip: updates.output === "unavailable" ? "Package check failed · click to retry" : updates.output === "" ? "Checking for updates…" : updates.output + " package updates · click to refresh"
                                foreground: updates.output === "unavailable" ? Theme.alert : Number.parseInt(updates.output) > 0 ? Theme.selected : Theme.muted
                                interactive: true
                                onClicked: updates.refresh()
                            }

                        }

                        BarDivider {
                            visible: accountStatus.visible
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StatusGroup {
                            id: deviceControls

                            BarButton {
                                id: wifiButton
                                symbol: "wifi"
                                level: network.state.current ? network.state.current.signal / 100 : 0
                                muted: !network.state.enabled
                                foreground: network.failed || !network.state.available ? Theme.alert : network.state.current ? Theme.foreground : Theme.muted
                                tooltip: network.message || (!network.state.available ? "NetworkManager unavailable" : !network.state.enabled ? "Wi-Fi off" : network.state.current ? network.state.current.ssid + " · " + network.state.current.signal + "% signal" : "Wi-Fi · Not connected")
                                tooltipEnabled: !networkPopup.visible
                                interactive: true
                                active: networkPopup.visible
                                onClicked: networkPopup.visible = !networkPopup.visible
                            }

                            BarButton {
                                visible: typeof root.stats.battery === "number"
                                symbol: "battery"
                                level: (root.stats.battery ?? 0) / 100
                                plugged: root.stats.plugged ?? false
                                tooltip: "Battery: " + root.stats.battery + "% · " + (root.stats.plugged ? "Plugged in" : "On battery")
                                tooltipEnabled: !devicePopup.visible
                                foreground: root.stats.battery <= 10 ? Theme.alert : Theme.foreground
                                interactive: true
                                active: devicePopup.visible && devicePopup.activeSection === "battery"
                                onClicked: devicePopup.toggleSection("battery")
                            }

                            BarButton {
                                visible: typeof root.stats.backlight === "number" && panel.width >= 900
                                symbol: "sun"
                                tooltip: "Brightness: " + root.stats.backlight + "%"
                                tooltipEnabled: !devicePopup.visible
                                interactive: true
                                active: devicePopup.visible && devicePopup.activeSection === "brightness"
                                onClicked: devicePopup.toggleSection("brightness")
                                onScrolled: (delta) => {
                                    if (delta !== 0)
                                        root.command(["brightnessctl", "set", delta > 0 ? "+5%" : "5%-"]);

                                }
                            }

                            BarButton {
                                symbol: "volume"
                                level: root.audio ? root.audio.volume : 0
                                muted: !root.audio || root.audio.muted
                                tooltip: !root.audio ? "No audio output" : "Volume: " + Math.round(root.audio.volume * 100) + "%" + (root.audio.muted ? " · Muted" : "")
                                tooltipEnabled: !devicePopup.visible
                                foreground: root.audio && root.audio.muted ? Theme.muted : root.audio && root.audio.volume > 1 ? Theme.alert : Theme.foreground
                                interactive: true
                                active: devicePopup.visible && devicePopup.activeSection === "volume"
                                onClicked: (button) => {
                                    if (button === Qt.RightButton)
                                        root.command(["pavucontrol"]);
                                    else if (button === Qt.MiddleButton && root.audio)
                                        root.audio.muted = !root.audio.muted;
                                    else if (button === Qt.LeftButton)
                                        devicePopup.toggleSection("volume");
                                }
                                onScrolled: (delta) => {
                                    if (root.audio && delta !== 0)
                                        root.audio.volume = Math.max(0, Math.min(1.5, root.audio.volume + (delta > 0 ? 0.01 : -0.01)));

                                }
                            }

                        }

                        BarDivider {
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StatusGroup {
                            BarButton {
                                id: notificationButton
                                symbol: notifications.paused ? "bell-off" : "bell"
                                foreground: !notifications.available || notifications.error !== "" ? Theme.alert : notifications.paused ? Theme.muted : Theme.selected
                                tooltip: notifications.summary + " · Click to manage"
                                tooltipEnabled: !notificationPopup.visible
                                active: notificationPopup.visible
                                interactive: true
                                onClicked: (button) => {
                                    if (button === Qt.LeftButton)
                                        notificationPopup.visible = !notificationPopup.visible;

                                }
                            }

                            BarButton {
                                id: powerButton

                                symbol: "power"
                                tooltip: "Session controls"
                                tooltipEnabled: !sessionPopup.visible
                                active: sessionPopup.visible
                                interactive: true
                                onClicked: (button) => {
                                    if (button === Qt.LeftButton)
                                        sessionPopup.visible = !sessionPopup.visible;

                                }
                            }

                        }

                        StatusGroup {
                            visible: trayRow.implicitWidth > 0

                            Row {
                                id: trayRow

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

}
