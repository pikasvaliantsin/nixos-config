pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Состояние niri через IPC: workspaces, окна, раскладка.
Singleton {
    id: root

    property var workspaces: []
    property var windows: ({})
    property var focused: null
    property string layoutName: ""
    property string layoutShort: ""

    function shortLayout(name) {
        if (!name) return "";
        if (name.indexOf("Russian") >= 0) return "RU";
        if (name.indexOf("English") >= 0) return "EN";
        return name.substring(0, 2).toUpperCase();
    }

    function applyEvent(line) {
        let ev;
        try {
            ev = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (ev.WorkspacesChanged) {
            root.workspaces = ev.WorkspacesChanged.workspaces;
        } else if (ev.WindowsChanged) {
            const map = ({});
            let focus = null;
            for (const w of ev.WindowsChanged.windows) {
                map[w.id] = w;
                if (w.is_focused) focus = w;
            }
            root.windows = map;
            root.focused = focus;
        } else if (ev.WindowFocusChanged) {
            const id = ev.WindowFocusChanged.id;
            root.focused = id === null ? null : (root.windows[id] || root.focused);
        } else if (ev.WindowOpenedOrChanged) {
            const w = ev.WindowOpenedOrChanged.window;
            const map = root.windows;
            map[w.id] = w;
            root.windows = map;
            if (w.is_focused) root.focused = w;
        } else if (ev.WindowClosed) {
            const map = root.windows;
            delete map[ev.WindowClosed.id];
            root.windows = map;
        } else if (ev.KeyboardLayoutsChanged) {
            const kl = ev.KeyboardLayoutsChanged.keyboard_layouts;
            root.layoutName = kl.names[kl.current_idx] || "";
            root.layoutShort = root.shortLayout(root.layoutName);
        }
    }

    function run(args) {
        action.command = args;
        action.running = true;
    }

    function focusWorkspace(idx) {
        run(["niri", "msg", "action", "focus-workspace", String(idx)]);
    }

    function toggleOverview() {
        run(["niri", "msg", "action", "toggle-overview"]);
    }

    function workspacesFor(output) {
        return root.workspaces
            .filter(w => w.output === output)
            .sort((a, b) => a.idx - b.idx);
    }

    Process {
        id: stream
        command: ["niri", "msg", "--json", "event-stream"]
        running: true
        stdout: SplitParser {
            onRead: line => root.applyEvent(line)
        }
        onExited: retry.restart()
    }

    Timer {
        id: retry
        interval: 1000
        repeat: false
        onTriggered: stream.running = true
    }

    Process {
        id: action
        onExited: running = false
    }
}
