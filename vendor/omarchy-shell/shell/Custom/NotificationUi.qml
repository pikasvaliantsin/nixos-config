pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property bool notificationsOpen: false
  property string tab: "recent"

  function toggle() {
    if (root.notificationsOpen) root.notificationsOpen = false
    else root.open()
  }

  function open() {
    root.tab = "recent"
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
    function toasts(): void { Notifications.toggleToasts() }
    function count(): string { return String(Notifications.count) }
    function quiet(): string { return Notifications.doNotDisturb ? "on" : "off" }
  }
}
