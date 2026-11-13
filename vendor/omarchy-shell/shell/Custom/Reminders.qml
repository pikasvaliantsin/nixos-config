pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Lightweight reminders: each one is a transient systemd user timer that
// calls notify-send. No Omarchy reminder flow or generated timer files.
Singleton {
  id: root

  property int count: 0

  function refresh() {
    if (!listProc.running) listProc.running = true
  }

  function start(minutes) {
    var n = Number(minutes)
    if (!isFinite(n) || n <= 0) return
    var unit = "omarchy-reminder-" + Date.now()
    var message = n + " minute" + (n === 1 ? "" : "s")
    Quickshell.execDetached([
      "systemd-run", "--user",
      "--on-active=" + n + "m",
      "--unit=" + unit,
      "--collect",
      "bash", "-lc",
      "notify-send -a Reminder 'Reminder' '" + message + "'"
    ])
    refreshTimer.restart()
  }

  function clear() {
    Quickshell.execDetached([
      "bash", "-lc",
      "systemctl --user stop $(systemctl --user list-units --type=timer --all --no-legend 'omarchy-reminder-*.timer' 2>/dev/null | awk '{print $1}') 2>/dev/null || true"
    ])
    refreshTimer.restart()
  }

  Process {
    id: listProc
    command: [
      "bash", "-lc",
      "systemctl --user list-units --type=timer --all --no-legend 'omarchy-reminder-*.timer' 2>/dev/null | wc -l"
    ]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var n = parseInt(String(text).trim(), 10)
        root.count = isFinite(n) ? Math.max(0, n) : 0
      }
    }
  }

  Timer {
    id: refreshTimer
    interval: 500
    repeat: false
    onTriggered: root.refresh()
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: refresh()

  IpcHandler {
    target: "reminders"
    function start(minutes: string): void { root.start(Number(minutes)) }
    function clear(): void { root.clear() }
    function count(): string { return String(root.count) }
  }
}
