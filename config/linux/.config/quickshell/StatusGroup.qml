import QtQuick

Item {
    default property alias content: contentRow.data

    implicitWidth: contentRow.implicitWidth + 4
    implicitHeight: Theme.height - 6

    data: Row {
        id: contentRow

        anchors.centerIn: parent
        spacing: 2
    }

}
