import QtQuick
import qs.Commons
import qs.Custom
import qs.Ui

BarIndicator {
  id: root

  active: Idle.stayAwake
  // A mug without a saucer, which drew a line under the cup.
  activeText: ""
  inactiveText: ""
  activeTooltipText: I18n.t("bar.allowIdleLock")
  inactiveTooltipText: I18n.t("bar.stayAwake")

  onPressed: function() { Idle.toggle() }
}
