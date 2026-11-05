import QtQuick
import QtQuick.Controls as Controls
import "../../ui"
import "../../services"

ShellPopup {
    id: root

    required property AudioOutputs outputs
    property var audio: null
    property real brightness: -1
    property real battery: -1
    property bool plugged: false
    property string batteryStatus: ""
    property string activeSection: ""

    signal brightnessRequested(int percent)
    signal mixerRequested()

    function toggleSection(section) {
        if (visible && activeSection === section) {
            close();
            return ;
        }
        activeSection = section;
        if (!visible) {
            outputRows.forceLayout();
            body.forceLayout();
            open();
        }
    }

    implicitWidth: 280
    implicitHeight: body.implicitHeight + 24
    padding: 0
    closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutsideParent
    onOpened: {
        outputs.refresh();
        closeButton.forceActiveFocus(Qt.PopupFocusReason);
    }
    onClosed: {
        activeSection = "";
    }

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

            Button {
                id: closeButton

                symbol: "close"
                tooltip: "Close quick controls"
                foreground: Theme.muted
                interactive: true
                onClicked: root.close()
            }

        }

        Column {
            visible: root.battery >= 0
            width: parent.width

            Row {
                width: parent.width

                Button {
                    symbol: "battery"
                    level: root.battery / 100
                    plugged: root.plugged
                    foreground: root.battery <= 10 ? Theme.alert : Theme.foreground
                }

                Text {
                    width: parent.width - 28 - batteryValue.implicitWidth
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Battery"
                    color: Theme.foreground
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    renderType: Text.QtRendering
                }

                Text {
                    id: batteryValue

                    anchors.verticalCenter: parent.verticalCenter
                    text: root.battery + "%"
                    color: root.battery <= 10 ? Theme.alert : Theme.muted
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    renderType: Text.QtRendering
                }

            }

            Text {
                x: 28
                text: root.batteryStatus || (root.plugged ? "Plugged in" : "On battery")
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 9
                renderType: Text.QtRendering
            }

        }

        Rectangle {
            visible: root.battery >= 0
            width: parent.width
            height: 1
            color: Theme.border
        }

        Column {
            visible: root.brightness >= 0
            width: parent.width

            Row {
                width: parent.width

                Button {
                    symbol: "sun"
                }

                Text {
                    width: parent.width - 28 - brightnessValue.implicitWidth
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Display"
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

        Rectangle {
            visible: root.brightness >= 0
            width: parent.width
            height: 1
            color: Theme.border
        }

        Column {
            width: parent.width

            Row {
                width: parent.width

                Button {
                    symbol: "volume"
                    tooltip: root.audio && root.audio.muted ? "Unmute audio" : "Mute audio"
                    level: root.audio ? root.audio.volume : 0
                    muted: !root.audio || root.audio.muted
                    foreground: root.audio && root.audio.muted ? Theme.muted : Theme.foreground
                    interactive: root.audio !== null
                    onClicked: root.audio.muted = !root.audio.muted
                }

                Text {
                    width: parent.width - 28 - volumeValue.implicitWidth
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.audio && root.audio.muted ? "Sound · muted" : "Sound"
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

        }

        Text {
            text: "AUDIO OUTPUTS"
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: 9
            font.letterSpacing: 0.5
        }

        Controls.ScrollView {
            id: outputList

            width: parent.width
            implicitHeight: Math.min(outputRows.implicitHeight, 180)
            contentWidth: availableWidth
            clip: true
            Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff

            Column {
                id: outputRows

                width: parent.width
                spacing: 4

                Repeater {
                    model: outputs.items

                    delegate: Button {
                        id: outputButton

                        required property var model
                        readonly property bool current: root.outputs.defaultSinkName === model.sinkName && model.activePort

                        width: outputRows.width
                        height: model.detail ? 42 : 32
                        tooltip: model.description + (current ? " · Current output" : " · Use this output")
                        active: current && root.outputs.items.count > 1
                        foreground: active ? Theme.selected : Theme.foreground
                        interactive: root.outputs.available && !root.outputs.busy && (root.outputs.items.count > 1 || !current)
                        onClicked: outputs.select(model.sinkName, model.portName)
                        onActiveFocusChanged: {
                            if (activeFocus) {
                                const view = outputList.contentItem;
                                view.contentY = Math.max(0, Math.min(y, Math.max(view.contentY, y + height - view.height)));
                            }
                        }

                        indicator: Row {
                            spacing: 5

                            Icon {
                                name: outputButton.model.symbol
                                color: outputButton.foreground
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                width: outputButton.width - 33
                                spacing: 2

                                Text {
                                    width: parent.width
                                    text: outputButton.model.label
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    color: outputButton.foreground
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize
                                }

                                Text {
                                    visible: outputButton.model.detail !== ""
                                    width: parent.width
                                    text: outputButton.model.detail
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    color: Theme.muted
                                    font.family: Theme.font
                                    font.pixelSize: 9
                                }

                            }

                        }

                    }

                }

            }

        }

        Text {
            visible: outputs.items.count === 0 || outputs.error !== ""
            width: parent.width
            text: outputs.error || (outputs.loading ? "Checking audio outputs…" : !outputs.available ? "Audio outputs unavailable" : "No audio outputs")
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: outputs.error ? Theme.alert : Theme.muted
            font.family: Theme.font
            font.pixelSize: 10
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.border
        }

        Button {
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
