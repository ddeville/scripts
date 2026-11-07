pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property bool connected: false
    property bool exitNode: false
    property bool exitNodeOnline: true

    implicitWidth: Theme.iconSize
    implicitHeight: Theme.iconSize

    Item {
        width: 20
        height: 20
        scale: Math.min(root.width, root.height) / 20
        transformOrigin: Item.TopLeft

        Repeater {
            model: 9

            Rectangle {
                required property int index
                readonly property bool marked: root.connected && root.exitNode

                x: 2 + (index % 3) * 6
                y: 2 + Math.floor(index / 3) * 6
                width: 4
                height: 4
                radius: 2
                antialiasing: true
                visible: !marked || (root.exitNodeOnline ? index < 7 : index < 4 || index === 6)
                color: root.connected && (index === 3 || index === 4 || index === 5 || index === 7) ? Theme.foreground : "#666666"
            }
        }

        Shape {
            visible: root.connected && root.exitNode
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: root.exitNodeOnline ? Theme.foreground : "#e56f4a"
                strokeWidth: 2
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                fillColor: "transparent"

                PathSvg {
                    path: root.exitNodeOnline ? "M9 16 H18 M15 13 L18 16 L15 19" : "M10 10 L17 17 M10 17 L17 10"
                }
            }
        }
    }
}
