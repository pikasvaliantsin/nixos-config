import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Развёрнутый трей: все иконки сеткой. ПКМ — скрыть/показать.
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
    implicitWidth: Math.max(240, content.implicitWidth + 24)
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

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            Text {
                text: "Трей"
                color: Theme.fgMuted
                font.family: Theme.font
                font.pixelSize: 11
            }
            Text {
                text: Tray.ignored.length > 0
                    ? Tray.visible.length + " · скрыто " + Tray.ignored.length
                    : String(Tray.visible.length)
                color: Theme.fgMuted
                font.family: Theme.font
                font.pixelSize: 10
            }
        }

        Grid {
            columns: 6
            spacing: 10
            anchors.horizontalCenter: parent.horizontalCenter

            Repeater {
                model: Tray.all
                delegate: Item {
                    id: cell
                    required property var modelData
                    width: 34
                    height: 34
                    opacity: Tray.isHidden(cell.modelData.id) ? 0.45 : 1.0

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

                    Icon {
                        visible: Tray.isHidden(cell.modelData.id)
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        glyph: "\uf070"
                        size: 8
                        color: Theme.warning
                    }

                    QsMenuAnchor {
                        id: menu
                        menu: cell.modelData.menu
                        anchor.item: cell
                        onClosed: Ui.trayOpen = false
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.RightButton) {
                                Tray.toggleHidden(cell.modelData.id);
                            } else if (mouse.button === Qt.MiddleButton) {
                                cell.modelData.secondaryActivate();
                            } else if (cell.modelData.hasMenu) {
                                menu.open();
                            } else {
                                cell.modelData.activate();
                                Ui.trayOpen = false;
                            }
                        }
                    }
                }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Иконка:"
                color: Theme.fgMuted
                font.family: Theme.font
                font.pixelSize: 9
            }

            Repeater {
                model: ["\uf054", "\uf078", "\uf141", "\uf00a", "\uf466", "\uf0c9"]
                delegate: Item {
                    required property var modelData
                    width: 20
                    height: 20

                    Rectangle {
                        anchors.fill: parent
                        radius: 5
                        color: Tray.icon === modelData
                            ? Theme.primary
                            : (pickHover.hovered ? Theme.surface : "transparent")
                    }

                    Icon {
                        anchors.centerIn: parent
                        glyph: modelData
                        size: 10
                        color: Tray.icon === modelData ? Theme.primaryText : Theme.fgMuted
                    }

                    HoverHandler { id: pickHover }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: Tray.setIcon(modelData)
                    }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "ЛКМ — открыть · ПКМ — скрыть/показать"
            color: Theme.fgMuted
            font.family: Theme.font
            font.pixelSize: 9
        }
    }
}
