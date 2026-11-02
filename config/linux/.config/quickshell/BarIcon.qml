import QtQuick
import QtQuick.Shapes

Item {
    id: root

    required property string name
    property color color: Theme.foreground
    property real level: 1
    property bool muted: false
    readonly property var paths: ({
        "mail": "M4 5 H20 V19 H4 Z M4 6 L12 12 L20 6",
        "updates": "M4 8 L12 4 L20 8 V17 L12 21 L4 17 Z M4 8 L12 12 L20 8 M12 12 V21 M8 6 L16 10",
        "sun": "M16 12 A4 4 0 1 1 8 12 A4 4 0 1 1 16 12 M12 2 V4 M12 20 V22 M2 12 H4 M20 12 H22 M5 5 L6.5 6.5 M17.5 17.5 L19 19 M5 19 L6.5 17.5 M17.5 6.5 L19 5",
        "battery": "M3 7 H19 V17 H3 Z M22 10 V14",
        "plug": "M8 3 V7 M16 3 V7 M6 7 H18 V10 A6 6 0 0 1 12 16 V21",
        "bell": "M6 16 V10 A6 6 0 0 1 18 10 V16 L20 18 H4 Z M10 21 H14",
        "bell-off": "M4 4 L20 20 M8 5 A6 6 0 0 1 18 10 V14 M6 9 V16 L4 18 H16 M10 21 H14",
        "power": "M12 3 V12 M7 5 A8 8 0 1 0 17 5",
        "close": "M6 6 L18 18 M18 6 L6 18",
        "volume": "M3 9 H7 L12 5 V19 L7 15 H3 Z"
    })

    implicitWidth: Theme.iconSize
    implicitHeight: Theme.iconSize

    Shape {
        width: 24
        height: 24
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.color
            strokeWidth: 1.8
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            fillColor: "transparent"

            PathSvg {
                path: {
                    let result = root.paths[root.name] || "";
                    if (root.name === "volume") {
                        if (root.muted) {
                            result += " M16 9 L22 15 M22 9 L16 15";
                        } else {
                            if (root.level > 0)
                                result += " M16 9 Q19 12 16 15";

                            if (root.level > 0.5)
                                result += " M19 6 Q25 12 19 18";

                        }
                    }
                    return result;
                }
            }

        }

        ShapePath {
            strokeColor: "transparent"
            fillColor: root.color

            PathSvg {
                path: root.name === "battery" && root.level > 0 ? "M5 9 H" + (5 + 12 * Math.min(1, root.level)) + " V15 H5 Z" : ""
            }

        }

        transform: Scale {
            xScale: root.width / 24
            yScale: root.height / 24
        }

    }

}
