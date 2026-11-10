pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import "../../ui"

ShellPopup {
    id: root

    required property date today
    property date displayedMonth: new Date(today.getFullYear(), today.getMonth(), 1, 12)

    function showToday() {
        displayedMonth = new Date(today.getFullYear(), today.getMonth(), 1, 12);
    }

    function moveMonth(offset) {
        displayedMonth = new Date(displayedMonth.getFullYear(), displayedMonth.getMonth() + offset, 1, 12);
    }

    implicitWidth: 300
    popupX: 0
    padding: 12
    closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutsideParent
    onAboutToShow: showToday()
    onOpened: previousButton.forceActiveFocus(Qt.PopupFocusReason)

    contentItem: Column {
        spacing: 10

        Row {
            width: parent.width

            Text {
                width: parent.width - 84
                anchors.verticalCenter: parent.verticalCenter
                text: grid.title
                elide: Text.ElideRight
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: 14
                renderType: Text.QtRendering
            }

            Button {
                id: previousButton

                symbol: "chevron-left"
                tooltip: "Previous month"
                Accessible.name: "Previous month"
                onClicked: root.moveMonth(-1)
            }

            Button {
                symbol: "chevron-right"
                tooltip: "Next month"
                Accessible.name: "Next month"
                onClicked: root.moveMonth(1)
            }

            Button {
                symbol: "close"
                tooltip: "Close calendar"
                foreground: Theme.muted
                Accessible.name: "Close calendar"
                onClicked: root.close()
            }

        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.border
        }

        Column {
            width: parent.width
            spacing: 4

            Controls.DayOfWeekRow {
                width: parent.width
                height: 22
                padding: 0
                spacing: grid.spacing
                locale: grid.locale

                delegate: Text {
                    required property string shortName

                    text: shortName.toUpperCase()
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 9
                    renderType: Text.QtRendering
                }

            }

            Controls.MonthGrid {
                id: grid

                width: parent.width
                height: 190
                padding: 0
                spacing: 2
                month: root.displayedMonth.getMonth()
                year: root.displayedMonth.getFullYear()

                delegate: Item {
                    id: day

                    required property var model
                    readonly property bool isToday: model.year === root.today.getFullYear() && model.month === root.today.getMonth() && model.day === root.today.getDate()

                    Rectangle {
                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        radius: 6
                        visible: day.isToday
                        color: Theme.selected
                    }

                    Text {
                        anchors.centerIn: parent
                        text: day.model.day
                        color: day.isToday ? Theme.background : day.model.month === grid.month ? Theme.foreground : Theme.emptyDesktop
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        renderType: Text.QtRendering
                    }

                }

            }

        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.border
        }

        Row {
            width: parent.width

            Button {
                id: todayButton

                text: "Today"
                foreground: Theme.selected
                onClicked: root.showToday()
            }

            Text {
                width: parent.width - todayButton.width
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(root.today, "ddd, d MMM")
                horizontalAlignment: Text.AlignRight
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 10
                renderType: Text.QtRendering
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
