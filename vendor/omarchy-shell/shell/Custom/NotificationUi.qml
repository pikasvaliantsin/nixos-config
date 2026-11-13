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

  function toggleDnd() {
    Notifications.toggleDoNotDisturb()
  }

  IpcHandler {
    target: "notifications"
    function toggle(): void { root.toggle() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function clear(): void { Notifications.clearAll() }
    function dnd(): void { root.toggleDnd() }
    function count(): string { return String(Notifications.count) }
    function quiet(): string { return Notifications.doNotDisturb ? "on" : "off" }
  }
}
