import QtQuick
pragma Singleton

QtObject {
    readonly property color background: "#202322"
    readonly property color foreground: "#e0dfd5"
    readonly property color muted: "#8e9690"
    readonly property color emptyDesktop: "#58605b"
    readonly property color surface: "#292e2b"
    readonly property color hover: "#363e37"
    readonly property color selected: "#d9c28f"
    readonly property color selectionSurface: "#3e3c30"
    readonly property color border: "#343b35"
    readonly property color primary: "#85ad85"
    readonly property color secondary: "#ffaf00"
    readonly property color tertiary: "#83adad"
    readonly property color alert: "#d75f5f"
    readonly property string font: "Noto Sans Mono"
    readonly property string iconFont: "Font Awesome 7 Free Solid"
    readonly property int fontSize: 12
    readonly property int iconSize: 16
    readonly property int height: 34
}
