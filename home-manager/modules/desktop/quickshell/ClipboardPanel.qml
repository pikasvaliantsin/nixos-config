import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// История буфера: текст и картинки с превью.
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
    implicitWidth: 420
    implicitHeight: Math.min(620, 92 + Math.max(1, Clip.entries.length) * 96)
    color: "transparent"
    visible: Clip.open
    exclusiveZone: 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-clipboard"

    IpcHandler {
        target: "clipboard"
        function toggle(): void { Clip.toggle(); }
        function open(): void { Clip.open = true; }
        function close(): void { Clip.open = false; }
        function clear(): void { Clip.clear(); }
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
                text: "Буфер обмена"
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: 14
                font.bold: true
            }
            Text {
                text: Clip.entries.length > 0 ? String(Clip.entries.length) : ""
                color: Theme.primary
                font.family: Theme.font
                font.pixelSize: 11
            }
            Item { Layout.fillWidth: true }
            Text {
                text: "Очистить"
                color: Clip.entries.length > 0 ? Theme.primary : Theme.fgMuted
                font.family: Theme.font
                font.pixelSize: 11
                MouseArea {
                    anchors.fill: parent
                    enabled: Clip.entries.length > 0
                    onClicked: Clip.clear()
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
            spacing: 6
            model: Clip.entries
            visible: Clip.entries.length > 0

            delegate: Rectangle {
                id: card
                required property var modelData
                required property int index
                width: ListView.view.width
                height: card.modelData.type === "image"
                    ? 88
                    : Math.min(72, textItem.implicitHeight + 18)
                radius: 10
                color: cardHover.hovered ? Theme.surface : Qt.rgba(1, 1, 1, 0.03)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.05)

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 10

                    Image {
                        visible: card.modelData.type === "image"
                        Layout.preferredWidth: 132
                        Layout.preferredHeight: 72
                        Layout.alignment: Qt.AlignVCenter
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        source: card.modelData.type === "image"
                            ? "file://" + card.modelData.path
                            : ""
                    }

                    Column {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 3

                        Text {
                            id: textItem
                            width: parent.width
                            text: card.modelData.type === "image"
                                ? (card.modelData.mime || "image/png")
                                : (card.modelData.text || "")
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: 11
                            wrapMode: Text.Wrap
                            maximumLineCount: card.modelData.type === "image" ? 2 : 3
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: (card.modelData.capturedAt ? card.modelData.capturedAt + " · " : "")
                                + (card.modelData.type === "image" ? "картинка" : "текст")
                                + " · ЛКМ — копировать, ПКМ — удалить"
                            color: Theme.fgMuted
                            font.family: Theme.font
                            font.pixelSize: 9
                            elide: Text.ElideRight
                        }
                    }
                }

                HoverHandler { id: cardHover }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton) Clip.removeAt(card.index);
                        else Clip.copy(card.modelData);
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: Clip.entries.length === 0
            text: "Пусто"
            color: Theme.fgMuted
            font.family: Theme.font
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
