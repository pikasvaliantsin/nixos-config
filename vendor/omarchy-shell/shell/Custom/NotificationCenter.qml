import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Custom
import qs.Ui

// A single notification center on the focused output. One full-screen
// OverlayWindow holds the scrim, the card and the key catcher, so an outside
// click and Escape close it in one surface; the clipboard uses the same shape.
Item {
  id: root

  readonly property int cardWidth: Math.min(Style.space(360), Math.max(Style.space(280), panel.width - Style.gapsOut * 2))
  readonly property int cardHeight: Math.min(Style.space(560), Math.max(Style.space(140), column.implicitHeight + Style.space(24)))

  OverlayWindow {
    id: panel

    shown: NotificationUi.notificationsOpen
    shownKeyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "omarchy-notifications-center"

    onShownChanged: {
      if (shown) Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }
    onBackingWindowVisibleChanged: {
      if (shown && backingWindowVisible) Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }

    Rectangle {
      anchors.fill: parent
      color: Commons.Color.menu.scrim
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.AllButtons
      onClicked: NotificationUi.close()
    }

    Rectangle {
      id: card

      anchors {
        top: parent.top
        right: parent.right
        topMargin: Style.bar.sizeHorizontal + Style.gapsOut
        rightMargin: Style.gapsOut
      }
      width: root.cardWidth
      height: root.cardHeight
      color: Commons.Color.popups.background
      radius: Style.cornerRadius
      border.width: 1
      border.color: Commons.Color.popups.border

      // Clicks inside the card must not reach the scrim behind it.
      MouseArea {
        anchors.fill: parent
        onClicked: {}
      }

      Item {
        id: keyCatcher

        anchors.fill: parent
        focus: panel.shown
        Keys.priority: Keys.BeforeItem
        Keys.onEscapePressed: NotificationUi.close()
      }

      ColumnLayout {
        id: column

        anchors.fill: parent
        anchors.margins: Style.space(12)
        spacing: Style.space(8)

        RowLayout {
          id: header
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

        Flickable {
          id: scroller
          Layout.fillWidth: true
          Layout.preferredHeight: Math.max(Style.space(80), Math.min(Style.space(430), listColumn.implicitHeight))
          contentWidth: width
          contentHeight: listColumn.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds

          Column {
            id: listColumn
            width: scroller.width
            spacing: Style.space(6)

            Repeater {
              model: Notifications.list.values
              delegate: Card {
                required property var modelData
                width: listColumn.width
                entry: modelData
                live: true
              }
            }

            Rectangle {
              visible: Notifications.history.length > 0
              width: parent.width
              height: 1
              color: Commons.Color.popups.border
              opacity: 0.5
            }

            RowLayout {
              visible: Notifications.history.length > 0
              width: parent.width
              spacing: Style.space(8)

              Text {
                text: "History"
                color: Commons.Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
              }
              Text {
                text: "Clear"
                color: Commons.Color.accent
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                MouseArea {
                  anchors.fill: parent
                  onClicked: Notifications.clearHistory()
                }
              }
              Item { Layout.fillWidth: true }
            }

            Repeater {
              model: Notifications.history
              delegate: Card {
                required property var modelData
                required property int index
                width: listColumn.width
                entry: modelData
                live: false
                historyIndex: index
              }
            }

            Text {
              visible: Notifications.count === 0 && Notifications.history.length === 0
              width: parent.width
              text: "Nothing here"
              color: Commons.Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
            }
          }
        }
      }
    }

    component Card: Rectangle {
      id: card

      property var entry: null
      property bool live: false
      property int historyIndex: -1

      readonly property var actions: live && entry && entry.actions ? entry.actions : []
      readonly property string timeLabel: {
        if (!entry || !entry.closedAt) return ""
        return Qt.formatDateTime(new Date(entry.closedAt), "HH:mm")
      }

      width: listColumn.width
      height: cardBody.implicitHeight + Style.space(18)
      radius: Style.space(10)
      color: live ? Commons.Color.background : Commons.Color.popups.background
      border.width: 1
      border.color: live ? Qt.rgba(1, 1, 1, 0.06) : Commons.Color.popups.border

      MouseArea {
        anchors.fill: parent
        onClicked: if (card.live && card.entry) card.entry.dismiss()
      }

      Column {
        id: cardBody
        anchors {
          left: parent.left
          right: parent.right
          top: parent.top
          margins: Style.space(9)
          rightMargin: Style.space(20)
        }
        spacing: Style.space(3)

        Text {
          width: cardBody.width
          text: card.entry ? String(card.entry.appName || "") : ""
          color: Commons.Color.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
        Text {
          width: cardBody.width
          text: card.entry ? String(card.entry.summary || "") : ""
          color: Commons.Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          font.bold: true
          wrapMode: Text.Wrap
          maximumLineCount: 2
          elide: Text.ElideRight
        }
        Text {
          width: cardBody.width
          visible: text.length > 0
          text: card.entry ? String(card.entry.body || "") : ""
          color: Commons.Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.Wrap
          maximumLineCount: 6
          elide: Text.ElideRight
        }

        Flow {
          visible: card.actions.length > 0
          width: cardBody.width
          spacing: Style.space(12)

          Repeater {
            model: card.actions
            delegate: Text {
              required property var modelData

              visible: String(modelData.text || "").length > 0
              text: String(modelData.text || "")
              color: Commons.Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall

              MouseArea {
                anchors.fill: parent
                anchors.margins: -Style.space(3)
                cursorShape: Qt.PointingHandCursor
                onClicked: modelData.invoke()
              }
            }
          }
        }

        Text {
          visible: !card.live
          width: cardBody.width
          text: card.timeLabel
          color: Commons.Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }

      Text {
        visible: !card.live
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Style.space(6)
        text: "×"
        color: Commons.Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.title

        MouseArea {
          anchors.fill: parent
          anchors.margins: -Style.space(4)
          cursorShape: Qt.PointingHandCursor
          onClicked: Notifications.removeHistory(card.historyIndex)
        }
      }
    }
  }
}
