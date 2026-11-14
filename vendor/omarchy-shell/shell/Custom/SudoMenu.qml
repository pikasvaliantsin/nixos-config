import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Custom
import qs.Ui

// Time picker for temporary passwordless sudo. The sudo call goes through
// the graphical PAM auth dialog, so enabling needs no terminal window.
KeyboardPanel {
  id: root

  focusTarget: escapeCatcher

  contentWidth: root.fittedContentWidth(Style.space(250))
  contentHeight: root.fittedContentHeight(menuColumn.implicitHeight)

  function enable(minutes) {
    Util.execArgv(["omarchy-sudo-passwordless", String(minutes)])
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
        text: "Confirm with your password or fingerprint."
        color: Commons.Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }
    }
  }
}
