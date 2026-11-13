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
    implicitHeight: Math.min(620, 92 + Math.max(1, Clip.entries.length) * 84)
    color: "transparent"
    visible: Clip.open
    exclusiveZone: 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-clipboard"

    IpcHandler {
        target: "clipboard"
        function toggle(): void { Clip.toggle(); }
        function open(): void { Clip.open = true; Clip.refresh(); }
        function close(): void { Clip.open = false; }
        function clear(): void { Clip.wipe(); }
        function refresh(): void { Clip.refresh(); }
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
                    onClicked: Clip.wipe()
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
                width: ListView.view.width
                height: card.modelData.isImage ? 92 : Math.min(64, textItem.implicitHeight + 16)
                radius: 10
                color: cardHover.hovered ? Theme.surface : Qt.rgba(1, 1, 1, 0.03)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.05)

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 10

                    Image {
                        visible: card.modelData.isImage
                        Layout.preferredWidth: 132
                        Layout.preferredHeight: 76
                        Layout.alignment: Qt.AlignVCenter
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: false
                        source: card.modelData.isImage ? Clip.thumbPath(card.modelData.id) : ""
                    }

                    Column {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 3

                        Text {
                            id: textItem
                            width: parent.width
                            text: card.modelData.preview
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: 11
                            wrapMode: Text.Wrap
                            maximumLineCount: card.modelData.isImage ? 2 : 3
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: card.modelData.isImage ? "картинка · ЛКМ — копировать" : "текст · ЛКМ — копировать"
                            color: Theme.fgMuted
                            font.family: Theme.font
                            font.pixelSize: 9
                        }
                    }
                }

                HoverHandler { id: cardHover }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton) Clip.remove(card.modelData);
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

    onVisibleChanged: if (visible) Clip.refresh()
}
