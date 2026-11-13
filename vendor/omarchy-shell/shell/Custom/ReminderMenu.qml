import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Custom
import qs.Ui

KeyboardPanel {
  id: root

  contentWidth: root.fittedContentWidth(Style.space(230))
  contentHeight: root.fittedContentHeight(menuColumn.implicitHeight)

  function run(minutes) {
    Reminders.start(minutes)
    if (root.owner && typeof root.owner.close === "function") root.owner.close()
  }

  Column {
    id: menuColumn
    width: parent.width
    spacing: Style.space(4)

    PanelSectionHeader {
      text: "Remind me in"
      width: parent.width
    }

    Repeater {
      model: [5, 10, 15, 30, 60]
      delegate: Button {
        required property int modelData
        width: menuColumn.width
        leftAlign: true
        text: modelData + " minutes"
        iconText: "󰢌"
        onClicked: root.run(modelData)
      }
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
      text: "Clear active reminders"
      iconText: "󰆴"
      enabled: Reminders.count > 0
      onClicked: {
        Reminders.clear()
        if (root.owner && typeof root.owner.close === "function") root.owner.close()
      }
    }
  }
}
