//@ pragma UseQApplication

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "bar"
import "launcher"
import "osd"
import "screenshot"
import "services"

ShellRoot {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    SystemStatus {
        id: systemStatus
    }

    Workspaces {
        id: desktopWorkspaces
    }

    Launcher {
        id: launcherService
    }

    Network {
        id: networkService
    }

    Tailscale {
        id: tailscaleService
    }

    Notifications {
        id: notificationService
    }

    Agents {
        id: agentsService
    }

    AudioOutputs {
        id: outputService
    }

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    Osd {
        id: osdService

        audio: root.sink ? root.sink.audio : null
        outputSymbol: outputService.currentOutput ? outputService.currentOutput.symbol : "volume"
    }

    Screenshot {
        id: screenshotService

        onPrepareCapture: {
            if (osdService.visible) {
                osdService.visible = false;
                screenshotService.waitForWindows();
            }
        }
    }

    Variants {
        model: Quickshell.screens

        OsdWindow {
            required property var modelData

            screen: modelData
            monitorName: modelData.name
            backend: osdService
        }
    }

    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData

            screen: modelData
            date: clock.date
            status: systemStatus
            workspaceService: desktopWorkspaces
            launcher: launcherService
            screenshot: screenshotService
            network: networkService
            tailscale: tailscaleService
            notifications: notificationService
            agents: agentsService
            audioOutputs: outputService
            audio: root.sink ? root.sink.audio : null
        }
    }
}
