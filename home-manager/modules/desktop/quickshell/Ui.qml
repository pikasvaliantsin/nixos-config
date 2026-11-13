pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Общий UI-стейт бара и IPC для панелей.
Singleton {
    id: root

    property bool trayExpanded: false
    property bool notifOpen: false
    property bool netOpen: false
    property bool btOpen: false

    function closePanels() {
        root.trayExpanded = false;
        root.notifOpen = false;
        root.netOpen = false;
        root.btOpen = false;
        Clip.open = false;
    }

    IpcHandler {
        target: "tray"
        function toggle(): void { root.trayExpanded = !root.trayExpanded; }
        function expand(): void { root.trayExpanded = true; }
        function collapse(): void { root.trayExpanded = false; }
    }

    IpcHandler {
        target: "notifications"
        function toggle(): void {
            const v = !root.notifOpen;
            root.closePanels();
            root.notifOpen = v;
        }
        function open(): void { root.closePanels(); root.notifOpen = true; }
        function close(): void { root.notifOpen = false; }
        function clear(): void { Notif.clearAll(); }
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void {
            const v = !Clip.open;
            root.closePanels();
            Clip.open = v;
        }
        function open(): void { root.closePanels(); Clip.open = true; }
        function close(): void { Clip.open = false; }
        function clear(): void { Clip.clear(); }
    }

    IpcHandler {
        target: "network"
        function toggle(): void {
            const v = !root.netOpen;
            root.closePanels();
            root.netOpen = v;
        }
        function open(): void { root.closePanels(); root.netOpen = true; }
        function close(): void { root.netOpen = false; }
    }

    IpcHandler {
        target: "bluetooth"
        function toggle(): void {
            const v = !root.btOpen;
            root.closePanels();
            root.btOpen = v;
        }
        function open(): void { root.closePanels(); root.btOpen = true; }
        function close(): void { root.btOpen = false; }
    }
}
