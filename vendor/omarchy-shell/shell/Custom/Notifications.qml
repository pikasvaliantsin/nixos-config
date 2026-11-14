pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.Commons

// The only notification server in the session. No toasts: every notification
// is tracked and shown in the center. Dismissed notifications move to a
// persisted history so closing the card or restarting the shell does not lose
// their text.
Singleton {
  id: root

  readonly property var list: server.trackedNotifications
  readonly property int count: list && list.values ? list.values.length : 0

  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy/notifications"
  readonly property string historyPath: root.stateDir + "/history.json"
  readonly property string quietPath: root.stateDir + "/quiet.json"

  // Newest first. Plain objects, safe to keep after the Notification object is
  // destroyed by the server.
  property var history: []
  property bool historyLoaded: false

  property bool doNotDisturb: false
  property bool quietLoaded: false

  function bounded(value, max) {
    return String(value || "").slice(0, max)
  }

  function historyEntry(notification, fromDnd) {
    return {
      appName: root.bounded(notification.appName, 256),
      appIcon: root.bounded(notification.appIcon, 256),
      summary: root.bounded(notification.summary, 2048),
      body: root.bounded(notification.body, 32768),
      urgency: Number(notification.urgency || 0),
      closedAt: Date.now(),
      dnd: !!fromDnd
    }
  }

  function addHistory(notification, fromDnd) {
    if (!notification) return
    root.history = [root.historyEntry(notification, fromDnd)].concat(root.history).slice(0, 50)
    root.saveHistory()
  }

  function removeHistory(index) {
    if (index < 0 || index >= root.history.length) return
    var next = root.history.slice()
    next.splice(index, 1)
    root.history = next
    root.saveHistory()
  }

  function clearHistory() {
    root.history = []
    root.saveHistory()
  }

  function clearAll() {
    const items = list.values.slice()
    for (let i = items.length - 1; i >= 0; i--) items[i].dismiss()
  }

  function parseHistory(raw) {
    var parsed
    try {
      parsed = JSON.parse(String(raw || "[]"))
    } catch (e) {
      return []
    }
    if (!Array.isArray(parsed)) return []

    var out = []
    for (var i = 0; i < parsed.length && out.length < 50; i++) {
      var entry = parsed[i]
      if (!entry || typeof entry !== "object") continue
      var closedAt = Number(entry.closedAt)
      if (!isFinite(closedAt) || closedAt <= 0) {
        var ts = Number(entry.ts)
        closedAt = isFinite(ts) && ts > 0 ? ts * 1000 : Date.now()
      }
      out.push({
        appName: root.bounded(entry.appName || entry.app, 256),
        appIcon: root.bounded(entry.appIcon, 256),
        summary: root.bounded(entry.summary, 2048),
        body: root.bounded(entry.body, 32768),
        urgency: Number(entry.urgency || 0),
        closedAt: closedAt,
        dnd: entry.dnd === true
      })
    }
    return out
  }

  function loadHistory(raw) {
    if (root.historyLoaded) return
    root.history = root.parseHistory(raw)
    root.historyLoaded = true
  }

  function saveHistory() {
    if (!root.historyLoaded) return
    historyFile.setText(JSON.stringify(root.history.slice(0, 50), null, 2) + "\n")
  }

  function loadQuiet(raw) {
    if (root.quietLoaded) return
    try {
      var parsed = JSON.parse(String(raw || "{}"))
      if (parsed && typeof parsed === "object" && typeof parsed.dnd === "boolean")
        root.doNotDisturb = parsed.dnd
    } catch (e) {
      root.doNotDisturb = false
    }
    root.quietLoaded = true
  }

  function saveQuiet() {
    if (!root.quietLoaded) return
    quietFile.setText(JSON.stringify({ dnd: root.doNotDisturb }) + "\n")
  }

  function setDoNotDisturb(value) {
    root.doNotDisturb = !!value
    root.saveQuiet()
  }

  function toggleDoNotDisturb() {
    root.setDoNotDisturb(!root.doNotDisturb)
  }

  // The omarchy-actions hint (omarchy-notification-send --action): up to three
  // label/argv pairs. Fail closed on malformed data, like the upstream parser.
  function parseExecActions(value) {
    var text = typeof value === "string" ? value : ""
    if (!text || text.length > 32768) return []

    var parsed
    try {
      parsed = JSON.parse(text)
    } catch (e) {
      return []
    }
    if (!Array.isArray(parsed) || parsed.length === 0 || parsed.length > 3) return []

    var out = []
    for (var i = 0; i < parsed.length; i++) {
      var entry = parsed[i]
      if (!entry || typeof entry !== "object" || typeof entry.label !== "string") return []
      var label = entry.label.trim()
      if (!label || label.length > 256) return []

      var argv = entry.argv
      if (!Array.isArray(argv) || argv.length === 0 || argv.length > 32) return []
      for (var j = 0; j < argv.length; j++) {
        if (typeof argv[j] !== "string" || argv[j].length > 4096 || argv[j].indexOf("\u0000") >= 0)
          return []
      }
      if (!argv[0] || argv[0].charAt(0) === "-") return []
      out.push({ label: label, argv: argv.slice() })
    }
    return out
  }

  function actionFromArgv(entry) {
    return {
      text: entry.label,
      invoke: function() { Util.execArgv(entry.argv) }
    }
  }

  function actionFromSender(action) {
    return {
      text: String(action.text || action.identifier || ""),
      invoke: function() { try { action.invoke() } catch (e) {} }
    }
  }

  // Buttons for a live card: Omarchy helper actions first, then the sender's
  // standard D-Bus actions.
  function actionsFor(notification) {
    if (!notification) return []
    var out = []
    var hints = notification.hints || ({})
    var custom = root.parseExecActions(hints["omarchy-actions"])
    for (var i = 0; i < custom.length; i++) out.push(root.actionFromArgv(custom[i]))

    var standard = notification.actions || []
    for (var j = 0; j < standard.length; j++) {
      if (String(standard[j].identifier || "") === "default") continue
      var action = root.actionFromSender(standard[j])
      if (action.text) out.push(action)
    }
    return out
  }

  FileView {
    id: historyFile
    path: root.historyPath
    atomicWrites: true
    blockLoading: true
    printErrors: false
    onLoaded: root.loadHistory(text())
    onLoadFailed: root.loadHistory("[]")
  }

  FileView {
    id: quietFile
    path: root.quietPath
    atomicWrites: true
    blockLoading: true
    printErrors: false
    onLoaded: root.loadQuiet(text())
    onLoadFailed: root.loadQuiet("{}")
  }

  NotificationServer {
    id: server
    keepOnReload: true
    actionsSupported: true
    bodySupported: true
    imageSupported: true
    bodyMarkupSupported: false
    onNotification: n => {
      // Do Not Disturb means no live card and no toast. Keep the notification
      // in history so it is still there when the user looks for it.
      if (root.doNotDisturb) {
        root.addHistory(n, true)
        return
      }
      n.tracked = true
      n.closed.connect(function() { root.addHistory(n) })
    }
  }
}
