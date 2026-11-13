import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// История буфера: поиск, пины, фильтр по типу.
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
    implicitWidth: 440
    implicitHeight: Math.min(640, 150 + Math.max(1, Clip.visibleEntries.length) * 96)
    color: "transparent"
    visible: Clip.open
    exclusiveZone: 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-clipboard"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    IpcHandler {
        target: "clipboard"
        function toggle(): void {
            const v = !Clip.open;
            Ui.netOpen = false;
            Ui.btOpen = false;
            Ui.notifOpen = false;
            Clip.open = v;
        }
        function open(): void { Clip.open = true; }
        function close(): void { Clip.open = false; }
        function clear(): void { Clip.clear(); }
    }

    onVisibleChanged: {
        if (visible) {
            Clip.query = "";
            search.text = "";
            search.forceActiveFocus();
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
            height: 30
            radius: 8
            color: Theme.surface
            border.width: 1
            border.color: search.activeFocus ? Theme.primary : Theme.outline

            Text {
                anchors.fill: parent
                anchors.leftMargin: 9
                verticalAlignment: Text.AlignVCenter
                visible: search.text.length === 0
                text: "Поиск по истории…"
                color: Theme.fgMuted
                font.family: Theme.font
                font.pixelSize: 12
            }

            TextInput {
                id: search
                anchors.fill: parent
                anchors.leftMargin: 9
                anchors.rightMargin: 9
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.fg
                selectionColor: Theme.primary
                selectedTextColor: Theme.primaryText
                font.family: Theme.font
                font.pixelSize: 12
                onTextChanged: Clip.query = text
                Keys.onEscapePressed: Clip.open = false
                Keys.onReturnPressed: {
                    if (Clip.visibleEntries.length > 0) Clip.copy(Clip.visibleEntries[0]);
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Repeater {
                model: [
                    { id: "all", label: "Все" },
                    { id: "text", label: "Текст" },
                    { id: "image", label: "Картинки" }
                ]
                delegate: Text {
                    required property var modelData
                    text: modelData.label
                    color: Clip.typeFilter === modelData.id ? Theme.primary : Theme.fgMuted
                    font.family: Theme.font
                    font.pixelSize: 11
                    font.bold: Clip.typeFilter === modelData.id
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        onClicked: Clip.typeFilter = modelData.id
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                text: Clip.sortMode === "recent" ? "по времени" : "по типу"
                color: Theme.fgMuted
                font.family: Theme.font
                font.pixelSize: 11
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    onClicked: Clip.sortMode = Clip.sortMode === "recent" ? "type" : "recent"
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
            model: Clip.visibleEntries
            visible: Clip.visibleEntries.length > 0

            delegate: Rectangle {
                id: card
                required property var modelData
                width: ListView.view.width
                height: card.modelData.type === "image"
                    ? 92
                    : Math.min(74, textColumn.implicitHeight + 18)
                radius: 10
                color: cardHover.hovered ? Theme.surface : Qt.rgba(1, 1, 1, 0.03)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.05)

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    anchors.rightMargin: 30
                    spacing: 10

                    Image {
                        visible: card.modelData.type === "image"
                        Layout.preferredWidth: 132
                        Layout.preferredHeight: 74
                        Layout.alignment: Qt.AlignVCenter
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        source: card.modelData.type === "image"
                            ? "file://" + card.modelData.path
                            : ""
                    }

                    Column {
                        id: textColumn
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 3

                        Text {
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

                Item {
                    width: 24
                    height: 24
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter

                    Icon {
                        anchors.centerIn: parent
                        glyph: "\uf08d"
                        size: 12
                        color: card.modelData.pinned ? Theme.primary : Theme.fgMuted
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: Clip.togglePin(card.modelData)
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: Clip.visibleEntries.length === 0
            text: Clip.entries.length === 0 ? "Пусто" : "Ничего не найдено"
            color: Theme.fgMuted
            font.family: Theme.font
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
