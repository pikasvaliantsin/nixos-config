pragma Singleton
import QtQuick
import Quickshell

// Общий UI-стейт бара: свёрнутый трей и т.п.
Singleton {
    id: root

    property bool trayOpen: false

    function toggleTray() {
        root.trayOpen = !root.trayOpen;
    }
}
