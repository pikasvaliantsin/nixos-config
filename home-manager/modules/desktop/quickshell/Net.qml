pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Сеть через NetworkManager (nmcli).
Singleton {
    id: root

    property bool connected: false
    property bool wifi: false
    property string name: ""
    property int strength: 0

    function refresh() {
        if (!poll.running) poll.running = true;
    }

    Process {
        id: poll
        command: [
            "sh", "-c",
            "nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device status 2>/dev/null; "
            + "nmcli -t -f ACTIVE,SIGNAL,SSID device wifi 2>/dev/null | grep '^yes' | head -n1"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                let best = null;
                for (const line of lines) {
                    const p = line.split(":");
                    if (p.length >= 4 && p[2] === "connected" && p[1] !== "loopback") {
                        best = { type: p[1], name: p[3] };
                        break;
                    }
                }
                root.connected = best !== null;
                root.wifi = best !== null && best.type === "wifi";
                root.name = best !== null ? best.name : "";

                const wifiLine = lines.find(l => l.startsWith("yes:"));
                if (wifiLine) {
                    const p = wifiLine.split(":");
                    root.strength = parseInt(p[1] || "0", 10);
                } else {
                    root.strength = 0;
                }
            }
        }
        onExited: timer.restart()
    }

    Timer {
        id: timer
        interval: 5000
        repeat: false
        onTriggered: poll.running = true
    }

    Component.onCompleted: poll.running = true
}
