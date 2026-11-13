import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray

// Развёрнутый трей: все иконки сеткой, меню — через QsMenuAnchor.
PanelWindow {
    id: panel

    anchors {
        top: true
        right: true
    }
    margins {
        top: Theme.barHeight + 6
        right: 8
    }
    implicitWidth: content.implicitWidth + 24
    implicitHeight: content.implicitHeight + 24
    color: "transparent"
    visible: Ui.trayOpen
    exclusiveZone: 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-tray"

    IpcHandler {
        target: "tray"
        function toggle(): void { Ui.toggleTray(); }
        function close(): void { Ui.trayOpen = false; }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.surfaceHigh
        radius: Theme.radius
        border.width: 1
        border.color: Theme.outline
    }

    Column {
        id: content
        anchors.centerIn: parent
        spacing: 10

        Text {
            text: "Трей"
            color: Theme.fgMuted
            font.family: Theme.font
            font.pixelSize: 11
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Grid {
            columns: 6
            spacing: 10
            anchors.horizontalCenter: parent.horizontalCenter

            Repeater {
                model: SystemTray.items
                delegate: Item {
                    id: cell
                    required property var modelData
                    width: 34
                    height: 34

                    Rectangle {
                        anchors.fill: parent
                        radius: 9
                        color: hover.hovered ? Theme.surface : "transparent"
                        HoverHandler { id: hover }
                    }

                    Image {
                        anchors.centerIn: parent
                        sourceSize.width: 22
                        sourceSize.height: 22
                        source: cell.modelData.icon
                    }

                    QsMenuAnchor {
                        id: menu
                        menu: cell.modelData.menu
                        anchor.item: cell
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.MiddleButton) {
                                cell.modelData.secondaryActivate();
                            } else if (cell.modelData.hasMenu) {
                                menu.open();
                            } else if (mouse.button === Qt.LeftButton) {
                                cell.modelData.activate();
                                Ui.trayOpen = false;
                            } else {
                                cell.modelData.secondaryActivate();
                            }
                        }
                    }
                }
            }
        }
    }
}
