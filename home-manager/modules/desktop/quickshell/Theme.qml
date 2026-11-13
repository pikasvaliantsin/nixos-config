pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property color bg: pal.bg
    readonly property color surface: pal.surface
    readonly property color surfaceContainer: pal.surfaceContainer
    readonly property color surfaceHigh: pal.surfaceContainerHigh
    readonly property color fg: pal.fg
    readonly property color fgMuted: pal.fgMuted
    readonly property color primary: pal.primary
    readonly property color primaryText: pal.primaryText
    readonly property color outline: pal.outline
    readonly property color error: pal.error
    readonly property color warning: pal.warning

    readonly property int radius: 12
    readonly property int barHeight: 34
    readonly property string font: "Inter"

    function reload() {
        file.reload();
    }

    IpcHandler {
        target: "theme"
        function reload(): void {
            root.reload();
        }
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.config/theme/palette.json"
        watchChanges: true
        onFileChanged: reload()
        onLoadFailed: console.warn("theme: cannot read palette.json, using defaults")

        JsonAdapter {
            id: pal
            property string bg: "#090415"
            property string surface: "#1F1F28"
            property string surfaceContainer: "#020007"
            property string surfaceContainerHigh: "#15102C"
            property string fg: "#E6E1F7"
            property string fgMuted: "#B6B8C3"
            property string primary: "#C7B3F3"
            property string primaryText: "#020007"
            property string outline: "#4E4570"
            property string error: "#E53935"
            property string warning: "#F57C00"
        }
    }
}
