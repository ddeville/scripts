import QtQuick
pragma Singleton

QtObject {
    readonly property color background: "#282828"
    readonly property color foreground: "#ebdbb2"
    readonly property color muted: "#a89984"
    readonly property color emptyDesktop: "#665c54"
    readonly property color surface: "#32302f"
    readonly property color hover: "#3c3836"
    readonly property color selected: "#fabd2f"
    readonly property color selectionSurface: "#3c3836"
    readonly property color border: "#504945"
    readonly property color primary: "#b8bb26"
    readonly property color secondary: "#fe8019"
    readonly property color tertiary: "#8ec07c"
    readonly property color alert: "#fb4934"
    readonly property string font: "Noto Sans Mono"
    readonly property int fontSize: 12
    readonly property int captionSize: 8
    readonly property int iconSize: 16
    readonly property int height: 34
}
