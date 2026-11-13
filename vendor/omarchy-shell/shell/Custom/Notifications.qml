pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// The only notification server in the session. No toasts: every notification
// is tracked and shown in the center.
Singleton {
  id: root

  readonly property var list: server.trackedNotifications
  readonly property int count: list && list.values ? list.values.length : 0

  property bool doNotDisturb: false

  function setDoNotDisturb(value) {
    root.doNotDisturb = !!value
  }

  function toggleDoNotDisturb() {
    root.setDoNotDisturb(!root.doNotDisturb)
  }

  function clearAll() {
    const items = list.values.slice()
    for (let i = items.length - 1; i >= 0; i--) items[i].dismiss()
  }

  NotificationServer {
    id: server
    keepOnReload: true
    actionsSupported: true
    bodySupported: true
    imageSupported: true
    bodyMarkupSupported: false
    onNotification: n => {
      // Do Not Disturb means nothing reaches the center. The notification is
      // not tracked, so it never shows up in the list or the count.
      if (!root.doNotDisturb) n.tracked = true
    }
  }
}
