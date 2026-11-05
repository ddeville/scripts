import QtQuick
import QtQuick.Shapes

Item {
    id: root

    required property string name
    property color color: Theme.foreground
    property real level: 1
    property bool muted: false
    property bool plugged: false
    readonly property var paths: ({
        "cpu": "M6 6 H18 V18 H6 Z M9 9 H15 V15 H9 Z M9 3 V6 M15 3 V6 M9 18 V21 M15 18 V21 M3 9 H6 M3 15 H6 M18 9 H21 M18 15 H21",
        "memory": "M3 6 H21 V17 H3 Z M6 9 H9 V13 H6 Z M12 9 H15 V13 H12 Z M18 9 V13 M6 17 V20 M10 17 V20 M14 17 V20 M18 17 V20",
        "temperature": "M10 14 V5 A2 2 0 0 1 14 5 V14 A4 4 0 1 1 10 14 M12 8 V17 M17 6 H20 M17 10 H19",
        "mail": "M4 5 H20 V19 H4 Z M4 6 L12 12 L20 6",
        "updates": "M4 8 L12 4 L20 8 V17 L12 21 L4 17 Z M4 8 L12 12 L20 8 M12 12 V21 M8 6 L16 10",
        "sun": "M16 12 A4 4 0 1 1 8 12 A4 4 0 1 1 16 12 M12 2 V4 M12 20 V22 M2 12 H4 M20 12 H22 M5 5 L6.5 6.5 M17.5 17.5 L19 19 M5 19 L6.5 17.5 M17.5 6.5 L19 5",
        "battery": "M3 7 H19 V17 H3 Z M22 10 V14",
        "plug": "M8 3 V7 M16 3 V7 M6 7 H18 V10 A6 6 0 0 1 12 16 V21",
        "ethernet": "M5 4 H19 V15 H16 V18 H8 V15 H5 Z M9 4 V8 M12 4 V8 M15 4 V8 M12 18 V21",
        "bell": "M6 16 V10 A6 6 0 0 1 18 10 V16 L20 18 H4 Z M10 21 H14",
        "bell-off": "M4 4 L20 20 M8 5 A6 6 0 0 1 18 10 V14 M6 9 V16 L4 18 H16 M10 21 H14",
        "power": "M12 3 V12 M7 5 A8 8 0 1 0 17 5",
        "apps": "M4 4 H10 V10 H4 Z M14 4 H20 V10 H14 Z M4 14 H10 V20 H4 Z M14 14 H20 V20 H14 Z",
        "lock": "M5 10 H19 V21 H5 Z M8 10 V7 A4 4 0 0 1 16 7 V10 M12 14 V17",
        "logout": "M10 4 H4 V20 H10 M10 12 H21 M17 8 L21 12 L17 16",
        "moon": "M20 14 A8 8 0 1 1 10 4 A7 7 0 0 0 20 14 Z",
        "restart": "M20 10 A8 8 0 1 0 19 17 M20 4 V10 H14",
        "close": "M6 6 L18 18 M18 6 L6 18",
        "chevron-left": "M15 6 L9 12 L15 18",
        "chevron-right": "M9 6 L15 12 L9 18",
        "volume": "M3 9 H7 L12 5 V19 L7 15 H3 Z",
        "headphones": "M4 13 V11 A8 8 0 0 1 20 11 V13 M4 12 H7 V21 H4 A2 2 0 0 1 2 19 V14 A2 2 0 0 1 4 12 M20 12 H17 V21 H20 A2 2 0 0 0 22 19 V14 A2 2 0 0 0 20 12",
        "speaker": "M6 3 H18 V21 H6 Z M14 7 A2 2 0 1 1 10 7 A2 2 0 1 1 14 7 M15 15 A3 3 0 1 1 9 15 A3 3 0 1 1 15 15",
        "monitor": "M3 4 H21 V17 H3 Z M12 17 V21 M8 21 H16"
    })
    readonly property var wifiArcs: ["M8.46 15.46 A5 5 0 0 1 15.54 15.46", "M5.28 12.28 A9.5 9.5 0 0 1 18.72 12.28", "M2.1 9.1 A14 14 0 0 1 21.9 9.1"]

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
                    if (root.name === "headphones" && root.muted)
                        result += " M3 3 L21 21";

                    return result;
                }
            }

        }

        ShapePath {
            strokeColor: Qt.alpha(root.color, 0.22)
            strokeWidth: 2
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"

            PathSvg {
                path: root.name === "wifi" ? root.wifiArcs.join(" ") : ""
            }

        }

        ShapePath {
            strokeColor: root.color
            strokeWidth: 2
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"

            PathSvg {
                path: root.name === "wifi" && !root.muted ? root.wifiArcs.slice(0, root.level > 0.66 ? 3 : root.level > 0.33 ? 2 : root.level > 0 ? 1 : 0).join(" ") : ""
            }

        }

        ShapePath {
            strokeColor: "transparent"
            fillColor: root.color

            PathSvg {
                path: root.name === "wifi" ? "M13.35 19 A1.35 1.35 0 1 1 10.65 19 A1.35 1.35 0 1 1 13.35 19" : ""
            }

        }

        ShapePath {
            strokeColor: root.color
            strokeWidth: 2
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"

            PathSvg {
                path: root.name === "wifi" && root.muted ? "M4 4 L20 20" : ""
            }

        }

        ShapePath {
            strokeColor: "transparent"
            fillColor: root.color

            PathSvg {
                path: root.name === "battery" && root.level > 0 ? "M5 9 H" + (5 + 12 * Math.min(1, root.level)) + " V15 H5 Z" : ""
            }

        }

        ShapePath {
            strokeColor: root.name === "battery" && root.plugged ? (root.level > 0.6 ? Theme.background : root.color) : "transparent"
            strokeWidth: 1.8
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: "M13 8 L10 12 H14 L11 16"
            }

        }

        transform: Scale {
            xScale: root.width / 24
            yScale: root.height / 24
        }

    }

}
