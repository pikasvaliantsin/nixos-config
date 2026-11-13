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
        return ["media", "sys", "weather", "tray", "volume", "net", "bt", "battery", "clipboard", "notifications", "clock"];
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
        case "clipboard": return clipboardComp;
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
        opacity: 0.94
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.35
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 8

        // --- воркспейсы + заголовок окна ---------------------------------
        Row {
            spacing: 5
            Repeater {
                model: bar.workspaces
                delegate: Rectangle {
                    required property var modelData
                    width: Math.max(24, label.implicitWidth + 12)
                    height: 24
                    radius: 8
                    color: modelData.is_active
                        ? Theme.primary
                        : (hover.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                    Behavior on color { ColorAnimation { duration: 120 } }

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
            Layout.leftMargin: 6
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
            spacing: 2
            Repeater {
                id: rightRepeater
                model: moduleModel
                delegate: Item {
                    id: slot
                    required property string kind
                    required property int index
                    property real dx: 0

                    width: loader.implicitWidth + 14
                    height: bar.height
                    opacity: drag.active ? 0.6 : 1.0

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: 8
                        color: hover.hovered ? Qt.rgba(1, 1, 1, 0.07) : "transparent"
                        HoverHandler { id: hover }
                    }

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
                spacing: 7
                property string now: Qt.formatDateTime(new Date(), "HH:mm")

                Text {
                    text: clockRow.now
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 13
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
                spacing: 7

                Icon {
                    glyph: bar.player && bar.player.isPlaying ? "\uf04c" : "\uf04b"
                    color: Theme.primary
                    size: 12
                }
                Text {
                    width: 150
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
        Item {
            implicitWidth: volumeRow.implicitWidth
            implicitHeight: volumeRow.implicitHeight

            Row {
                id: volumeRow
                anchors.centerIn: parent
                spacing: 5

                Icon {
                    glyph: Audio.muted ? "\uf026" : (Audio.volume < 35 ? "\uf027" : "\uf028")
                    color: Audio.muted ? Theme.warning : Theme.fg
                    size: 13
                }
                Text {
                    text: Audio.muted ? "—" : Audio.volume + "%"
                    color: Audio.muted ? Theme.warning : Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 11
                }
                Icon {
                    glyph: "\uf131"
                    color: Theme.warning
                    size: 11
                    visible: Audio.micMuted
                }
            }

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
        Item {
            implicitWidth: netRow.implicitWidth
            implicitHeight: netRow.implicitHeight

            Row {
                id: netRow
                anchors.centerIn: parent
                spacing: 5

                Icon {
                    glyph: Net.connected ? (Net.wifi ? "\uf1eb" : "\uf796") : "\uf05e"
                    color: Net.connected ? Theme.fg : Theme.fgMuted
                    size: 13
                }
                Text {
                    visible: Net.connected && Net.wifi
                    text: Net.strength + "%"
                    color: Theme.fgMuted
                    font.family: Theme.font
                    font.pixelSize: 10
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        bar.spawn(["ghostty", "-e", "impala"]);
                    } else {
                        const open = !Ui.netOpen;
                        Ui.btOpen = false;
                        Ui.notifOpen = false;
                        Clip.open = false;
                        Ui.netOpen = open;
                    }
                }
            }
        }
    }

    Component {
        id: btComp
        Item {
            implicitWidth: btRow.implicitWidth
            implicitHeight: btRow.implicitHeight

            Row {
                id: btRow
                anchors.centerIn: parent
                spacing: 5

                Icon {
                    glyph: "\uf294"
                    color: Bt.powered ? Theme.fg : Theme.fgMuted
                    size: 12
                }
                Text {
                    visible: Bt.connectedCount > 0
                    text: Bt.connectedCount
                    color: Theme.fgMuted
                    font.family: Theme.font
                    font.pixelSize: 10
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        bar.spawn(["ghostty", "-e", "bluetui"]);
                    } else {
                        const open = !Ui.btOpen;
                        Ui.netOpen = false;
                        Ui.notifOpen = false;
                        Clip.open = false;
                        Ui.btOpen = open;
                    }
                }
            }
        }
    }

    Component {
        id: batteryComp
        Item {
            implicitWidth: batteryRow.implicitWidth
            implicitHeight: batteryRow.implicitHeight
            visible: Sys.battery >= 0

            Row {
                id: batteryRow
                anchors.centerIn: parent
                spacing: 5

                Icon {
                    glyph: {
                        if (Sys.charging) return "\uf0e7";
                        if (Sys.battery > 90) return "\uf240";
                        if (Sys.battery > 60) return "\uf241";
                        if (Sys.battery > 40) return "\uf242";
                        if (Sys.battery > 15) return "\uf243";
                        return "\uf244";
                    }
                    color: Sys.battery < 15 && !Sys.charging ? Theme.error : Theme.fg
                    size: 13
                }
                Text {
                    text: Sys.battery + "%"
                    color: Sys.battery < 15 && !Sys.charging ? Theme.error : Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 11
                }
            }
        }
    }

    Component {
        id: sysComp
        Item {
            implicitWidth: sysRow.implicitWidth
            implicitHeight: sysRow.implicitHeight

            Row {
                id: sysRow
                anchors.centerIn: parent
                spacing: 5

                Icon {
                    glyph: "\uf2db"
                    color: Theme.fgMuted
                    size: 12
                }
                Text {
                    text: Sys.load.toFixed(1) + " · " + Sys.ramUsed + "%"
                    color: Theme.fgMuted
                    font.family: Theme.font
                    font.pixelSize: 10
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: bar.spawn(["ghostty", "-e", "dgop", "top"])
            }
        }
    }

    Component {
        id: weatherComp
        Item {
            implicitWidth: weatherRow.implicitWidth
            implicitHeight: weatherRow.implicitHeight

            Row {
                id: weatherRow
                anchors.centerIn: parent
                spacing: 5

                Icon {
                    glyph: {
                        const c = (Weather.condition || "").toLowerCase();
                        if (c.indexOf("rain") >= 0 || c.indexOf("drizzle") >= 0) return "\uf73d";
                        if (c.indexOf("snow") >= 0) return "\uf2dc";
                        if (c.indexOf("cloud") >= 0 || c.indexOf("overcast") >= 0) return "\uf0c2";
                        if (c.indexOf("clear") >= 0 || c.indexOf("sunny") >= 0) return "\uf185";
                        return "\uf6c4";
                    }
                    color: Theme.fgMuted
                    size: 13
                }
                Text {
                    text: Weather.temp
                    color: Theme.fgMuted
                    font.family: Theme.font
                    font.pixelSize: 11
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: bar.spawn(["sh", "-c", "ghostty -e sh -c 'curl -s wttr.in; read -r _'"])
            }
        }
    }

    Component {
        id: clipboardComp
        Item {
            implicitWidth: clipRow.implicitWidth
            implicitHeight: clipRow.implicitHeight

            Row {
                id: clipRow
                anchors.centerIn: parent
                spacing: 5

                Icon {
                    glyph: "\uf328"
                    color: Theme.fg
                    size: 13
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: bar.spawn(["quickshell", "ipc", "call", "clipboard", "toggle"])
            }
        }
    }

    Component {
        id: notifComp
        Item {
            implicitWidth: notifRow.implicitWidth
            implicitHeight: notifRow.implicitHeight

            Row {
                id: notifRow
                anchors.centerIn: parent
                spacing: 5

                Icon {
                    glyph: Notif.count > 0 ? "\uf0f3" : "\uf0a2"
                    color: Notif.count > 0 ? Theme.primary : Theme.fgMuted
                    size: 13
                }
                Text {
                    visible: Notif.count > 0
                    text: Notif.count
                    color: Theme.primary
                    font.family: Theme.font
                    font.pixelSize: 10
                    font.bold: true
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: bar.spawn(["quickshell", "ipc", "call", "notifications", "toggle"])
            }
        }
    }

    Component {
        id: trayComp
        Row {
            spacing: 7

            Repeater {
                model: Ui.trayExpanded ? Tray.all : []
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

            Item {
                visible: Tray.all.length > 0
                width: 18
                height: 16

                Icon {
                    anchors.centerIn: parent
                    glyph: Ui.trayExpanded ? "\uf053" : Tray.icon
                    color: Ui.trayExpanded ? Theme.primary : Theme.fgMuted
                    size: 11
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton) Tray.cycleIcon();
                        else Ui.trayExpanded = !Ui.trayExpanded;
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
