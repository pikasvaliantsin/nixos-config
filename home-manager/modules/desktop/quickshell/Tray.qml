pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray

// Состояние трея: какие приложения скрыты.
Singleton {
    id: root

    property var hidden: []

    readonly property var all: SystemTray.items.values
    readonly property var visible: all.filter(item => !root.isHidden(item.id))
    readonly property var ignored: all.filter(item => root.isHidden(item.id))

    function isHidden(id) {
        return root.hidden.indexOf(String(id)) >= 0;
    }

    function toggleHidden(id) {
        const key = String(id);
        const next = root.hidden.slice();
        const at = next.indexOf(key);
        if (at >= 0) next.splice(at, 1);
        else next.push(key);
        root.hidden = next;
        store.hidden = next;
    }

    function rebuild() {
        const raw = store.hidden;
        const arr = [];
        if (raw) {
            for (let i = 0; i < raw.length; i++) arr.push(String(raw[i]));
        }
        root.hidden = arr;
    }

    FileView {
        id: storeFile
        path: Quickshell.env("HOME") + "/.local/state/quickshell/tray.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.rebuild()
        onLoadFailed: root.hidden = []
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: store
            property list<string> hidden: []
        }
    }
}
