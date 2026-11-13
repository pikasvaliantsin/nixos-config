import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// One bar button for the capture menu. No Print key required: everything is
// reachable from here (and from Mod+Shift+S).
BarWidget {
  id: root
  moduleName: "local.capture"

  property bool menuOpen: false
  property bool recording: false

  readonly property bool opened: menuOpen

  function open() { menuOpen = true }
  function close() { menuOpen = false }
  function toggle() { menuOpen = !menuOpen }

  function run(command) {
    if (root.bar) root.bar.run(command)
    root.close()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    bar: root.bar
    text: "\uDB80\uDD00"
    active: root.recording
    onPressed: function() { root.toggle() }
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: if (!statusProc.running) statusProc.running = true
  }

  Process {
    id: statusProc
    command: ["omarchy-capture-screenrecording", "--status"]
    onExited: function(code) { root.recording = code === 0 }
  }

  KeyboardPanel {
    id: menu
    anchorItem: root
    owner: root
    bar: root.bar
    open: root.menuOpen
    contentWidth: menu.fittedContentWidth(Style.space(240))
    contentHeight: menu.fittedContentHeight(menuColumn.implicitHeight)

    Column {
      id: menuColumn
      width: parent.width
      spacing: Style.space(4)

      PanelSectionHeader {
        text: "Screenshot"
        width: parent.width
      }

      Button {
        width: parent.width
        leftAlign: true
        text: "Region"
        iconText: "󰹑"
        onClicked: root.run("omarchy-capture-screenshot region")
      }
      Button {
        width: parent.width
        leftAlign: true
        text: "Screen"
        iconText: "󰍹"
        onClicked: root.run("omarchy-capture-screenshot screen")
      }
      Button {
        width: parent.width
        leftAlign: true
        text: "Window"
        iconText: "󰖲"
        onClicked: root.run("omarchy-capture-screenshot window")
      }

      Rectangle {
        width: parent.width
        height: 1
        color: Commons.Color.popups.border
        opacity: 0.5
      }

      PanelSectionHeader {
        text: "Recording"
        width: parent.width
      }

      Button {
        width: parent.width
        leftAlign: true
        text: root.recording ? "Stop recording" : "Record screen"
        iconText: root.recording ? "󰓛" : "󰻂"
        active: root.recording
        onClicked: root.run(root.recording ? "omarchy-capture-screenrecording --stop-recording" : "omarchy-capture-screenrecording --fullscreen")
      }
      Button {
        width: parent.width
        leftAlign: true
        text: "Record region"
        iconText: "󰩫"
        enabled: !root.recording
        onClicked: root.run("omarchy-capture-screenrecording --region")
      }
    }
  }
}
