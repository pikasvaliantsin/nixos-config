pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Погода через wttr.in (без ключей и координат).
Singleton {
    id: root

    property string temp: ""
    property string condition: ""

    function refresh() {
        if (!poll.running) poll.running = true;
    }

    Process {
        id: poll
        command: ["curl", "-fsS", "--max-time", "10", "https://wttr.in/?format=%t|%C"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().replace(/^\+/, "").split("|");
                root.temp = p[0] || "";
                root.condition = p[1] || "";
            }
        }
        onExited: timer.restart()
    }

    Timer {
        id: timer
        interval: 1800000
        repeat: false
        onTriggered: poll.running = true
    }

    Component.onCompleted: poll.running = true
}
