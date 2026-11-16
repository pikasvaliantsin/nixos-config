import QtQuick
import Quickshell
import qs.Commons
import qs.Custom
import qs.Ui

Panel {
  id: root
  moduleName: "local.print"
  ipcTarget: "local.print"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    bar: root.bar
    text: "\uDB81\uDC2A"
    // The same signal the notification bell uses: a number beside the glyph,
    // in the bar's active colour, while the folder holds unprinted documents.
    labelText: PrintService.newCount > 0 ? String(PrintService.newCount) : ""
    active: PrintService.newCount > 0
    onPressed: function(button) {
      if (button === Qt.RightButton) {
        if (root.opened) root.close()
        if (PrintService.folder !== "") {
          Util.launchScoped(["xdg-open", PrintService.folder])
        }
        return
      }
      root.toggle()
    }
  }

  PrintPanel {
    id: panel
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.opened
  }
}
