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

  property var pendingDoc: null

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

    onFullscreenRequested: function(doc) {
      root.pendingDoc = doc
      // Open after the click has been released. A layer surface opened in the
      // same frame receives that release and can dismiss itself immediately.
      fullscreenOpenTimer.restart()
    }
  }

  // Lives in the bar widget, not in the lazily built panel: closing the panel
  // must not unmap the reader's layer surface with it.
  PrintPreviewOverlay {
    id: fullscreen

    targetScreen: root.QsWindow.window ? root.QsWindow.window.screen : null

    onClosed: {
      root.pendingDoc = null
      panel.fullscreenCooldownUntil = Date.now() + 700
    }
  }

  Timer {
    id: fullscreenOpenTimer
    interval: 80
    repeat: false
    onTriggered: {
      if (!root.pendingDoc) return
      var doc = root.pendingDoc
      root.pendingDoc = null
      if (fullscreen.open(doc)) root.close()
    }
  }
}
