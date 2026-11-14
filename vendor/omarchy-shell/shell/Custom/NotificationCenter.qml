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

  property var recentGroups: []

  function buildGroups() {
    var groups = []
    var byKey = ({})

    function add(entry, live, historyIndex, recentIndex) {
      if (!entry) return
      var name = String(entry.appName || "Notifications")
      var key = name.toLowerCase()
      if (byKey[key] === undefined) {
        byKey[key] = groups.length
        groups.push({ appName: name, appIcon: String(entry.appIcon || ""), entries: [] })
      }
      groups[byKey[key]].entries.push({
        entry: entry,
        live: live,
        historyIndex: historyIndex,
        recentIndex: recentIndex
      })
    }

    var live = Notifications.list && Notifications.list.values ? Notifications.list.values : []
    for (var i = 0; i < live.length; i++) add(live[i], true, -1, -1)
    for (var j = 0; j < Notifications.recent.length; j++)
      add(Notifications.recent[j], false, -1, j)
    return groups
  }

  function rebuildGroups() { root.recentGroups = root.buildGroups() }

  Component.onCompleted: rebuildGroups()

  Connections {
    target: Notifications
    function onCountChanged() { root.rebuildGroups() }
    function onRecentChanged() { root.rebuildGroups() }
  }

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
            text: "Toasts"
            color: Notifications.toastsEnabled ? Commons.Color.accent : Commons.Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            MouseArea {
              anchors.fill: parent
              onClicked: Notifications.toggleToasts()
            }
          }
          Text {
            text: "DND"
            color: Notifications.doNotDisturb ? Commons.Color.urgent : Commons.Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            MouseArea {
              anchors.fill: parent
              onClicked: Notifications.toggleDoNotDisturb()
            }
          }
          Text {
            text: "Clear"
            color: (NotificationUi.tab === "history"
              ? Notifications.history.length > 0
              : Notifications.count > 0 || Notifications.recent.length > 0)
              ? Commons.Color.accent : Commons.Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            MouseArea {
              anchors.fill: parent
              onClicked: {
                if (NotificationUi.tab === "history") Notifications.clearHistory()
                else {
                  Notifications.clearAll()
                  Notifications.clearRecent()
                }
              }
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

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(12)

          Text {
            text: "Recent"
            color: NotificationUi.tab === "recent" ? Commons.Color.accent : Commons.Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: NotificationUi.tab === "recent"
            MouseArea {
              anchors.fill: parent
              onClicked: NotificationUi.tab = "recent"
            }
          }
          Text {
            text: "History"
            color: NotificationUi.tab === "history" ? Commons.Color.accent : Commons.Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: NotificationUi.tab === "history"
            MouseArea {
              anchors.fill: parent
              onClicked: NotificationUi.tab = "history"
            }
          }
          Item { Layout.fillWidth: true }
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
              model: NotificationUi.tab === "recent" ? root.recentGroups : []
              delegate: GroupDelegate {
                required property var modelData
                width: listColumn.width
                group: modelData
              }
            }

            Repeater {
              model: NotificationUi.tab === "history" ? Notifications.history : []
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
              visible: NotificationUi.tab === "recent"
                ? root.recentGroups.length === 0
                : Notifications.history.length === 0
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
      property int recentIndex: -1
      property bool replyOpen: false
      property string replyText: ""

      function sendReply() {
        if (!card.entry || !card.entry.hasInlineReply) return
        var text = String(card.replyText || "").trim()
        if (text.length === 0) return
        card.entry.sendInlineReply(text)
        card.replyText = ""
        card.replyOpen = false
        card.entry.dismiss()
      }

      readonly property var actions: live && entry ? Notifications.actionsFor(entry) : []
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

        Column {
          width: cardBody.width
          spacing: Style.space(4)
          visible: card.live && card.entry && card.entry.hasInlineReply && card.replyOpen

          TextField {
            id: replyField
            width: parent.width
            placeholderText: card.entry && card.entry.inlineReplyPlaceholder
              ? card.entry.inlineReplyPlaceholder : "Reply"
            foreground: Commons.Color.foreground
            accent: Commons.Color.accent
            onAccepted: card.sendReply()
            Keys.onEscapePressed: function(event) {
              card.replyOpen = false
              event.accepted = true
            }
            onTextChanged: card.replyText = text
          }
        }

        Text {
          visible: card.live && card.entry && card.entry.hasInlineReply && !card.replyOpen
          width: cardBody.width
          text: "Reply"
          color: Commons.Color.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          MouseArea {
            anchors.fill: parent
            anchors.margins: -Style.space(3)
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              card.replyOpen = true
              Qt.callLater(function() { replyField.forceActiveFocus() })
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
          onClicked: {
            if (card.recentIndex >= 0) Notifications.removeRecent(card.recentIndex)
            else Notifications.removeHistory(card.historyIndex)
          }
        }
      }
    }

    component GroupDelegate: Column {
      id: groupRoot

      property var group: null
      readonly property var entries: group && group.entries ? group.entries : []
      readonly property bool single: entries.length <= 1
      property bool expanded: false

      width: listColumn.width
      spacing: Style.space(6)

      Rectangle {
        visible: !groupRoot.single
        width: parent.width
        height: groupColumn.implicitHeight + Style.space(18)
        radius: Style.space(10)
        color: Commons.Color.popups.background
        border.width: 1
        border.color: Commons.Color.popups.border

        Column {
          id: groupColumn
          anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: Style.space(9)
          }
          spacing: Style.space(2)

          Text {
            width: parent.width
            text: groupRoot.group ? String(groupRoot.group.appName || "") : ""
            color: Commons.Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }
          Text {
            width: parent.width
            text: groupRoot.entries.length + (groupRoot.entries.length === 1 ? " notification" : " notifications")
            color: Commons.Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
          }
          Text {
            width: parent.width
            text: groupRoot.entries.length > 0 && groupRoot.entries[0].entry
              ? String(groupRoot.entries[0].entry.summary || "") : ""
            color: Commons.Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            maximumLineCount: 1
            elide: Text.ElideRight
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: groupRoot.expanded = !groupRoot.expanded
        }
      }

      Repeater {
        model: groupRoot.single || groupRoot.expanded ? groupRoot.entries : []

        delegate: Card {
          required property var modelData
          width: groupRoot.width
          entry: modelData.entry
          live: modelData.live
          historyIndex: modelData.historyIndex
          recentIndex: modelData.recentIndex
        }
      }
    }
  }
}
