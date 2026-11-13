import QtQuick
import qs.Commons
import qs.Custom
import qs.Ui

BarWidget {
  id: root
  moduleName: "local.notifications"

  readonly property int count: Notifications.count

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    bar: root.bar
    text: root.count > 0 ? "\uDB81\uDC9A" : "\uDB81\uDC9C"
    labelText: root.count > 0 ? String(root.count) : ""
    active: root.count > 0
    onPressed: function() { NotificationUi.toggle() }
  }
}
