pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking as Net
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import "../ui"
import "../services"
import "../launcher"
import "../screenshot"
import "popups"

// Quickshell chooses a concrete PanelWindow backend at runtime.
PanelWindow { // qmllint disable uncreatable-type
    id: panel

    required property SystemStatus status
    required property Workspaces workspaceService
    required property Launcher launcher
    required property Screenshot screenshot
    required property Network network
    required property Tailscale tailscale
    required property Notifications notifications
    required property Agents agents
    required property AudioOutputs audioOutputs
    required property date date
    property var audio: null
    // Quickshell's tray metadata leaves ObjectModel opaque to qmllint.
    readonly property var trayItems: SystemTray.items.values.filter(item => item.status !== Status.Passive && item.id !== "tailscale") // qmllint disable missing-property

    function command(args) {
        Quickshell.execDetached(args);
    }

    function networkRate(bytes) {
        if (bytes >= 1048576)
            return (bytes / 1048576).toFixed(bytes < 10485760 ? 1 : 0) + "M";
        return Math.round(bytes / 1024) + "K";
    }

    function closeOtherPopups(openingPopup) {
        let closed = false;
        for (const popup of [sessionPopup, devicePopup, networkPopup, tailscalePopup, calendarPopup, notificationPopup, agentsPopup, launcherPopup, screenshotPopup, trayPopup]) {
            if (popup !== openingPopup && popup.visible) {
                closed = true;
                popup.close();
            }
        }
        return closed;
    }

    implicitHeight: Theme.height
    color: Theme.background
    exclusiveZone: implicitHeight
    exclusionMode: ExclusionMode.Normal

    anchors {
        left: true
        right: true
        bottom: true
    }

    Connections {
        target: panel.launcher

        function onShowRequested(monitor) {
            panel.closeOtherPopups(null);
            // Quickshell 0.3.2 exports the window's screen type as opaque to qmllint.
            if (panel.screen.name === monitor) // qmllint disable missing-property
                launcherPopup.open();
        }

        function onCloseRequested() {
            launcherPopup.close();
        }
    }

    LauncherPopup {
        id: launcherPopup

        anchorItem: panel.contentItem
        backend: panel.launcher
        screenHeight: panel.screen.height // qmllint disable missing-property
        onAboutToShow: panel.closeOtherPopups(launcherPopup)
    }

    Connections {
        target: panel.screenshot

        function onPrepareCapture() {
            if (panel.closeOtherPopups(null))
                panel.screenshot.waitForWindows();
        }

        function onCloseRequested() {
            screenshotPopup.close();
        }

        function onShowRequested(monitor) {
            panel.closeOtherPopups(null);
            if (panel.screen.name === monitor) // qmllint disable missing-property
                screenshotPopup.open();
        }
    }

    ScreenshotPopup {
        id: screenshotPopup

        anchorItem: panel.contentItem
        backend: panel.screenshot
        screenHeight: panel.screen.height // qmllint disable missing-property
        onAboutToShow: panel.closeOtherPopups(screenshotPopup)
    }

    SessionPopup {
        id: sessionPopup

        anchorItem: powerButton
        onAboutToShow: panel.closeOtherPopups(sessionPopup)
        onActionRequested: (action) => {
            if (action === "lock")
                panel.command(["loginctl", "lock-session", Quickshell.env("XDG_SESSION_ID")]);
            else if (action === "logout")
                panel.command(["hyprctl", "eval", "hl.dispatch(hl.dsp.exit())"]);
            else
                panel.command(["systemctl", action]);
        }
    }

    QuickControlsPopup {
        id: devicePopup

        anchorItem: deviceControls
        onAboutToShow: panel.closeOtherPopups(devicePopup)
        audio: panel.audio
        outputs: panel.audioOutputs
        brightness: panel.status.stats.backlight ?? -1
        battery: UPower.displayDevice.ready && UPower.displayDevice.isPresent ? Math.round(UPower.displayDevice.percentage * 100) : -1
        plugged: !UPower.onBattery
        batteryStatus: UPowerDeviceState.toString(UPower.displayDevice.state)
        onBrightnessRequested: percent => panel.status.setBrightness(percent)
        onMixerRequested: Applications.launch(["pavucontrol"])
    }

    NetworkPopup {
        id: networkPopup
        anchorItem: wifiButton
        onAboutToShow: panel.closeOtherPopups(networkPopup)
        backend: panel.network
        onSettingsRequested: Applications.launch(["nm-connection-editor"])
    }

    TailscalePopup {
        id: tailscalePopup
        anchorItem: tailscaleButton
        backend: panel.tailscale
        onAboutToShow: panel.closeOtherPopups(tailscalePopup)
    }

    CalendarPopup {
        id: calendarPopup

        anchorItem: clockButton
        today: panel.date
        onVisibleChanged: {
            if (visible)
                panel.closeOtherPopups(calendarPopup);
        }
    }

    NotificationPopup {
        id: notificationPopup
        anchorItem: notificationButton
        onAboutToShow: panel.closeOtherPopups(notificationPopup)
        backend: panel.notifications
    }

    AgentsPopup {
        id: agentsPopup
        anchorItem: agentsButton
        backend: panel.agents
        onAboutToShow: panel.closeOtherPopups(agentsPopup)
    }

    TrayPopup {
        id: trayPopup

        anchorItem: trayButton
        items: panel.trayItems
        onAboutToShow: panel.closeOtherPopups(trayPopup)
        onMenuRequested: item => {
            const pos = trayButton.mapToItem(panel.contentItem, 0, 0);
            item.display(panel, pos.x, pos.y);
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        y: 0
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

            Button {
                id: clockButton

                caption: Qt.formatDateTime(panel.date, "ddd d MMM").toUpperCase()
                text: Qt.formatDateTime(panel.date, "h:mm AP")
                textWidth: 60
                active: calendarPopup.visible
                onClicked: calendarPopup.toggle()
            }

        }

        Divider {
            Layout.alignment: Qt.AlignVCenter
            visible: workspaces.width > 0
        }

        StatusGroup {
            Layout.minimumWidth: implicitWidth
            visible: workspaces.width > 0

            WorkspaceStrip {
                id: workspaces

                backend: panel.workspaceService
                monitor: panel.screen.name // qmllint disable missing-property
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

                    Button {
                        id: networkStatus

                        caption: "NET"
                        enabled: false
                        stacked: true
                        tooltip: "Download: " + (panel.status.downloadRate / 1024).toFixed(1) + " KiB/s\nUpload: " + (panel.status.uploadRate / 1024).toFixed(1) + " KiB/s\n" + (Object.keys(panel.status.stats.network ?? {}).join(", ") || "No active physical link")
                        leadingContent: Row {
                            spacing: 8

                            Repeater {
                                model: [{ arrow: "↓", rate: panel.status.downloadRate }, { arrow: "↑", rate: panel.status.uploadRate }]
                                delegate: Row {
                                    id: networkDirection

                                    required property var modelData
                                    spacing: 3
                                    Text {
                                        text: networkDirection.modelData.arrow
                                        color: Theme.muted
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize
                                    }
                                    Text {
                                        text: panel.networkRate(networkDirection.modelData.rate)
                                        color: Theme.foreground
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize
                                    }
                                }
                            }
                        }
                    }

                    Button {
                        caption: "CPU"
                        enabled: false
                        stacked: true
                        text: panel.status.cpu + "%"
                        textWidth: 30
                    }

                    Button {
                        caption: "MEM"
                        enabled: false
                        stacked: true
                        text: (panel.status.stats.memory ?? 0) + "%"
                        textWidth: 30
                    }

                    Button {
                        visible: typeof panel.status.stats.temperature === "number"
                        caption: "TEMP"
                        enabled: false
                        stacked: true
                        text: panel.status.stats.temperature + "°F"
                        textWidth: 38
                        foreground: panel.status.stats.temperature >= 140 ? Theme.alert : Theme.foreground
                    }

                }

                Divider {
                    visible: machineStatus.visible && accountStatus.visible
                    anchors.verticalCenter: parent.verticalCenter
                }

                StatusGroup {
                    id: accountStatus

                    visible: panel.width >= 1000

                    Button {
                        id: agentsButton

                        symbol: "agent"
                        foreground: ["working", "idle"].includes(panel.agents.indicatorState) ? Theme.foreground : panel.agents.color(panel.agents.indicatorState)
                        tooltip: panel.agents.tooltip
                        tooltipEnabled: !agentsPopup.visible
                        active: agentsPopup.visible
                        onClicked: agentsPopup.toggle()
                    }

                    Button {
                        visible: panel.status.github !== ""
                        glyph: "\uf09b"
                        glyphSize: 14
                        tooltip: panel.status.github === "offline" ? "GitHub check unavailable" : "GitHub: " + panel.status.github + " unread notifications"
                        foreground: panel.status.github === "offline" ? Theme.alert : Number.parseInt(panel.status.github) > 0 ? Theme.selected : Theme.foreground
                        onClicked: Applications.launch(["xdg-open", "https://github.com/notifications"])
                    }

                    Button {
                        visible: panel.status.email !== ""
                        symbol: "mail"
                        tooltip: panel.status.email === "offline" ? "Email check unavailable" : "Mail: " + panel.status.email + " unread messages"
                        foreground: panel.status.email === "offline" ? Theme.alert : Number.parseInt(panel.status.email) > 0 ? Theme.selected : Theme.foreground
                        onClicked: Applications.launch(["xdg-open", "https://app.fastmail.com/"])
                    }

                    Button {
                        symbol: "updates"
                        tooltip: panel.status.updates === "unavailable" ? "Package check failed · click to retry" : panel.status.updates === "" ? "Checking for updates…" : panel.status.updates + " package updates · click to refresh"
                        foreground: panel.status.updates === "unavailable" ? Theme.alert : Number.parseInt(panel.status.updates) > 0 ? Theme.selected : Theme.foreground
                        onClicked: panel.status.refreshUpdates()
                    }

                }

                Divider {
                    visible: accountStatus.visible
                    anchors.verticalCenter: parent.verticalCenter
                }

                StatusGroup {
                    id: deviceControls

                    Button {
                        id: tailscaleButton

                        tooltip: panel.tailscale.tooltip
                        tooltipEnabled: !tailscalePopup.visible
                        active: tailscalePopup.visible
                        onClicked: tailscalePopup.toggle()

                        leadingContent: Item {
                            width: Theme.iconSize
                            height: Theme.iconSize

                            TailscaleIcon {
                                anchors.fill: parent
                                connected: panel.tailscale.state.connected
                                exitNode: panel.tailscale.usingExitNode
                                exitNodeOnline: panel.tailscale.state.exitNode?.online ?? true
                            }

                            Rectangle {
                                visible: panel.tailscale.warning && !(panel.tailscale.usingExitNode && !panel.tailscale.state.exitNode.online)
                                anchors.right: parent.right
                                anchors.top: parent.top
                                width: 5
                                height: 5
                                radius: 2.5
                                color: Theme.alert
                                border.width: 1
                                border.color: Theme.background
                            }
                        }
                    }

                    Button {
                        id: wifiButton
                        symbol: panel.network.wiredConnection ? "ethernet" : "wifi"
                        level: panel.network.current ? panel.network.current.signalStrength : 0
                        muted: !Net.Networking.wifiEnabled && !panel.network.wiredConnection
                        foreground: panel.network.error !== "" || Net.Networking.backend === Net.NetworkBackendType.None ? Theme.alert : panel.network.wiredConnection || panel.network.current ? Theme.foreground : Theme.muted
                        tooltip: panel.network.message || (Net.Networking.backend === Net.NetworkBackendType.None ? "NetworkManager unavailable" : panel.network.wiredConnection ? "Ethernet · " + panel.network.wiredConnection.name : !Net.Networking.wifiEnabled ? "Wi-Fi off" : panel.network.current ? panel.network.current.name + " · " + Math.round(panel.network.current.signalStrength * 100) + "% signal" : "Wi-Fi · Not connected")
                        tooltipEnabled: !networkPopup.visible
                        active: networkPopup.visible
                        onClicked: networkPopup.toggle()
                    }

                    Button {
                        visible: UPower.displayDevice.ready && UPower.displayDevice.isPresent
                        symbol: "battery"
                        level: UPower.displayDevice.percentage
                        plugged: !UPower.onBattery
                        tooltip: "Battery: " + Math.round(UPower.displayDevice.percentage * 100) + "% · " + (UPower.onBattery ? "On battery" : "Plugged in")
                        tooltipEnabled: !devicePopup.visible
                        foreground: UPower.displayDevice.percentage <= 0.1 ? Theme.alert : Theme.foreground
                        active: devicePopup.visible && devicePopup.activeSection === "battery"
                        onClicked: devicePopup.toggleSection("battery")
                    }

                    Button {
                        visible: typeof panel.status.stats.backlight === "number" && panel.width >= 900
                        symbol: "sun"
                        tooltip: "Brightness: " + panel.status.stats.backlight + "%"
                        tooltipEnabled: !devicePopup.visible
                        active: devicePopup.visible && devicePopup.activeSection === "brightness"
                        onClicked: devicePopup.toggleSection("brightness")
                        wheelEnabled: true
                        onScrolled: (delta) => {
                            if (delta !== 0)
                                panel.command(["brightnessctl", "set", delta > 0 ? "+5%" : "5%-"]);

                        }
                    }

                    Button {
                        symbol: panel.audioOutputs.currentOutput && panel.audioOutputs.currentOutput.symbol === "headphones" ? "headphones" : "volume"
                        level: panel.audio ? panel.audio.volume : 0
                        muted: !panel.audio || panel.audio.muted
                        tooltip: !panel.audio ? "No audio output" : (panel.audioOutputs.currentOutput ? panel.audioOutputs.currentOutput.label : "Volume") + ": " + Math.round(panel.audio.volume * 100) + "%" + (panel.audio.muted ? " · Muted" : "")
                        tooltipEnabled: !devicePopup.visible
                        foreground: panel.audio && panel.audio.muted ? Theme.muted : panel.audio && panel.audio.volume > 1 ? Theme.alert : Theme.foreground
                        active: devicePopup.visible && devicePopup.activeSection === "volume"
                        onClicked: devicePopup.toggleSection("volume")
                        onSecondaryClicked: button => {
                            if (button === Qt.RightButton)
                                Applications.launch(["pavucontrol"]);
                            else if (button === Qt.MiddleButton && panel.audio)
                                panel.audio.muted = !panel.audio.muted;
                        }
                        wheelEnabled: true
                        onScrolled: (delta) => {
                            if (panel.audio && delta !== 0)
                                panel.audio.volume = Math.max(0, Math.min(1.5, panel.audio.volume + (delta > 0 ? 0.01 : -0.01)));

                        }
                    }

                }

                Divider {
                    anchors.verticalCenter: parent.verticalCenter
                }

                StatusGroup {
                    Button {
                        id: trayButton

                        symbol: "apps"
                        tooltip: "Application tray"
                        tooltipEnabled: !trayPopup.visible
                        active: trayPopup.visible
                        onClicked: trayPopup.toggle()
                    }

                    Button {
                        id: notificationButton
                        symbol: panel.notifications.paused ? "bell-off" : "bell"
                        foreground: !panel.notifications.available || panel.notifications.error !== "" ? Theme.alert : panel.notifications.paused ? Theme.muted : Theme.selected
                        tooltip: panel.notifications.summary + " · Click to manage"
                        tooltipEnabled: !notificationPopup.visible
                        active: notificationPopup.visible
                        onClicked: notificationPopup.toggle()
                    }

                    Button {
                        id: powerButton

                        symbol: "power"
                        tooltip: "Session controls"
                        tooltipEnabled: !sessionPopup.visible
                        active: sessionPopup.visible
                        onClicked: sessionPopup.toggle()
                    }

                }

            }

        }

    }

}
