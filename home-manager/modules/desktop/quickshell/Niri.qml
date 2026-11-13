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
    property var layoutNames: []
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
        const name = Object.keys(ev)[0];

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
        } else if (ev.KeyboardLayoutsChanged) {
            const kl = ev.KeyboardLayoutsChanged.keyboard_layouts;
            root.layoutNames = kl.names;
            root.layoutName = kl.names[kl.current_idx] || "";
            root.layoutShort = root.shortLayout(root.layoutName);
        } else if (ev.KeyboardLayoutSwitched) {
            const idx = ev.KeyboardLayoutSwitched.idx;
            root.layoutName = root.layoutNames[idx] || "";
            root.layoutShort = root.shortLayout(root.layoutName);
        }

        // niri присылает точечные события (WorkspaceActivated, WindowFocusChanged
        // и т.п.) без полного состояния — проще перечитать снимок.
        switch (name) {
        case "WorkspaceActivated":
        case "WorkspaceActiveWindowChanged":
        case "WorkspaceUrgencyChanged":
        case "WindowFocusChanged":
        case "WindowOpenedOrChanged":
        case "WindowClosed":
        case "WindowUrgencyChanged":
        case "WindowLayoutsChanged":
            refreshTimer.restart();
            break;
        }
    }

    function run(args) {
        action.command = args;
        action.running = true;
    }

    function focusWorkspace(idx, output) {
        if (output) {
            // Сначала фокусируем нужный монитор: action focus-workspace
            // действует на активном выходе.
            run([
                "sh", "-c",
                "niri msg action focus-monitor " + JSON.stringify(output)
                + " && niri msg action focus-workspace " + JSON.stringify(String(idx))
            ]);
        } else {
            run(["niri", "msg", "action", "focus-workspace", String(idx)]);
        }
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

    Timer {
        id: refreshTimer
        interval: 50
        repeat: false
        onTriggered: {
            wsProc.running = true;
            focusProc.running = true;
        }
    }

    Process {
        id: wsProc
        command: ["niri", "msg", "--json", "workspaces"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.workspaces = JSON.parse(text);
                } catch (e) { /* keep previous */ }
            }
        }
    }

    Process {
        id: focusProc
        command: ["niri", "msg", "--json", "focused-window"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const w = JSON.parse(text);
                    root.focused = (w && w.id !== undefined) ? w : null;
                } catch (e) {
                    root.focused = null;
                }
            }
        }
    }

    Process {
        id: action
        onExited: running = false
    }
}
