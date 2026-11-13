pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Общий UI-стейт бара.
Singleton {
    id: root

    property bool trayExpanded: false
    property bool notifOpen: false
    property bool netOpen: false
    property bool btOpen: false

    IpcHandler {
        target: "tray"
        function toggle(): void { root.trayExpanded = !root.trayExpanded; }
        function expand(): void { root.trayExpanded = true; }
        function collapse(): void { root.trayExpanded = false; }
    }
}
