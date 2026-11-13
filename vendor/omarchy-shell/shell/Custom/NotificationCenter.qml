import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Custom

// A single notification center, on the focused output. It replaces the
// upstream Omarchy notification deck entirely.
PanelWindow {
  id: panel

  anchors {
    top: true
    right: true
  }
  margins {
    top: Style.gapsOut
    right: Style.gapsOut
  }

  implicitWidth: Style.space(360)
  implicitHeight: Math.min(Style.space(560), Math.max(Style.space(140), column.implicitHeight + Style.space(24)))
  color: "transparent"
  visible: NotificationUi.notificationsOpen && screen && screen.name === Niri.focusedOutput
  exclusiveZone: 0
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "omarchy-notifications-center"

  Rectangle {
    anchors.fill: parent
    color: Commons.Color.popups.background
    radius: Style.cornerRadius
    border.width: 1
    border.color: Commons.Color.popups.border
  }

  ColumnLayout {
    id: column
    anchors.fill: parent
    anchors.margins: Style.space(12)
    spacing: Style.space(8)

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(8)

      Text {
        text: "Notifications"
        color: Commons.Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.title
        font.bold: true
      }
      Text {
        text: Notifications.count > 0 ? String(Notifications.count) : ""
        color: Commons.Color.accent
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }
      Item { Layout.fillWidth: true }
      Text {
        text: "Clear"
        color: Notifications.count > 0 ? Commons.Color.accent : Commons.Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        MouseArea {
          anchors.fill: parent
          enabled: Notifications.count > 0
          onClicked: Notifications.clearAll()
        }
      }
      Text {
        text: "×"
        color: Commons.Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.title
        MouseArea {
          anchors.fill: parent
          onClicked: NotificationUi.close()
        }
      }
    }

    Rectangle {
      Layout.fillWidth: true
      height: 1
      color: Commons.Color.popups.border
      opacity: 0.5
    }

    ListView {
      id: listView
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      spacing: Style.space(6)
      model: Notifications.list
      visible: Notifications.count > 0

      delegate: Rectangle {
        id: card
        required property var modelData
        width: ListView.view.width
        height: body.implicitHeight + Style.space(18)
        radius: Style.space(10)
        color: Commons.Color.background
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.06)

        Column {
          id: body
          anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: Style.space(9)
          }
          spacing: Style.space(3)

          Text {
            width: body.width
            text: modelData.appName || ""
            color: Commons.Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }
          Text {
            width: body.width
            text: modelData.summary || ""
            color: Commons.Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
          }
          Text {
            width: body.width
            visible: text.length > 0
            text: modelData.body || ""
            color: Commons.Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.Wrap
            maximumLineCount: 6
            elide: Text.ElideRight
          }
        }

        MouseArea {
          anchors.fill: parent
          onClicked: card.modelData.dismiss()
        }
      }
    }

    Text {
      Layout.fillWidth: true
      visible: Notifications.count === 0
      text: "Nothing here"
      color: Commons.Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      horizontalAlignment: Text.AlignHCenter
    }
  }
}
