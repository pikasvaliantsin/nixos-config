import QtQuick
import qs.Commons
import qs.Custom
import qs.Ui

BarIndicator {
  id: root

  readonly property bool dnd: Notifications.doNotDisturb

  active: dnd
  activeText: "󰂛"
  inactiveText: "󰂛"
  activeTooltipText: I18n.t("bar.allowNotifications")
  inactiveTooltipText: I18n.t("bar.silenceNotifications")

  onPressed: function() {
    Notifications.toggleDoNotDisturb()
  }
}
