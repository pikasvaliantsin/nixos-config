import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Центр уведомлений: единственное место, где они видны.
PanelWindow {
    id: panel

    anchors {
        top: true
        right: true
    }
    margins {
        top: Theme.barHeight + 2
        right: 8
    }
    implicitWidth: 360
    implicitHeight: Math.min(560, Math.max(140, column.implicitHeight + 24))
    color: "transparent"
    visible: Ui.notifOpen
    exclusiveZone: 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"

    IpcHandler {
        target: "notifications"
        function toggle(): void {
            const v = !Ui.notifOpen;
            Ui.netOpen = false;
            Ui.btOpen = false;
            Clip.open = false;
            Ui.notifOpen = v;
        }
        function open(): void { Ui.notifOpen = true; }
        function close(): void { Ui.notifOpen = false; }
        function clear(): void { Notif.clearAll(); }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.surfaceHigh
        radius: Theme.radius
        border.width: 1
        border.color: Theme.outline
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                text: "Уведомления"
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: 14
                font.bold: true
            }
            Text {
                text: Notif.count > 0 ? String(Notif.count) : ""
                color: Theme.primary
                font.family: Theme.font
                font.pixelSize: 12
            }
            Item { Layout.fillWidth: true }
            Text {
                text: "Очистить"
                color: Notif.count > 0 ? Theme.primary : Theme.fgMuted
                font.family: Theme.font
                font.pixelSize: 11
                MouseArea {
                    anchors.fill: parent
                    enabled: Notif.count > 0
                    onClicked: Notif.clearAll()
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
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 6
            model: Notif.list
            visible: Notif.count > 0

            delegate: Rectangle {
                id: card
                required property var modelData
                width: ListView.view.width
                height: body.implicitHeight + 18
                radius: 10
                color: Theme.surface
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.04)

                Column {
                    id: body
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: 9
                    }
                    spacing: 3

                    Text {
                        width: body.width
                        text: modelData.appName || ""
                        color: Theme.primary
                        font.family: Theme.font
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                    Text {
                        width: body.width
                        text: modelData.summary || ""
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.bold: true
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                    Text {
                        width: body.width
                        visible: text.length > 0
                        text: modelData.body || ""
                        color: Theme.fgMuted
                        font.family: Theme.font
                        font.pixelSize: 11
                        wrapMode: Text.Wrap
                        maximumLineCount: 6
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: card.modelData.dismiss()
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: Notif.count === 0
            text: "Пусто"
            color: Theme.fgMuted
            font.family: Theme.font
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
