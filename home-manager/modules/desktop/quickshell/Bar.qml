import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray

PanelWindow {
    id: bar

    required property var modelData
    property var screenData: modelData
    screen: screenData

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight
    exclusiveZone: Theme.barHeight
    color: "transparent"

    WlrLayershell.namespace: "quickshell-bar"
    WlrLayershell.layer: WlrLayer.Top

    readonly property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
    readonly property var workspaces: Niri.workspacesFor(screenData.name)

    function spawn(args) {
        proc.command = args;
        proc.running = true;
    }

    // --- порядок модулей (drag-and-drop) ---------------------------------
    ListModel { id: moduleModel }

    function defaultOrder() {
        return ["media", "sys", "weather", "tray", "volume", "net", "bt", "battery", "notifications", "clock"];
    }

    function applyOrder(order) {
        if (!order || order.length === 0) return;
        const present = [];
        for (const kind of order) {
            for (let i = 0; i < moduleModel.count; i++) {
                if (moduleModel.get(i).kind === kind) { present.push(kind); break; }
            }
        }
        for (let i = 0; i < moduleModel.count; i++) {
            if (!present.includes(moduleModel.get(i).kind)) present.push(moduleModel.get(i).kind);
        }
        for (let i = 0; i < present.length; i++) {
            const at = indexOfKind(present[i]);
            if (at !== i) moduleModel.move(at, i);
        }
    }

    function indexOfKind(kind) {
        for (let i = 0; i < moduleModel.count; i++) if (moduleModel.get(i).kind === kind) return i;
        return -1;
    }

    function widthAt(i) {
        const it = rightRepeater.itemAt(i);
        return it ? it.width : 0;
    }

    function commitReorder(from, dx) {
        let to = from;
        if (dx > 0) {
            let acc = widthAt(from) / 2;
            while (to < moduleModel.count - 1 && dx > acc) {
                to += 1;
                acc += widthAt(to);
            }
        } else if (dx < 0) {
            let acc = -widthAt(from) / 2;
            while (to > 0 && dx < acc) {
                to -= 1;
                acc -= widthAt(to);
            }
        }
        if (to !== from) {
            moduleModel.move(from, to);
            saveOrder();
        }
    }

    function saveOrder() {
        const arr = [];
        for (let i = 0; i < moduleModel.count; i++) arr.push(moduleModel.get(i).kind);
        orderAdapter.order = arr;
        orderFile.writeAdapter();
    }

    function componentFor(kind) {
        switch (kind) {
        case "media": return mediaComp;
        case "sys": return sysComp;
        case "weather": return weatherComp;
        case "tray": return trayComp;
        case "volume": return volumeComp;
        case "net": return netComp;
        case "bt": return btComp;
        case "battery": return batteryComp;
        case "notifications": return notifComp;
        case "clock": return clockComp;
        default: return null;
        }
    }

    FileView {
        id: orderFile
        path: Quickshell.env("HOME") + "/.local/state/quickshell/bar-order.json"
        watchChanges: false
        onLoaded: bar.applyOrder(orderAdapter.order)
        JsonAdapter {
            id: orderAdapter
            property list<string> order: []
        }
    }

    Process { id: proc; onExited: running = false }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        opacity: 0.93
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 8

        // --- воркспейсы + заголовок окна ---------------------------------
        Row {
            spacing: 6
            Repeater {
                model: bar.workspaces
                delegate: Rectangle {
                    required property var modelData
                    width: Math.max(22, label.implicitWidth + 12)
                    height: 22
                    radius: 7
                    color: modelData.is_active ? Theme.primary : (hover.hovered ? Theme.surfaceHigh : "transparent")
                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: modelData.name && modelData.name.length > 0 ? modelData.name : String(modelData.idx)
                        color: modelData.is_active ? Theme.primaryText : Theme.fgMuted
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.bold: modelData.is_active
                    }
                    HoverHandler { id: hover }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: Niri.focusWorkspace(modelData.idx, bar.screenData.name)
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            text: Niri.focused ? (Niri.focused.title || Niri.focused.app_id || "") : ""
            color: Theme.fgMuted
            font.family: Theme.font
            font.pixelSize: 12
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }

        // --- перетаскиваемые модули --------------------------------------
        Row {
            id: rightRow
            spacing: 4
            Repeater {
                id: rightRepeater
                model: moduleModel
                delegate: Item {
                    id: slot
                    required property string kind
                    required property int index
                    property real dx: 0
                    property real startWidth: 0
                    width: loader.implicitWidth + 10
                    height: bar.height
                    opacity: drag.active ? 0.65 : 1.0

                    Loader {
                        id: loader
                        anchors.centerIn: parent
                        sourceComponent: bar.componentFor(slot.kind)
                    }

                    DragHandler {
                        id: drag
                        target: null
                        xAxis.enabled: true
                        yAxis.enabled: false
                        onActiveTranslationChanged: slot.dx = activeTranslation.x
                        onActiveChanged: {
                            if (!active) {
                                bar.commitReorder(slot.index, slot.dx);
                                slot.dx = 0;
                            }
                        }
                    }
                }
            }
        }
    }

    // --- компоненты модулей ----------------------------------------------
    Component {
        id: clockComp
        Item {
            implicitWidth: clockRow.implicitWidth
            implicitHeight: clockRow.implicitHeight

            Row {
                id: clockRow
                anchors.centerIn: parent
                spacing: 6
                property string now: Qt.formatDateTime(new Date(), "HH:mm")
                Text {
                    text: clockRow.now
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.bold: true
                }
                Text {
                    text: Niri.layoutShort
                    color: Theme.fgMuted
                    font.family: Theme.font
                    font.pixelSize: 11
                    visible: Niri.layoutShort.length > 0
                }
                Timer {
                    interval: 1000
                    repeat: true
                    running: true
                    onTriggered: clockRow.now = Qt.formatDateTime(new Date(), "HH:mm")
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: bar.spawn(["ghostty", "--class=calcurse", "--title=calcurse", "-e", "calcurse"])
            }
        }
    }

    Component {
        id: mediaComp
        Item {
            implicitWidth: mediaRow.implicitWidth
            implicitHeight: mediaRow.implicitHeight
            visible: bar.player !== null

            Row {
                id: mediaRow
                anchors.centerIn: parent
                spacing: 6
                Text {
                    text: bar.player && bar.player.isPlaying ? "▶" : "⏸"
                    color: Theme.primary
                    font.pixelSize: 12
                }
                Text {
                    width: 160
                    text: bar.player ? ((bar.player.trackTitle || "—") + (bar.player.trackArtist ? " · " + bar.player.trackArtist : "")) : ""
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (mouse) => {
                    if (!bar.player) return;
                    if (mouse.button === Qt.RightButton) bar.player.next();
                    else if (bar.player.canTogglePlaying) bar.player.togglePlaying();
                }
                onWheel: (wheel) => {
                    if (!bar.player || !bar.player.volumeSupported) return;
                    bar.player.volume = Math.max(0, Math.min(1, bar.player.volume + (wheel.angleDelta.y > 0 ? 0.03 : -0.03)));
                }
            }
        }
    }

    Component {
        id: volumeComp
        Text {
            text: (Audio.muted ? "MUTE" : "VOL " + Audio.volume + "%") + (Audio.micMuted ? "  MIC×" : "")
            color: Audio.muted ? Theme.warning : Theme.fg
            font.family: Theme.font
            font.pixelSize: 11
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) Audio.toggleMicMute();
                    else Audio.toggleMute();
                }
                onWheel: (wheel) => Audio.change(wheel.angleDelta.y > 0 ? 3 : -3)
            }
        }
    }

    Component {
        id: netComp
        Text {
            text: Net.connected ? (Net.wifi ? "WIFI " + Net.strength + "%" : "NET") : "OFF"
            color: Net.connected ? Theme.fg : Theme.fgMuted
            font.family: Theme.font
            font.pixelSize: 11
            MouseArea {
                anchors.fill: parent
                onClicked: bar.spawn(["ghostty", "-e", "impala"])
            }
        }
    }

    Component {
        id: btComp
        Text {
            text: Bt.powered ? "BT " + Bt.connectedCount : "BT×"
            color: Bt.powered ? Theme.fg : Theme.fgMuted
            font.family: Theme.font
            font.pixelSize: 11
            MouseArea {
                anchors.fill: parent
                onClicked: bar.spawn(["ghostty", "-e", "bluetui"])
            }
        }
    }

    Component {
        id: batteryComp
        Text {
            visible: Sys.battery >= 0
            text: Sys.charging ? "CHG " + Sys.battery + "%" : "BAT " + Sys.battery + "%"
            color: Sys.battery >= 0 && Sys.battery < 15 ? Theme.error : Theme.fg
            font.family: Theme.font
            font.pixelSize: 11
        }
    }

    Component {
        id: sysComp
        Text {
            text: "L " + Sys.load.toFixed(1) + " · " + Sys.ramUsed + "%"
            color: Theme.fgMuted
            font.family: Theme.font
            font.pixelSize: 11
            MouseArea {
                anchors.fill: parent
                onClicked: bar.spawn(["ghostty", "-e", "dgop", "top"])
            }
        }
    }

    Component {
        id: weatherComp
        Text {
            text: Weather.temp
            color: Theme.fgMuted
            font.family: Theme.font
            font.pixelSize: 11
            MouseArea {
                anchors.fill: parent
                onClicked: bar.spawn(["sh", "-c", "ghostty -e sh -c 'curl -s wttr.in; read -r _'"])
            }
        }
    }

    Component {
        id: notifComp
        Text {
            text: Notif.count > 0 ? "● " + Notif.count : "○"
            color: Notif.count > 0 ? Theme.primary : Theme.fgMuted
            font.family: Theme.font
            font.pixelSize: 12
            MouseArea {
                anchors.fill: parent
                onClicked: bar.spawn(["quickshell", "ipc", "call", "notifications", "toggle"])
            }
        }
    }

    Component {
        id: trayComp
        Row {
            spacing: 6
            Repeater {
                model: SystemTray.items
                delegate: Item {
                    id: trayItem
                    required property var modelData
                    width: 16
                    height: 16

                    Image {
                        anchors.fill: parent
                        sourceSize.width: 16
                        sourceSize.height: 16
                        source: trayItem.modelData.icon
                    }

                    QsMenuAnchor {
                        id: trayMenu
                        menu: trayItem.modelData.menu
                        anchor.item: trayItem
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.MiddleButton) {
                                trayItem.modelData.secondaryActivate();
                            } else if (trayItem.modelData.hasMenu) {
                                trayMenu.open();
                            } else if (mouse.button === Qt.LeftButton) {
                                trayItem.modelData.activate();
                            } else {
                                trayItem.modelData.secondaryActivate();
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        const order = defaultOrder();
        for (const kind of order) moduleModel.append({ kind: kind });
    }
}
