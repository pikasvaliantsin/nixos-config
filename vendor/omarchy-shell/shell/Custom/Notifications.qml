pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// The only notification server in the session. No toasts: every notification
// is tracked and shown in the center. Dismissed notifications move to a small
// in-session history so closing the card does not lose their text.
Singleton {
  id: root

  readonly property var list: server.trackedNotifications
  readonly property int count: list && list.values ? list.values.length : 0

  // Newest first. Plain objects, safe to keep after the Notification object is
  // destroyed by the server.
  property var history: []

  property bool doNotDisturb: false

  function setDoNotDisturb(value) {
    root.doNotDisturb = !!value
  }

  function toggleDoNotDisturb() {
    root.setDoNotDisturb(!root.doNotDisturb)
  }

  function addHistory(notification) {
    if (!notification) return
    var entry = {
      appName: String(notification.appName || ""),
      appIcon: String(notification.appIcon || ""),
      summary: String(notification.summary || ""),
      body: String(notification.body || ""),
      urgency: Number(notification.urgency || 0),
      closedAt: Date.now()
    }
    root.history = [entry].concat(root.history).slice(0, 50)
  }

  function removeHistory(index) {
    if (index < 0 || index >= root.history.length) return
    var next = root.history.slice()
    next.splice(index, 1)
    root.history = next
  }

  function clearHistory() {
    root.history = []
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
      if (root.doNotDisturb) return
      n.tracked = true
      n.closed.connect(function() { root.addHistory(n) })
    }
  }
}
