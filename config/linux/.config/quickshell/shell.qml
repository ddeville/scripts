import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "bar"
import "launcher"
import "services"

ShellRoot {
    id: root

    readonly property bool preview: Quickshell.env("QS_BAR_PREVIEW") === "1"
    readonly property var sink: Pipewire.defaultAudioSink

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    SystemStatus {
        id: systemStatus

        offline: Quickshell.env("QS_BAR_OFFLINE") === "1"
    }

    Bspwm {
        id: bspwmService
    }

    Launcher {
        id: launcherService
    }

    Network {
        id: networkService
    }

    Notifications {
        id: notificationService
    }

    AudioOutputs {
        id: outputService

        enabled: true
    }

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData

            screen: modelData
            preview: root.preview
            date: clock.date
            status: systemStatus
            bspwm: bspwmService
            launcher: launcherService
            network: networkService
            notifications: notificationService
            audioOutputs: outputService
            audio: root.sink ? root.sink.audio : null
        }
    }
}
