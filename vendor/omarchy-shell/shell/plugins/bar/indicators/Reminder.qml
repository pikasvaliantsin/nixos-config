import QtQuick
import qs.Commons
import qs.Custom
import qs.Ui

BarIndicator {
  id: root

  property bool menuOpen: false

  function close() { root.menuOpen = false }

  active: Reminders.count > 0
  activeText: "󰢌"
  inactiveText: "󰢌"
  activeTooltipText: Reminders.count + " active reminder" + (Reminders.count === 1 ? "" : "s")
  inactiveTooltipText: "Reminders"

  onPressed: function() {
    root.menuOpen = !root.menuOpen
  }

  ReminderMenu {
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.menuOpen
  }
}
