pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray

// Трей: иконки показываются прямо в баре, состояние разворота — в Ui.
Singleton {
    id: root

    readonly property var all: SystemTray.items.values
    readonly property var icons: ["\uf054", "\uf078", "\uf141", "\uf00a", "\uf466", "\uf0c9"]

    property string icon: "\uf054"

    function cycleIcon() {
        const at = root.icons.indexOf(root.icon);
        const next = root.icons[(at + 1) % root.icons.length];
        root.icon = next;
        store.icon = next;
    }

    function rebuild() {
        root.icon = store.icon && String(store.icon).length > 0
            ? String(store.icon)
            : "\uf054";
    }

    FileView {
        id: storeFile
        path: Quickshell.env("HOME") + "/.local/state/quickshell/tray.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.rebuild()
        onLoadFailed: root.icon = "\uf054"

        JsonAdapter {
            id: store
            property string icon: "\uf054"
        }
    }
}
