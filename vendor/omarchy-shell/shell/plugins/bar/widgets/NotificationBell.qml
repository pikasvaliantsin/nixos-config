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
    // The bar renders icons through Symbols Nerd Font, where U+F049A/F049C
    // are a shopping bag and a shredder. Use the Material Design bell pair in
    // the same private-use range so the unread and empty states read as a
    // notification control rather than a second printer-like glyph.
    text: root.count > 0 ? "\uDB80\uDC9A" : "\uDB80\uDC9C"
    labelText: root.count > 0 ? String(root.count) : ""
    active: root.count > 0
    onPressed: function() { NotificationUi.toggle() }
  }
}
