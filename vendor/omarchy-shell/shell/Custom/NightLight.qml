pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Blue-light filter on niri. wlsunset holds gamma ramps while it runs and
// restores them when the process exits. The two temperatures are deliberately
// almost identical so the screen stays at ~4000K regardless of the hour.
Singleton {
  id: root

  property bool enabled: false

  function setEnabled(value) {
    root.enabled = !!value
  }

  function toggle() {
    root.enabled = !root.enabled
  }

  Process {
    id: sun
    command: ["wlsunset", "-t", "4000", "-T", "4001"]
    running: root.enabled
  }

  IpcHandler {
    target: "nightlight"
    function toggle(): void { root.toggle() }
    function on(): void { root.setEnabled(true) }
    function off(): void { root.setEnabled(false) }
    function status(): string { return root.enabled ? "on" : "off" }
  }
}
