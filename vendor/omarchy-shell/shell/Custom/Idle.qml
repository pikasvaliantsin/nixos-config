pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Stay-awake via a systemd idle inhibitor. A compositor surface idle
// inhibitor would be enough on niri, but this also covers logind and is easy
// to see with `systemd-inhibit --list`.
Singleton {
  id: root

  property bool stayAwake: false

  function setStayAwake(value) {
    root.stayAwake = !!value
  }

  function toggle() {
    root.stayAwake = !root.stayAwake
  }

  Process {
    id: inhibitor
    command: ["systemd-inhibit", "--what=idle", "--why=Stay awake", "--mode=block", "sleep", "infinity"]
    running: root.stayAwake
  }

  IpcHandler {
    target: "idle"
    function toggle(): void { root.toggle() }
    function on(): void { root.setStayAwake(true) }
    function off(): void { root.setStayAwake(false) }
    function status(): string { return root.stayAwake ? "on" : "off" }
  }
}
