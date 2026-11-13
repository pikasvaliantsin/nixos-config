pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// История буфера через cliphist: текст и картинки.
Singleton {
    id: root

    property var entries: []
    property int rev: 0
    property bool open: false

    function toggle() {
        root.open = !root.open;
        if (root.open) root.refresh();
    }

    function refresh() {
        if (!listProc.running) listProc.running = true;
    }

    function shq(s) {
        return "'" + String(s).replace(/'/g, "") + "'";
    }

    function copy(entry) {
        let mime = "";
        if (entry.isImage) {
            mime = entry.preview.indexOf("jpeg") >= 0 ? "image/jpeg" : "image/png";
        }
        const cmd = "cliphist decode " + root.shq(entry.id)
            + " | wl-copy" + (mime ? " --type " + mime : "");
        copyProc.command = ["sh", "-c", cmd];
        copyProc.running = true;
        root.open = false;
    }

    function remove(entry) {
        delProc.command = ["sh", "-c", "printf '%s\\n' " + root.shq(entry.id) + " | cliphist delete"];
        delProc.running = true;
    }

    function wipe() {
        wipeProc.running = true;
    }

    function thumbPath(id) {
        return "file://" + Quickshell.env("HOME") + "/.cache/quickshell/clip/" + id + ".png?v=" + root.rev;
    }

    Process {
        id: listProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    if (!line) continue;
                    const tab = line.indexOf("\t");
                    if (tab < 0) continue;
                    const id = line.substring(0, tab);
                    const preview = line.substring(tab + 1);
                    out.push({
                        id: id,
                        preview: preview,
                        isImage: preview.indexOf("binary data") >= 0
                    });
                }
                root.entries = out.slice(0, 40);
                if (root.entries.some(e => e.isImage) && !thumbsProc.running) {
                    thumbsProc.running = true;
                }
            }
        }
    }

    Process {
        id: thumbsProc
        command: [
            "sh", "-c",
            "cache=\"$HOME/.cache/quickshell/clip\"; mkdir -p \"$cache\"; "
            + "cliphist list | head -n 40 | while IFS=$'\\t' read -r id prev; do "
            + "case \"$prev\" in *\"binary data\"*) "
            + "f=\"$cache/$id.png\"; "
            + "[ -s \"$f\" ] || cliphist decode \"$id\" > \"$f\" 2>/dev/null || rm -f \"$f\" ;; "
            + "esac; done; "
            + "find \"$cache\" -type f -mtime +7 -delete 2>/dev/null || true"
        ]
        onExited: root.rev += 1
    }

    Process {
        id: copyProc
        onExited: root.refresh()
    }

    Process {
        id: delProc
        onExited: root.refresh()
    }

    Process {
        id: wipeProc
        command: ["cliphist", "wipe"]
        onExited: root.refresh()
    }
}
