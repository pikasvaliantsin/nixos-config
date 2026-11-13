pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// История буфера в стиле omarchy: JSON-массив + файлы картинок.
Singleton {
    id: root

    property var entries: []
    property bool open: false

    function toggle() {
        root.open = !root.open;
    }

    function rebuild() {
        const raw = file.text();
        try {
            const parsed = JSON.parse(raw || "[]");
            root.entries = Array.isArray(parsed) ? parsed : [];
        } catch (e) {
            root.entries = [];
        }
    }

    function commit(next) {
        root.entries = next;
        file.setText(JSON.stringify(next, null, 2) + "\n");
    }

    function copy(entry) {
        if (entry.type === "image") {
            cmd.command = [
                "sh", "-c", "wl-copy --type \"$1\" < \"$2\"", "sh",
                entry.mime || "image/png", entry.path
            ];
        } else {
            cmd.command = [
                "sh", "-c", "printf %s \"$1\" | wl-copy", "sh",
                entry.text || ""
            ];
        }
        cmd.running = true;
        root.open = false;
    }

    function removeAt(index) {
        const arr = root.entries.slice();
        if (index < 0 || index >= arr.length) return;
        arr.splice(index, 1);
        root.commit(arr);
    }

    function clear() {
        root.commit([]);
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.local/state/quickshell/clipboard/history.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.rebuild()
        onLoadFailed: root.entries = []
    }

    Process {
        id: cmd
        onExited: running = false
    }
}
