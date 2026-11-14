import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Custom
import qs.Ui

// Time picker for temporary passwordless sudo. Enabling still asks for the
// password once in a small floating terminal, then the helper installs the
// time-limited sudoers rule.
KeyboardPanel {
  id: root

  contentWidth: root.fittedContentWidth(Style.space(250))
  contentHeight: root.fittedContentHeight(menuColumn.implicitHeight)

  function enable(minutes) {
    Util.execArgv(["omarchy-launch-floating-terminal", "sudo", "omarchy-sudo-passwordless", String(minutes)])
    if (root.owner && typeof root.owner.close === "function") root.owner.close()
  }

  Column {
    id: menuColumn
    width: parent.width
    spacing: Style.space(4)

    PanelSectionHeader {
      text: "Passwordless sudo for"
      width: parent.width
    }

    Repeater {
      model: [
        { minutes: 10, label: "10 minutes" },
        { minutes: 30, label: "30 minutes" },
        { minutes: 60, label: "1 hour" }
      ]

      delegate: Button {
        required property var modelData
        width: menuColumn.width
        leftAlign: true
        text: modelData.label
        iconText: "󰟵"
        onClicked: root.enable(modelData.minutes)
      }
    }

    Text {
      width: parent.width
      text: "Asks for your sudo password once in a small terminal."
      color: Commons.Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }
  }
}
