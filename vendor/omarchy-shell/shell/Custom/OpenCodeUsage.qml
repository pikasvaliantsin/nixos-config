pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// One compact OpenCode record, refreshed by the collector Omarchy already
// ships. The upstream multi-provider agents panel is intentionally not used.
Singleton {
  id: root

  property var data: ({})
  property bool loading: false

  readonly property var limits: data && Array.isArray(data.limits) ? data.limits : []
  readonly property string tier: data && data.tierLabel ? String(data.tierLabel) : ""
  readonly property string usageStatus: data && data.usageStatusText ? String(data.usageStatusText) : ""
  readonly property string authHelp: data && data.authHelpText ? String(data.authHelpText) : ""
  readonly property bool ready: !!(data && data.ready)
  readonly property int todayTokens: data && data.todayTotalTokens ? Number(data.todayTotalTokens) : 0
  readonly property int todayPrompts: data && data.todayPrompts ? Number(data.todayPrompts) : 0
  readonly property int todaySessions: data && data.todaySessions ? Number(data.todaySessions) : 0
  readonly property int totalPrompts: data && data.totalPrompts ? Number(data.totalPrompts) : 0
  readonly property int totalSessions: data && data.totalSessions ? Number(data.totalSessions) : 0

  function parse(raw) {
    try {
      root.data = JSON.parse(String(raw || "{}")) || {}
    } catch (e) {
      root.data = {}
    }
  }

  function refresh() {
    if (updateProc.running) return
    root.loading = true
    updateProc.running = true
  }

  FileView {
    id: usageFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/agents/usage/opencode.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.parse(text())
    onLoadFailed: root.parse("")
  }

  Process {
    id: updateProc
    command: ["omarchy-agent-usage-update", "opencode"]
    onExited: function() {
      root.loading = false
      usageFile.reload()
    }
  }

  Timer {
    interval: 300000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: {
    usageFile.reload()
    refresh()
  }
}
