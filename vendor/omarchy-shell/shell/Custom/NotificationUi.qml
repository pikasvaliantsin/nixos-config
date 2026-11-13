pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property bool notificationsOpen: false

  function toggle() {
    root.notificationsOpen = !root.notificationsOpen
  }

  function open() {
    root.notificationsOpen = true
  }

  function close() {
    root.notificationsOpen = false
  }

  IpcHandler {
    target: "notifications"
    function toggle(): void { root.toggle() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function clear(): void { Notifications.clearAll() }
  }
}
