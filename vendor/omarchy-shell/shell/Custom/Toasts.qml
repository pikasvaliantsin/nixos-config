import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Optional notification toasts. Off by default; the notification center is
// still the only place where history is kept.
Item {
  id: root

  property var queue: []
  property var current: null
  property bool toastVisible: false

  readonly property int toastWidth: Style.space(360)

  function enqueue(entry) {
    if (!entry || !Notifications.toastsEnabled) return
    root.queue = root.queue.concat([entry])
    if (!root.current) root.showNext()
  }

  function showNext() {
    if (root.queue.length === 0) {
      root.current = null
      root.toastVisible = false
      hideTimer.stop()
      return
    }
    root.current = root.queue[0]
    root.queue = root.queue.slice(1)
    root.toastVisible = true
    hideTimer.restart()
  }

  function dismiss() {
    hideTimer.stop()
    root.current = null
    root.toastVisible = false
    Qt.callLater(function() { root.showNext() })
  }

  Connections {
    target: Notifications
    function onToastRequested(entry) { root.enqueue(entry) }
    function onToastsEnabledChanged() {
      if (!Notifications.toastsEnabled) {
        root.queue = []
        root.current = null
        root.toastVisible = false
        hideTimer.stop()
      }
    }
  }

  Timer {
    id: hideTimer
    interval: 5000
    onTriggered: root.dismiss()
  }

  PanelWindow {
    id: panel

    visible: root.toastVisible && root.current !== null
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-toasts"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
      top: true
      right: true
    }
    margins {
      top: Style.bar.sizeHorizontal + Style.gapsOut
      right: Style.gapsOut
    }
    implicitWidth: root.toastWidth
    implicitHeight: toastBody.implicitHeight + Style.space(24)

    Rectangle {
      anchors.fill: parent
      radius: Style.cornerRadius
      color: Commons.Color.popups.background
      border.width: 1
      border.color: Commons.Color.popups.border

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: hideTimer.stop()
        onExited: hideTimer.restart()
        onClicked: {
          NotificationUi.open()
          root.dismiss()
        }
      }

      Column {
        id: toastBody
        anchors {
          left: parent.left
          right: parent.right
          top: parent.top
          margins: Style.space(12)
          rightMargin: Style.space(28)
        }
        spacing: Style.space(3)

        Text {
          width: parent.width
          text: root.current ? String(root.current.appName || "") : ""
          color: Commons.Color.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
        Text {
          width: parent.width
          text: root.current ? String(root.current.summary || "") : ""
          color: Commons.Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          font.bold: true
          wrapMode: Text.Wrap
          maximumLineCount: 2
          elide: Text.ElideRight
        }
        Text {
          width: parent.width
          visible: text.length > 0
          text: root.current ? String(root.current.body || "") : ""
          color: Commons.Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.Wrap
          maximumLineCount: 3
          elide: Text.ElideRight
        }
      }

      Text {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Style.space(7)
        text: "×"
        color: Commons.Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.title

        MouseArea {
          anchors.fill: parent
          anchors.margins: -Style.space(4)
          onClicked: root.dismiss()
        }
      }
    }
  }
}
