import QtQuick
import qs.Commons
import qs.Ui

// Keyboard layout for the niri port. Niri reports the seat's layout list and
// current index over its event stream; a click cycles the layout.
//
// The label follows Caps Lock: lowercase while it is off, uppercase while it
// is on. CapsLock reads the kernel key events because niri exposes no modifier
// state (and this keyboard's LED does not follow the lock).
BarWidget {
  id: root
  moduleName: "omarchy.keyboard-layout"

  readonly property var layouts: Niri.keyboard && Niri.keyboard.names ? Niri.keyboard.names : []
  readonly property int currentIndex: Niri.keyboard && Niri.keyboard.current_idx !== undefined
    ? Number(Niri.keyboard.current_idx) : 0
  readonly property string fullName: {
    var index = root.currentIndex
    return index >= 0 && index < root.layouts.length ? String(root.layouts[index]) : ""
  }
  readonly property string code: root.codeFor(root.fullName)
  readonly property string label: root.code === "" ? ""
    : (CapsLock.active ? root.code.toUpperCase() : root.code.toLowerCase())

  function codeFor(name) {
    var value = String(name || "").trim()
    if (!value) return ""
    var known = {
      "English (US)": "en",
      "English (UK)": "en",
      "Russian": "ru",
      "Ukrainian": "uk",
      "German": "de",
      "French": "fr",
      "Spanish": "es",
      "Polish": "pl"
    }
    if (known[value]) return known[value]
    return value.split(/\s+/)[0].substring(0, 2).toLowerCase()
  }

  visible: root.label !== ""
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.label
    fontSize: Style.font.body
    horizontalMargin: 6
    tooltipText: root.fullName + (CapsLock.active
      ? " · " + I18n.t("keyboard.capsOn", "Caps Lock ON")
      : "")
    onPressed: function(button) {
      if (button === Qt.LeftButton) Niri.cycleLayout()
    }
  }
}
