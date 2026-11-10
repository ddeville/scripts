pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import "LauncherSearch.js" as Search
import "../ui"

ShellPopup {
    id: root

    required property Launcher backend
    required property real screenHeight
    property int dismissKey: 0
    readonly property var matches: Search.search(backend.applications, search.text, backend.history)

    function moveSelection(delta) {
        if (results.count > 0) {
            results.currentIndex = (results.currentIndex + delta + results.count) % results.count;
            results.positionViewAtIndex(results.currentIndex, ListView.Contain);
        }
    }

    function activate() {
        if (results.currentIndex >= 0 && results.currentIndex < matches.length)
            backend.launch(matches[results.currentIndex]);
    }

    function isToggleShortcut(event) {
        return (event.modifiers === Qt.MetaModifier && (event.key === Qt.Key_D || event.key === Qt.Key_Space)) || (event.modifiers === Qt.ControlModifier && event.key === Qt.Key_Space);
    }

    implicitWidth: Math.min(540, anchorItem.width - 32)
    implicitHeight: Math.min(500, screenHeight - 80)
    popupX: (anchorItem.width - width) / 2
    popupY: anchorItem.height - (screenHeight + height) / 2
    padding: 16
    closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
    onOpened: {
        dismissKey = 0;
        backend.opened = true;
        search.clear();
        results.currentIndex = matches.length ? 0 : -1;
        results.positionViewAtBeginning();
        search.forceActiveFocus(Qt.ShortcutFocusReason);
    }
    onClosed: backend.opened = false
    onMatchesChanged: {
        results.currentIndex = matches.length ? 0 : -1;
        results.positionViewAtBeginning();
    }

    background: Rectangle {
        radius: 10
        color: Theme.background
        border.width: 1
        border.color: Theme.border
    }

    contentItem: Column {
        spacing: 12

        Controls.TextField {
            id: search

            width: parent.width
            height: 44
            placeholderText: "Search applications…"
            placeholderTextColor: Theme.muted
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: 16
            selectByMouse: true
            selectionColor: Theme.selected
            selectedTextColor: Theme.background
            leftPadding: 12
            rightPadding: 12
            Accessible.name: "Search applications"
            onAccepted: root.activate()
            Keys.onDownPressed: root.moveSelection(1)
            Keys.onUpPressed: root.moveSelection(-1)
            Keys.onTabPressed: root.moveSelection(1)
            Keys.onBacktabPressed: root.moveSelection(-1)
            Keys.onEscapePressed: root.dismissKey = Qt.Key_Escape
            Keys.onPressed: (event) => {
                if (root.isToggleShortcut(event)) {
                    root.dismissKey = event.key;
                    event.accepted = true;
                }
            }
            Keys.onReleased: (event) => {
                if (event.key === root.dismissKey) {
                    event.accepted = true;
                    if (!event.isAutoRepeat) {
                        root.dismissKey = 0;
                        root.close();
                    }
                }
            }

            background: Rectangle {
                radius: 6
                color: Theme.surface
                border.width: 1
                border.color: Theme.selected
            }
        }

        ListView {
            id: results

            width: parent.width
            height: root.availableHeight - search.height - hints.height - 24
            model: root.matches
            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0
            Controls.ScrollBar.vertical: Controls.ScrollBar {}

            delegate: Controls.ItemDelegate {
                id: result

                required property var modelData
                required property int index

                width: results.width
                height: 44
                padding: 7
                highlighted: ListView.isCurrentItem
                hoverEnabled: true
                focusPolicy: Qt.NoFocus
                Accessible.name: modelData.name
                onClicked: {
                    results.currentIndex = index;
                    root.backend.launch(modelData);
                }

                contentItem: Row {
                    spacing: 12

                    Image {
                        id: appIcon

                        width: 28
                        height: 28
                        anchors.verticalCenter: parent.verticalCenter
                        source: Quickshell.iconPath(result.modelData.icon, true)
                        sourceSize.width: 56
                        sourceSize.height: 56

                        Text {
                            anchors.centerIn: parent
                            visible: appIcon.status !== Image.Ready
                            text: result.modelData.name.slice(0, 1).toUpperCase()
                            color: Theme.muted
                            font.family: Theme.font
                            font.pixelSize: 20
                        }
                    }

                    Column {
                        width: parent.width - 40
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            width: parent.width
                            text: result.modelData.name
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: result.highlighted ? Theme.selected : Theme.foreground
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                        }

                        Text {
                            width: parent.width
                            text: result.modelData.genericName || result.modelData.comment
                            textFormat: Text.PlainText
                            visible: text !== ""
                            elide: Text.ElideRight
                            color: Theme.muted
                            font.family: Theme.font
                            font.pixelSize: 9
                        }
                    }
                }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }

                background: Rectangle {
                    radius: 6
                    color: result.highlighted ? Theme.selectionSurface : result.hovered ? Theme.hover : "transparent"
                }
            }

            Text {
                anchors.centerIn: parent
                visible: results.count === 0
                text: search.text.trim() ? "No matching applications" : "No applications found"
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
            }
        }

        Row {
            id: hints

            width: parent.width

            Text {
                width: parent.width - count.implicitWidth
                text: "↑↓ Select   Enter Open   Esc Close"
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 9
            }

            Text {
                id: count

                text: root.matches.length + (root.matches.length === 1 ? " app" : " apps")
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 9
            }
        }
    }
}
