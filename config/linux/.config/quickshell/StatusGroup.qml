import QtQuick

Rectangle {
    default property alias content: contentRow.data

    implicitWidth: contentRow.implicitWidth + 6
    implicitHeight: Theme.height - 6
    color: Theme.surface
    radius: 7

    data: Row {
        id: contentRow

        anchors.centerIn: parent
        spacing: 2
    }

}
