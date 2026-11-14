import QtQuick
import Quickshell
import qs.Commons

// Bottom OSD for keyboard state. One instance in shell.qml, because it only
// reports events; the bar widget per output covers the persistent indicator.
Item {
  id: root

  property var host: null

  function show(payload) {
    if (!root.host || typeof root.host.summon !== "function") return
    root.host.summon("omarchy.osd", JSON.stringify(payload))
  }

  Connections {
    target: Niri
    function onEventReceived(event) {
      if (!event || !event.KeyboardLayoutSwitched) return
      var index = Number(event.KeyboardLayoutSwitched.idx)
      var names = Niri.keyboard && Niri.keyboard.names ? Niri.keyboard.names : []
      var name = index >= 0 && index < names.length ? String(names[index]) : ""
      if (name) root.show({ icon: "keyboard", message: name, duration: "1200" })
    }
  }

  Connections {
    target: CapsLock
    function onToggled(active) {
      root.show({
        icon: "keyboard",
        message: I18n.t(active ? "keyboard.capsOn" : "keyboard.capsOff",
                        active ? "Caps Lock ON" : "Caps Lock OFF"),
        duration: "1400"
      })
    }
  }
}
