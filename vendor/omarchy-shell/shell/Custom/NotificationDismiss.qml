import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Custom

// Transparent full-screen layer under the center: click outside to close.
PanelWindow {
  id: root

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }
  color: "transparent"
  exclusiveZone: 0
  visible: NotificationUi.notificationsOpen
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "omarchy-notifications-dismiss"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  MouseArea {
    anchors.fill: parent
    onClicked: NotificationUi.close()
  }
}
