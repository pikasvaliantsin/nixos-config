import QtQuick
import Quickshell
import qs.Commons
import qs.Custom
import qs.Ui

Panel {
  id: root
  moduleName: "local.opencode"
  ipcTarget: "local.opencode"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    bar: root.bar
    // The asset is a cream-white tile: correct on a light surface, but on a
    // themed dark bar it reads as a bright block instead of a bar glyph.
    // Draw the same mark (frame plus lower block) in the bar foreground, so
    // it follows the theme like the other icons. Geometry mirrors the
    // upstream SVG: a 240x300 frame, 60 units thick, with a 120x120 block
    // in its lower half.
    iconComponent: Component {
      Item {
        id: mark
        readonly property color tint: root.bar ? root.bar.foreground : Commons.Color.foreground
        readonly property real unit: Style.bar.iconSize / 5
        width: 4 * unit
        height: 5 * unit

        Rectangle {
          anchors.fill: parent
          color: "transparent"
          border.width: mark.unit
          border.color: mark.tint
          antialiasing: true
        }

        Rectangle {
          x: mark.unit
          y: 2 * mark.unit
          width: 2 * mark.unit
          height: 2 * mark.unit
          color: Qt.rgba(mark.tint.r, mark.tint.g, mark.tint.b, 0.45)
          antialiasing: true
        }
      }
    }
    onPressed: function(button) {
      if (button === Qt.RightButton) {
        if (root.opened) root.close()
        Util.launchScoped(["ghostty", "-e", "opencode"])
        return
      }
      root.toggle()
    }
  }

  OpenCodePanel {
    id: panel
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.opened
  }
}
