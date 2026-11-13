pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Громкость и микрофон через wpctl (PipeWire).
Singleton {
    id: root

    property int volume: 0
    property bool muted: false
    property bool micMuted: false
    property string sinkName: ""

    function refresh() {
        if (!poll.running) poll.running = true;
    }

    function toggleMute() {
        root.run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
    }

    function toggleMicMute() {
        root.run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]);
    }

    function change(delta) {
        root.run(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", (delta > 0 ? "+" : "-") + Math.abs(delta) + "%"]);
    }

    function run(args) {
        cmd.command = args;
        cmd.running = true;
    }

    Process {
        id: poll
        command: [
            "sh", "-c",
            "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null; "
            + "wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                if (lines.length > 0) {
                    const m = lines[0].match(/Volume:\s+([0-9.]+)/);
                    if (m) root.volume = Math.round(parseFloat(m[1]) * 100);
                    root.muted = lines[0].indexOf("[MUTED]") >= 0;
                }
                if (lines.length > 1) root.micMuted = lines[1].indexOf("[MUTED]") >= 0;
            }
        }
        onExited: timer.restart()
    }

    Timer {
        id: timer
        interval: 1000
        repeat: false
        onTriggered: poll.running = true
    }

    Process {
        id: cmd
        onExited: running = false
    }

    Component.onCompleted: poll.running = true
}
