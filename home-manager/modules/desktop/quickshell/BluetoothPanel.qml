import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Bluetooth

// Bluetooth: адаптер, устройства, подключение.
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
    implicitWidth: 400
    implicitHeight: Math.min(560, 150 + Math.max(1, Bt.devices.length) * 46)
    color: "transparent"
    visible: Ui.btOpen
    exclusiveZone: 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-bluetooth"

    IpcHandler {
        target: "bluetooth"
        function toggle(): void {
            const v = !Ui.btOpen;
            Ui.netOpen = false;
            Ui.notifOpen = false;
            Clip.open = false;
            Ui.btOpen = v;
        }
        function close(): void { Ui.btOpen = false; }
    }

    onVisibleChanged: {
        if (!visible) Bt.setDiscovering(false);
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.surfaceHigh
        radius: Theme.radius
        border.width: 1
        border.color: Theme.outline
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Bluetooth"
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: 14
                font.bold: true
            }
            Text {
                Layout.fillWidth: true
                text: Bt.powered ? Bt.connectedCount + " подключено" : "выключен"
                color: Theme.fgMuted
                font.family: Theme.font
                font.pixelSize: 11
            }

            Rectangle {
                width: 34
                height: 18
                radius: 9
                color: Bt.powered ? Theme.primary : Theme.outline
                Behavior on color { ColorAnimation { duration: 120 } }
                Rectangle {
                    width: 14
                    height: 14
                    radius: 7
                    y: 2
                    x: Bt.powered ? 18 : 2
                    color: Theme.primaryText
                    Behavior on x { NumberAnimation { duration: 120 } }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: Bt.setPowered(!Bt.powered)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: Bt.powered

            Text {
                text: Bt.discovering ? "поиск устройств…" : "поиск"
                color: Theme.primary
                font.family: Theme.font
                font.pixelSize: 10
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    onClicked: Bt.setDiscovering(!Bt.discovering)
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.outline
            opacity: 0.5
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            model: Bt.sortedDevices
            visible: Bt.powered && Bt.devices.length > 0

            delegate: Item {
                id: row
                required property var modelData
                width: ListView.view.width
                height: 44

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: rowHover.hovered ? Theme.surface : "transparent"
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    Image {
                        sourceSize.width: 16
                        sourceSize.height: 16
                        source: Quickshell.iconPath(row.modelData.icon, "bluetooth")
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: row.modelData.name || row.modelData.deviceName || row.modelData.address
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            width: parent.width
                        }
                        Text {
                            text: row.modelData.connected
                                ? "подключено"
                                : (row.modelData.paired ? "сопряжено" : "не сопряжено")
                            color: row.modelData.connected ? Theme.primary : Theme.fgMuted
                            font.family: Theme.font
                            font.pixelSize: 9
                        }
                    }

                    Text {
                        visible: row.modelData.batteryAvailable
                        text: Math.round(row.modelData.battery * 100) + "%"
                        color: Theme.fgMuted
                        font.family: Theme.font
                        font.pixelSize: 10
                    }
                }

                HoverHandler { id: rowHover }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Bt.toggleDevice(row.modelData)
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: !Bt.powered
            text: "Bluetooth выключен"
            color: Theme.fgMuted
            font.family: Theme.font
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            Layout.fillWidth: true
            visible: Bt.powered && Bt.devices.length === 0
            text: Bt.discovering ? "Поиск…" : "Нет устройств — включи поиск"
            color: Theme.fgMuted
            font.family: Theme.font
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
