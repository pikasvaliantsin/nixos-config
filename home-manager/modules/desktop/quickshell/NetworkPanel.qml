import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Networking

// Сеть: Wi-Fi, Ethernet и VPN.
PanelWindow {
    id: panel

    anchors {
        top: true
        right: true
    }
    margins {
        top: 2
        right: 8
    }
    implicitWidth: 400
    implicitHeight: Math.min(600, 126
        + (Net.wifiEnabled ? Net.wifiNetworks.length * 42 : 0)
        + Net.vpn.length * 34
        + (panel.selectedNetwork !== null ? 38 : 0))
    color: "transparent"
    required property var modelData
    screen: modelData
    visible: Ui.netOpen && modelData.name === Niri.focusedOutput
    exclusiveZone: 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-network"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    property var selectedNetwork: null


    onVisibleChanged: {
        if (visible) {
            panel.selectedNetwork = null;
            Net.refreshVpn();
            if (Net.wifiEnabled) Net.scan(true);
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
        spacing: 6

        // --- заголовок ---------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Icon {
                glyph: "\uf1eb"
                size: 13
                color: Net.connected ? Theme.primary : Theme.fgMuted
            }
            Text {
                text: "Сеть"
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: 13
                font.bold: true
            }
            Text {
                Layout.fillWidth: true
                text: Net.connected ? Net.name : "не подключено"
                color: Theme.fgMuted
                font.family: Theme.font
                font.pixelSize: 10
                elide: Text.ElideRight
            }

            Rectangle {
                width: 32
                height: 16
                radius: 8
                color: Net.wifiEnabled ? Theme.primary : Theme.outline
                Behavior on color { ColorAnimation { duration: 120 } }
                Rectangle {
                    width: 12
                    height: 12
                    radius: 6
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
            spacing: 6

            Text {
                text: Net.wired
                    ? "Ethernet · " + (Net.activeNetwork ? Net.activeNetwork.name : "подключён")
                    : (Net.wifiEnabled ? "Wi-Fi" : "Wi-Fi выключен")
                color: Theme.fgMuted
                font.family: Theme.font
                font.pixelSize: 9
                elide: Text.ElideRight
            }
            Item { Layout.fillWidth: true }
            Text {
                visible: Net.wifiEnabled
                text: Net.wifiDevice && Net.wifiDevice.scannerEnabled ? "сканирование…" : "обновить"
                color: Theme.primary
                font.family: Theme.font
                font.pixelSize: 9
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -3
                    onClicked: {
                        Net.scan(false);
                        Net.scan(true);
                    }
                }
            }
        }

        // --- Wi-Fi сети --------------------------------------------------
        ListView {
            Layout.fillWidth: true
            Layout.preferredHeight: Net.wifiEnabled ? Net.wifiNetworks.length * 42 : 0
            clip: true
            spacing: 0
            model: Net.wifiEnabled ? Net.wifiNetworks : []
            visible: Net.wifiEnabled && Net.wifiNetworks.length > 0

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
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    spacing: 8

                    Icon {
                        glyph: "\uf1eb"
                        size: 12
                        color: row.modelData.connected ? Theme.primary : Theme.fgMuted
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            text: row.modelData.name
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: 11
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
                        font.pixelSize: 9
                    }
                    Icon {
                        visible: Net.isSecure(row.modelData) && !row.modelData.connected
                        glyph: "\uf023"
                        size: 8
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

        Text {
            Layout.fillWidth: true
            visible: Net.wifiEnabled && Net.wifiNetworks.length === 0
            text: "Сети не найдены"
            color: Theme.fgMuted
            font.family: Theme.font
            font.pixelSize: 10
            horizontalAlignment: Text.AlignHCenter
        }

        // --- VPN ----------------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.outline
            opacity: 0.4
            visible: Net.vpn.length > 0 && Net.wifiEnabled && Net.wifiNetworks.length > 0
        }

        RowLayout {
            Layout.fillWidth: true
            visible: Net.vpn.length > 0

            Text {
                text: "VPN"
                color: Theme.fgMuted
                font.family: Theme.font
                font.pixelSize: 9
                font.bold: true
            }
            Item { Layout.fillWidth: true }
            Text {
                text: Net.vpnActive ? "активен" : "выключен"
                color: Net.vpnActive ? Theme.primary : Theme.fgMuted
                font.family: Theme.font
                font.pixelSize: 9
            }
        }

        Repeater {
            model: Net.vpn

            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 8

                Icon {
                    glyph: "\uf023"
                    size: 11
                    color: modelData.active ? Theme.primary : Theme.fgMuted
                }
                Text {
                    Layout.fillWidth: true
                    text: modelData.name
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
                Rectangle {
                    width: 32
                    height: 16
                    radius: 8
                    color: modelData.active ? Theme.primary : Theme.outline
                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        y: 2
                        x: modelData.active ? 18 : 2
                        color: Theme.primaryText
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: Net.toggleVpn(modelData.name, modelData.active)
                    }
                }
            }
        }

        // --- пароль -------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: panel.selectedNetwork !== null

            Rectangle {
                Layout.fillWidth: true
                height: 28
                radius: 7
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
                    font.pixelSize: 10
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
                    font.pixelSize: 11
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
                text: "OK"
                color: Theme.primary
                font.family: Theme.font
                font.pixelSize: 11
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -3
                    onClicked: {
                        Net.connectNetwork(panel.selectedNetwork, password.text);
                        panel.selectedNetwork = null;
                        password.text = "";
                    }
                }
            }
        }
    }
}
