import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Small qalc-backed calculator overlay. It keeps the Walker `=` calculator
// without keeping Walker: type an expression, Enter copies the result.
Item {
  id: root

  property bool opened: false
  property string expression: ""
  property string result: ""
  property string error: ""
  property bool copied: false
  property string pendingOutput: ""

  function open(payload) {
    root.opened = true
    root.expression = ""
    root.result = ""
    root.error = ""
    root.copied = false
    root.pendingOutput = ""
    Qt.callLater(function() {
      input.text = ""
      input.forceActiveFocus()
    })
  }

  function close() {
    root.opened = false
    root.expression = ""
    root.result = ""
    root.error = ""
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open("{}")
  }

  function evaluate() {
    var text = String(root.expression || "").replace(/^=/, "").trim()
    root.result = ""
    root.error = ""
    root.copied = false
    root.pendingOutput = ""
    if (text.length === 0) return
    calcProc.command = ["/etc/profiles/per-user/" + Quickshell.env("USER") + "/bin/qalc", "-t", text]
    calcProc.running = true
  }

  function copyResult() {
    if (!root.result) return
    Quickshell.execDetached(["wl-copy", root.result])
    root.error = ""
    root.copied = true
  }

  ShellIpc {
    target: "local.calc"

    function open(payloadJson): void { root.open(payloadJson) }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  Timer {
    id: debounce
    interval: 100
    onTriggered: root.evaluate()
  }

  Process {
    id: calcProc
    stdout: SplitParser {
      onRead: function(line) { root.pendingOutput += line + "\n" }
    }
    onExited: {
      var value = String(root.pendingOutput).trim()
      root.pendingOutput = ""
      if (value.length === 0) {
        root.error = "Invalid expression"
        root.result = ""
      } else {
        root.result = value
      }
    }
  }

  OverlayWindow {
    id: panel
    shown: root.opened
    shownKeyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "omarchy-calc"

    onShownChanged: if (shown) Qt.callLater(function() { input.forceActiveFocus() })

    Rectangle {
      anchors.fill: parent
      color: Commons.Color.menu.scrim
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.AllButtons
      onClicked: root.close()
    }

    BorderSurface {
      id: card
      width: Math.min(Style.space(380), Math.max(Style.space(280), panel.width - Style.gapsOut * 4))
      height: content.implicitHeight + card.padding * 2
      anchors.centerIn: parent
      color: Commons.Color.menu.background
      borderSpec: Border.surfaceSpec("menu", "border", Commons.Color.menu.border, Math.max(1, Style.space(2)))
      radius: Style.cornerRadius
      padding: Style.space(16)

      MouseArea { anchors.fill: parent; onClicked: {} }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(10)

        Text {
          width: parent.width
          text: "Calculator"
          color: Commons.Color.menu.text
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          font.bold: true
        }

        TextField {
          id: input
          width: parent.width
          placeholderText: "Expression"
          foreground: Commons.Color.menu.text
          accent: Commons.Color.accent
          Keys.onEscapePressed: root.close()
          Keys.onReturnPressed: root.copyResult()
          Keys.onEnterPressed: root.copyResult()
          onTextChanged: {
            root.expression = text
            debounce.restart()
          }
        }

        Text {
          width: parent.width
          visible: root.result.length > 0 || root.error.length > 0
          text: root.error.length > 0 ? root.error : (root.result + (root.copied ? "  ✓" : ""))
          color: root.error.length > 0 ? Commons.Color.urgent : Commons.Color.menu.text
          font.family: Style.font.family
          font.pixelSize: Style.font.display
          wrapMode: Text.Wrap
          elide: Text.ElideRight
          maximumLineCount: 2
        }

        Text {
          width: parent.width
          text: "Enter copy result · Esc close"
          color: Commons.Color.menu.text
          opacity: 0.4
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
