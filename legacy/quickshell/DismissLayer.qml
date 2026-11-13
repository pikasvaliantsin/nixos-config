import QtQuick
import Quickshell
import Quickshell.Wayland

// Прозрачный слой: клик мимо панели закрывает её.
PanelWindow {
    id: root

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    margins {
        top: 0
    }
    color: "transparent"
    exclusiveZone: 0
    required property var modelData
    screen: modelData
    visible: (Ui.notifOpen || Clip.open || Ui.netOpen || Ui.btOpen) && modelData.name === Niri.focusedOutput

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-dismiss"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        onClicked: {
            Ui.notifOpen = false;
            Clip.open = false;
            Ui.netOpen = false;
            Ui.btOpen = false;
        }
    }
}
