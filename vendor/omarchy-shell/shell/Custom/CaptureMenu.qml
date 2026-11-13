import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Shared capture popup. Anchored to whatever bar control opened it; the
// recording indicator uses it, so recording is a button, not a read-only dot.
KeyboardPanel {
  id: root

  property bool recording: false

  contentWidth: root.fittedContentWidth(Style.space(240))
  contentHeight: root.fittedContentHeight(menuColumn.implicitHeight)

  function run(command) {
    if (root.bar) root.bar.run(command)
    if (root.owner && typeof root.owner.close === "function") root.owner.close()
  }

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
