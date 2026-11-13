import QtQuick
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
    iconComponent: Component {
      Image {
        source: "../../agents/assets/opencode.svg"
        sourceSize.width: Style.bar.iconCanvas
        sourceSize.height: Style.bar.iconCanvas
        fillMode: Image.PreserveAspectFit
      }
    }
    onPressed: function() { root.toggle() }
  }

  OpenCodePanel {
    id: panel
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.opened
  }
}
