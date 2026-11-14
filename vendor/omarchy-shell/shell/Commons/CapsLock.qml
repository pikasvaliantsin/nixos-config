pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Caps Lock state from the kernel key events, because niri has no modifier
// event and this keyboard's LED does not follow the XKB lock.
Singleton {
  id: root

  property bool active: false
  property bool known: false

  signal toggled(bool active)

  Process {
    id: watcher
    command: ["omarchy-capslock-watch"]
    running: true
    stdout: SplitParser {
      onRead: function(data) {
        var next = String(data).trim() === "1"
        if (!root.known) {
          root.known = true
          root.active = next
          return
        }
        if (root.active === next) return
        root.active = next
        root.toggled(next)
      }
    }
    onExited: restart.restart()
  }

  Timer {
    id: restart
    interval: 2000
    onTriggered: watcher.running = true
  }
}
