pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Bluetooth через BlueZ (bluetoothctl).
Singleton {
    id: root

    property bool powered: false
    property int connectedCount: 0

    function refresh() {
        if (!poll.running) poll.running = true;
    }

    Process {
        id: poll
        command: [
            "sh", "-c",
            "bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo powered || echo off; "
            + "bluetoothctl devices Connected 2>/dev/null | wc -l"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                root.powered = (lines[0] || "").indexOf("powered") >= 0;
                root.connectedCount = parseInt(lines[1] || "0", 10);
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
