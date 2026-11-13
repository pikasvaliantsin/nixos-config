pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// CPU load / RAM / батарея — из /proc и /sys, без демонов.
Singleton {
    id: root

    property real load: 0
    property int ramUsed: 0
    property int ramTotal: 1
    property int battery: -1
    property bool charging: false

    function refresh() {
        if (!poll.running) poll.running = true;
    }

    Process {
        id: poll
        command: [
            "sh", "-c",
            "cat /proc/loadavg; "
            + "awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{print t, a}' /proc/meminfo; "
            + "for b in /sys/class/power_supply/BAT*; do [ -d \"$b\" ] && cat \"$b/capacity\" \"$b/status\" && break; done"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                root.load = parseFloat((lines[0] || "0").split(" ")[0]) || 0;
                const mem = (lines[1] || "").split(" ");
                if (mem.length >= 2) {
                    const total = parseInt(mem[0], 10) || 1;
                    const avail = parseInt(mem[1], 10) || 0;
                    root.ramTotal = total;
                    root.ramUsed = Math.max(0, Math.round(((total - avail) / total) * 100));
                }
                if (lines.length > 2) {
                    root.battery = parseInt(lines[2], 10);
                    root.charging = (lines[3] || "").indexOf("Charging") >= 0;
                } else {
                    root.battery = -1;
                }
            }
        }
        onExited: timer.restart()
    }

    Timer {
        id: timer
        interval: 2000
        repeat: false
        onTriggered: poll.running = true
    }

    Component.onCompleted: poll.running = true
}
