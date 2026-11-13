pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// История буфера в стиле omarchy: JSON + файлы картинок.
Singleton {
    id: root

    property var entries: []
    property bool open: false
    property string query: ""
    property string typeFilter: "all"   // all | text | image
    property string sortMode: "recent"  // recent | type

    readonly property var visibleEntries: {
        const q = root.query.trim().toLowerCase();
        const arr = root.entries.filter(e => {
            if (root.typeFilter !== "all" && e.type !== root.typeFilter) return false;
            if (!q) return true;
            const hay = e.type === "image"
                ? ("image " + (e.mime || "") + " " + (e.capturedAt || ""))
                : ((e.text || "") + " " + (e.capturedAt || ""));
            return hay.toLowerCase().indexOf(q) >= 0;
        });

        arr.sort((a, b) => {
            const pa = a.pinned ? 1 : 0;
            const pb = b.pinned ? 1 : 0;
            if (pa !== pb) return pb - pa;
            if (root.sortMode === "type") {
                const ta = a.type === "image" ? 1 : 0;
                const tb = b.type === "image" ? 1 : 0;
                if (ta !== tb) return ta - tb;
            }
            return 0;
        });
        return arr;
    }

    function entryKey(entry) {
        if (!entry) return "";
        return entry.type === "image"
            ? "image:" + (entry.path || "")
            : "text:" + (entry.text || "");
    }

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

    function togglePin(entry) {
        const key = root.entryKey(entry);
        root.commit(root.entries.map(e => {
            if (root.entryKey(e) !== key) return e;
            return Object.assign({}, e, { pinned: !e.pinned });
        }));
    }

    function remove(entry) {
        const key = root.entryKey(entry);
        root.commit(root.entries.filter(e => root.entryKey(e) !== key));
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
