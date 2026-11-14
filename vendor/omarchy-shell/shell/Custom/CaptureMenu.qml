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

  focusTarget: escapeCatcher

  property bool recording: false
  property string audioMode: "desktop"

  readonly property string audioModePath: Quickshell.env("HOME") + "/.local/state/omarchy/screenrecord-audio"

  function loadAudioMode(raw) {
    var value = String(raw || "").trim()
    if (value === "none" || value === "desktop" || value === "both") root.audioMode = value
  }

  function setAudioMode(value) {
    root.audioMode = value
    audioModeFile.setText(value + "\n")
  }

  function recordCommand(region) {
    var command = "omarchy-capture-screenrecording" + (region ? " --region" : " --fullscreen")
    if (root.audioMode === "desktop") command += " --with-desktop-audio"
    else if (root.audioMode === "both") command += " --with-desktop-audio --with-microphone-audio"
    return command
  }


  contentWidth: root.fittedContentWidth(Style.space(240))
  contentHeight: root.fittedContentHeight(menuColumn.implicitHeight)

  function run(command) {
    if (root.bar) root.bar.run(command)
    if (root.owner && typeof root.owner.close === "function") root.owner.close()
  }

  Item {
    id: escapeCatcher
    anchors.fill: parent
    focus: true
    Keys.onEscapePressed: function(event) {
      root.close()
      event.accepted = true
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
        text: "No audio"
        iconText: root.audioMode === "none" ? "󰄬" : ""
        active: root.audioMode === "none"
        enabled: !root.recording
        onClicked: root.setAudioMode("none")
      }
      Button {
        width: parent.width
        leftAlign: true
        text: "Desktop audio"
        iconText: root.audioMode === "desktop" ? "󰄬" : ""
        active: root.audioMode === "desktop"
        enabled: !root.recording
        onClicked: root.setAudioMode("desktop")
      }
      Button {
        width: parent.width
        leftAlign: true
        text: "Desktop + mic"
        iconText: root.audioMode === "both" ? "󰄬" : ""
        active: root.audioMode === "both"
        enabled: !root.recording
        onClicked: root.setAudioMode("both")
      }

      Rectangle {
        width: parent.width
        height: 1
        color: Commons.Color.popups.border
        opacity: 0.5
      }

      Button {
        width: parent.width
        leftAlign: true
        text: root.recording ? "Stop recording" : "Record screen"
        iconText: root.recording ? "󰓛" : "󰻂"
        active: root.recording
        onClicked: root.run(root.recording
          ? "omarchy-capture-screenrecording --stop-recording"
          : root.recordCommand(false))
      }
      Button {
        width: parent.width
        leftAlign: true
        text: "Record region"
        iconText: "󰩫"
        enabled: !root.recording
        onClicked: root.run(root.recordCommand(true))
      }
    }
  }

  // A FileView is not an Item, so it must not become a child of the panel
  // content. Declaring it as a property keeps it out of contentItem.
  property FileView audioModeFile: FileView {
    path: root.audioModePath
    atomicWrites: true
    blockLoading: true
    printErrors: false
    onLoaded: root.loadAudioMode(text())
    onLoadFailed: root.loadAudioMode("")
  }
}
