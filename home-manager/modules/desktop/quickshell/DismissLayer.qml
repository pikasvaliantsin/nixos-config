import QtQuick
import Quickshell
import Quickshell.Wayland

// Прозрачный слой на весь экран: клик мимо панели закрывает её.
PanelWindow {
    id: root

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusiveZone: 0
    visible: Ui.trayOpen || Ui.notifOpen || Clip.open

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-dismiss"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        onClicked: {
            Ui.trayOpen = false;
            Ui.notifOpen = false;
            Clip.open = false;
        }
    }
}
