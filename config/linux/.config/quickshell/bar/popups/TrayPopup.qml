pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import "../../ui"

ShellPopup {
    id: root

    required property var items

    signal menuRequested(var item)

    implicitWidth: 240
    implicitHeight: list.implicitHeight + 24
    padding: 12
    closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutsideParent
    onOpened: {
        if (entries.count > 0)
            entries.itemAt(0).forceActiveFocus(Qt.PopupFocusReason);
        else
            list.forceActiveFocus(Qt.PopupFocusReason);
    }

    background: Rectangle {
        radius: 10
        color: Theme.background
        border.width: 1
        border.color: Theme.border
    }

    contentItem: Controls.ScrollView {
        id: list

        implicitHeight: Math.min(rows.implicitHeight, 240)
        contentWidth: availableWidth
        clip: true
        Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff

        Column {
            id: rows

            width: parent.width
            spacing: 4

            Text {
                visible: root.items.length === 0
                width: parent.width
                height: 32
                text: "No tray applications"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
            }

            Repeater {
                id: entries

                model: root.items

                delegate: Button {
                    id: entry

                    required property var modelData

                    width: rows.width
                    height: 32
                    text: modelData.title || modelData.tooltipTitle || "Application"
                    textWidth: Math.max(0, width - 40)
                    tooltip: [modelData.tooltipTitle || modelData.title, modelData.tooltipDescription].filter(part => !!part).join("\n")
                    interactive: true

                    indicator: Image {
                        width: Theme.iconSize
                        height: Theme.iconSize
                        sourceSize.width: width * Screen.devicePixelRatio
                        sourceSize.height: height * Screen.devicePixelRatio
                        source: entry.modelData.icon
                        fillMode: Image.PreserveAspectFit
                    }

                    onClicked: button => {
                        root.close();
                        if (button === Qt.RightButton || modelData.onlyMenu)
                            root.menuRequested(modelData);
                        else if (button === Qt.MiddleButton)
                            modelData.secondaryActivate();
                        else
                            modelData.activate();
                    }
                    wheelEnabled: true
                    onScrolled: delta => modelData.scroll(delta, false)
                    onActiveFocusChanged: {
                        if (activeFocus) {
                            const view = list.contentItem as Flickable;
                            view.contentY = Math.max(0, Math.min(y, Math.max(view.contentY, y + height - view.height)));
                        }
                    }
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Menu || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier))) {
                            clicked(Qt.RightButton);
                            event.accepted = true;
                        } else {
                            event.accepted = false;
                        }
                    }
                }
            }
        }
    }
}
