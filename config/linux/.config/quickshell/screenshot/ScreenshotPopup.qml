import QtQuick
import QtQuick.Controls as Controls
import "../ui"

ShellPopup {
    id: root

    required property Screenshot backend
    required property real screenHeight
    property int shownCaptureId: -1
    property bool escapePressed: false

    implicitWidth: Math.min(560, anchorItem.width - 32)
    implicitHeight: body.implicitHeight + 32
    popupX: (anchorItem.width - width) / 2
    popupY: anchorItem.height - (screenHeight + height) / 2
    padding: 16
    closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
    onOpened: {
        shownCaptureId = backend.captureId;
        escapePressed = false;
        if (backend.imagePath !== "")
            copyButton.forceActiveFocus(Qt.ShortcutFocusReason);
        else
            retryButton.forceActiveFocus(Qt.ShortcutFocusReason);
    }
    onClosed: backend.dismiss(shownCaptureId)

    background: Rectangle {
        radius: 10
        color: Theme.background
        border.width: 1
        border.color: Theme.border
    }

    contentItem: Column {
        id: body

        spacing: 12
        Keys.onEscapePressed: root.escapePressed = true
        Keys.onReleased: event => {
            if (event.key === Qt.Key_Escape && root.escapePressed) {
                event.accepted = true;
                root.escapePressed = false;
                root.close();
            }
        }
        Keys.onPressed: event => {
            if (event.modifiers === Qt.ControlModifier && (event.key === Qt.Key_C || event.key === Qt.Key_S)) {
                event.accepted = true;
                root.backend.perform(event.key === Qt.Key_C ? "copy" : "save");
            }
        }

        Row {
            width: parent.width

            Text {
                width: parent.width - closeButton.width
                anchors.verticalCenter: parent.verticalCenter
                text: "Screenshot"
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: 14
            }

            Button {
                id: closeButton

                symbol: "close"
                tooltip: "Close preview"
                foreground: Theme.muted
                interactive: true
                onClicked: root.close()
            }
        }

        Rectangle {
            visible: root.backend.imagePath !== ""
            width: parent.width
            height: Math.min(280, root.screenHeight - 220)
            radius: 6
            color: Theme.surface

            Image {
                anchors.fill: parent
                anchors.margins: 8
                source: root.backend.imagePath
                sourceSize.width: 1200
                sourceSize.height: 700
                fillMode: Image.PreserveAspectFit
                cache: false
            }
        }

        Row {
            visible: root.backend.imagePath !== ""
            width: parent.width
            spacing: 8

            Button {
                id: copyButton

                width: (parent.width - 16) / 3
                height: 34
                text: "Copy"
                tooltip: "Copy image · Ctrl+C"
                foreground: Theme.selected
                interactive: !root.backend.busy
                onClicked: root.backend.perform("copy")
            }

            Button {
                width: (parent.width - 16) / 3
                height: 34
                text: root.backend.savedPath ? "Saved" : "Save"
                tooltip: "Save to screenshots folder · Ctrl+S"
                foreground: root.backend.savedPath ? Theme.muted : Theme.foreground
                interactive: !root.backend.busy && root.backend.savedPath === ""
                onClicked: root.backend.perform("save")
            }

            Button {
                width: (parent.width - 16) / 3
                height: 34
                text: "Open"
                tooltip: root.backend.savedPath ? "Open saved screenshot" : "Save and open in image viewer"
                interactive: !root.backend.busy
                onClicked: root.backend.perform("open")
            }
        }

        Text {
            visible: text !== ""
            width: parent.width
            text: root.backend.error || (root.backend.busy ? "Working…" : root.backend.message)
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: root.backend.error ? Theme.alert : Theme.muted
            font.family: Theme.font
            font.pixelSize: 10
        }

        Button {
            id: retryButton

            visible: root.backend.imagePath === "" && root.backend.error !== ""
            text: "Try again"
            interactive: !root.backend.busy
            onClicked: root.backend.capture(root.backend.mode)
        }
    }
}
