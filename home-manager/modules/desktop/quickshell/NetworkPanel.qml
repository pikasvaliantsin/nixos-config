import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Networking

// Сеть: Wi-Fi сети, подключение, радио-переключатель.
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
    implicitHeight: Math.min(560, 150 + Math.max(1, Net.wifiNetworks.length) * 46)
    color: "transparent"
    visible: Ui.netOpen
    exclusiveZone: 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-network"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    property var selectedNetwork: null
    property var pendingNetwork: null

    IpcHandler {
        target: "network"
        function toggle(): void {
            const v = !Ui.netOpen;
            Ui.btOpen = false;
            Ui.notifOpen = false;
            Clip.open = false;
            Ui.netOpen = v;
        }
        function close(): void { Ui.netOpen = false; }
    }

    onVisibleChanged: {
        if (visible) {
            panel.selectedNetwork = null;
            Net.scan(true);
        } else {
            Net.scan(false);
        }
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
                text: "Сеть"
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: 14
                font.bold: true
            }
            Text {
                Layout.fillWidth: true
                text: Net.connected ? Net.name : "не подключено"
                color: Theme.fgMuted
                font.family: Theme.font
                font.pixelSize: 11
                elide: Text.ElideRight
            }

            Rectangle {
                width: 34
                height: 18
                radius: 9
                color: Net.wifiEnabled ? Theme.primary : Theme.outline
                Behavior on color { ColorAnimation { duration: 120 } }
                Rectangle {
                    width: 14
                    height: 14
                    radius: 7
                    y: 2
                    x: Net.wifiEnabled ? 18 : 2
                    color: Theme.primaryText
                    Behavior on x { NumberAnimation { duration: 120 } }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: Net.setWifiEnabled(!Net.wifiEnabled)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: Net.wired ? "Ethernet подключён" : "Wi-Fi"
                color: Theme.fgMuted
                font.family: Theme.font
                font.pixelSize: 10
            }
            Item { Layout.fillWidth: true }
            Text {
                text: Net.wifiDevice && Net.wifiDevice.scannerEnabled ? "идёт поиск…" : "обновить"
                color: Theme.primary
                font.family: Theme.font
                font.pixelSize: 10
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    onClicked: {
                        Net.scan(false);
                        Net.scan(true);
                    }
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
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            model: Net.wifiNetworks
            visible: Net.wifiNetworks.length > 0 && Net.wifiEnabled

            delegate: Item {
                id: row
                required property var modelData
                width: ListView.view.width
                height: 42

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

                    Icon {
                        glyph: "\uf1eb"
                        size: 13
                        color: row.modelData.connected ? Theme.primary : Theme.fgMuted
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: row.modelData.name
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            width: parent.width
                        }
                        Text {
                            text: (Net.isSecure(row.modelData)
                                ? Net.securityLabel(row.modelData)
                                : "открытая")
                                + (row.modelData.signalStrength === undefined
                                    ? ""
                                    : " · " + Math.round(row.modelData.signalStrength * 100) + "%")
                            color: Theme.fgMuted
                            font.family: Theme.font
                            font.pixelSize: 9
                        }
                    }

                    Text {
                        visible: row.modelData.connected
                        text: "подключено"
                        color: Theme.primary
                        font.family: Theme.font
                        font.pixelSize: 10
                    }
                    Icon {
                        visible: Net.isSecure(row.modelData) && !row.modelData.connected
                        glyph: "\uf023"
                        size: 9
                        color: Theme.fgMuted
                    }
                }

                HoverHandler { id: rowHover }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (row.modelData.connected) {
                            Net.disconnectNetwork(row.modelData);
                        } else if (row.modelData.known || !Net.isSecure(row.modelData)) {
                            Net.connectNetwork(row.modelData, "");
                        } else {
                            panel.selectedNetwork = row.modelData;
                            password.forceActiveFocus();
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: panel.selectedNetwork !== null

            Rectangle {
                Layout.fillWidth: true
                height: 30
                radius: 8
                color: Theme.surface
                border.width: 1
                border.color: password.activeFocus ? Theme.primary : Theme.outline

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    verticalAlignment: Text.AlignVCenter
                    visible: password.text.length === 0
                    text: "пароль для " + (panel.selectedNetwork ? panel.selectedNetwork.name : "")
                    color: Theme.fgMuted
                    font.family: Theme.font
                    font.pixelSize: 11
                }

                TextInput {
                    id: password
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    color: Theme.fg
                    selectionColor: Theme.primary
                    selectedTextColor: Theme.primaryText
                    font.family: Theme.font
                    font.pixelSize: 12
                    Keys.onReturnPressed: {
                        Net.connectNetwork(panel.selectedNetwork, password.text);
                        panel.selectedNetwork = null;
                        password.text = "";
                    }
                    Keys.onEscapePressed: {
                        panel.selectedNetwork = null;
                        password.text = "";
                    }
                }
            }

            Text {
                text: "Подключить"
                color: Theme.primary
                font.family: Theme.font
                font.pixelSize: 11
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    onClicked: {
                        Net.connectNetwork(panel.selectedNetwork, password.text);
                        panel.selectedNetwork = null;
                        password.text = "";
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: !Net.wifiEnabled
            text: "Wi-Fi выключен"
            color: Theme.fgMuted
            font.family: Theme.font
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
