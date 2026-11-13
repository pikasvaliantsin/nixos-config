import QtQuick
import qs.Commons
import qs.Custom
import qs.Ui

BarIndicator {
  id: root

  active: NightLight.enabled
  activeText: "󰔎"
  inactiveText: "󰔎"
  activeTooltipText: I18n.t("bar.dayLight")
  inactiveTooltipText: I18n.t("bar.nightLight")

  onPressed: function() { NightLight.toggle() }
}
