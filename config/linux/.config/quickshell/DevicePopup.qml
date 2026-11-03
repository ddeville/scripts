import QtQuick
import QtQuick.Controls as Controls

Controls.Popup {
    id: root

    required property Item anchorItem
    property bool below: false
    property var audio: null
    property string audioName: ""
    property real brightness: -1
    property real battery: -1
    property bool plugged: false
    property string batteryStatus: ""

    signal brightnessRequested(int percent)
    signal mixerRequested()

    implicitWidth: 280
    implicitHeight: body.implicitHeight + 24
    parent: anchorItem
    x: anchorItem.width - width
    y: below ? anchorItem.height + 8 : -height - 8
    padding: 0
    margins: -1
    popupType: Controls.Popup.Window
    focus: true
    closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutsideParent

    Column {
        id: body

        x: 12
        y: 12
        width: root.width - 24
        spacing: 10

        Row {
            width: parent.width

            Text {
                width: parent.width - 28
                anchors.verticalCenter: parent.verticalCenter
                text: "Quick controls"
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: 14
                renderType: Text.QtRendering
            }

            BarButton {
                symbol: "close"
                foreground: Theme.muted
                interactive: true
                onClicked: root.close()
            }

        }

        Row {
            visible: root.battery >= 0
            width: parent.width
            spacing: 10

            BarIcon {
                name: "battery"
                level: root.battery / 100
                plugged: root.plugged
                implicitWidth: 24
                implicitHeight: 24
                color: root.battery <= 10 ? Theme.alert : Theme.foreground
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                spacing: 3

                Text {
                    text: root.battery + "% · " + (root.plugged ? "Plugged in" : "On battery")
                    color: Theme.foreground
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    renderType: Text.QtRendering
                }

                Text {
                    text: root.batteryStatus
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 9
                    renderType: Text.QtRendering
                }

            }

        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.border
        }

        Column {
            visible: root.brightness >= 0
            width: parent.width

            Row {
                width: parent.width

                BarButton {
                    symbol: "sun"
                }

                Text {
                    width: parent.width - 28 - brightnessValue.implicitWidth
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Brightness"
                    color: Theme.foreground
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    renderType: Text.QtRendering
                }

                Text {
                    id: brightnessValue

                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(brightnessSlider.value) + "%"
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    renderType: Text.QtRendering
                }

            }

            LevelSlider {
                id: brightnessSlider

                width: parent.width
                from: 1
                to: 100
                stepSize: 1
                reportedValue: root.brightness
                Accessible.name: "Display brightness"
                onMoved: root.brightnessRequested(Math.round(value))
            }

        }

        Column {
            width: parent.width

            Row {
                width: parent.width

                BarButton {
                    symbol: "volume"
                    level: root.audio ? root.audio.volume : 0
                    muted: !root.audio || root.audio.muted
                    foreground: root.audio && root.audio.muted ? Theme.muted : Theme.foreground
                    interactive: root.audio !== null
                    onClicked: root.audio.muted = !root.audio.muted
                }

                Text {
                    width: parent.width - 28 - volumeValue.implicitWidth
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.audio && root.audio.muted ? "Volume · muted" : "Volume"
                    color: Theme.foreground
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    renderType: Text.QtRendering
                }

                Text {
                    id: volumeValue

                    anchors.verticalCenter: parent.verticalCenter
                    text: root.audio ? Math.round(volumeSlider.value * 100) + "%" : "—"
                    color: root.audio && root.audio.volume > 1 ? Theme.alert : Theme.muted
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    renderType: Text.QtRendering
                }

            }

            LevelSlider {
                id: volumeSlider

                width: parent.width
                from: 0
                to: 1.5
                markerValue: 1
                stepSize: 0.01
                enabled: root.audio !== null
                reportedValue: root.audio ? root.audio.volume : 0
                accent: value > 1 ? Theme.alert : Theme.selected
                Accessible.name: "Output volume"
                onMoved: {
                    if (root.audio)
                        root.audio.volume = value;

                }
            }

            Item {
                width: parent.width
                height: 12

                Text {
                    x: 6 + (parent.width - 12) * 2 / 3 - width / 2
                    text: "100%"
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 8
                    renderType: Text.QtRendering
                }

            }

            Text {
                width: parent.width
                text: root.audioName || "No audio output"
                elide: Text.ElideRight
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 9
                renderType: Text.QtRendering
            }

        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.border
        }

        BarButton {
            text: "Sound settings…"
            foreground: Theme.muted
            interactive: true
            onClicked: {
                root.close();
                root.mixerRequested();
            }
        }

    }

    background: Rectangle {
        radius: 10
        color: Theme.background
        border.width: 1
        border.color: Theme.border
    }

}
