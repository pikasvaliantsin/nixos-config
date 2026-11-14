import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Custom
import qs.Ui

BarIndicator {
  id: root

  property bool recording: false
  property bool menuOpen: false

  // The indicator widget mounts this button outside the collapsible inactive
  // area so it is a target even before a recording exists.
  alwaysShow: settings && settings.alwaysShow === true

  function close() { root.menuOpen = false }

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
    if (root.recording) {
      root.menuOpen = false
      if (root.bar) root.bar.run("omarchy-capture-screenrecording --stop-recording")
      root.recording = false
      if (!statusProc.running) {
        statusProc.command = ["omarchy-capture-screenrecording", "--status"]
        statusProc.running = true
      }
      return
    }
    root.menuOpen = !root.menuOpen
  }

  // The recording control is a button, not a read-only indicator: clicking it
  // opens the capture menu. The status probe still keeps the icon live.
  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  CaptureMenu {
    id: captureMenu
    anchorItem: root
    bar: root.bar
    owner: root
    recording: root.recording
    open: root.menuOpen
  }
}
