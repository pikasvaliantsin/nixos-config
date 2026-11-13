import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

BarIndicator {
  id: root

  property bool recording: false

  active: recording
  activeText: "󰻂"
  inactiveText: "󰻂"
  activeTooltipText: I18n.t("bar.stopRecording")
  inactiveTooltipText: I18n.t("bar.screenRecording")

  function refresh() {
    if (!root.bar || statusProc.running) return
    statusProc.command = ["omarchy-capture-screenrecording", "--status"]
    statusProc.running = true
  }

  onBarChanged: refresh()
  Component.onCompleted: refresh()

  Connections {
    target: root.indicatorHost
    ignoreUnknownSignals: true
    function onRefreshRequested() { root.refresh() }
  }

  Process {
    id: statusProc
    onExited: function(exitCode) {
      root.recording = exitCode === 0
    }
  }

  onPressed: function() {
    if (root.bar)
      root.bar.run(root.recording ? "omarchy-capture-screenrecording --stop-recording" : "omarchy-capture-screenrecording --fullscreen")
  }

  // The recorder is started by a niri binding, so the indicator has to notice
  // state changes on its own. The status probe is one short-lived process.
  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }
}
