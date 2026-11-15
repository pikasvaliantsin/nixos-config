import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Graphical front end for the sudo PAM helper. The helper owns authentication:
// it verifies the password with pamtester or runs fprintd itself, so this
// dialog is never trusted with a "success" result.
//
// The password field and fingerprint path are both live from the moment the
// dialog opens. Typing sends the password and cancels an in-flight scan;
// touching the sensor can succeed without waiting for a password attempt.
Item {
  id: root

  readonly property string socketPath: Quickshell.env("XDG_RUNTIME_DIR")
    ? Quickshell.env("XDG_RUNTIME_DIR") + "/omarchy-auth.sock" : ""
  property var client: null
  property string user: ""
  property string service: ""
  property string command: ""
  property string cwd: ""
  property string tty: ""
  property int requestPid: 0
  property string parentName: ""
  property int parentPid: 0
  property bool opened: false
  property bool checking: false
  property bool cancelling: false
  property bool fingerprintActive: false
  property bool fingerprintEnabled: true
  property bool statusError: false
  property string status: ""

  function send(payload) {
    if (!root.client) return false
    try {
      root.client.write(JSON.stringify(payload) + "\n")
      root.client.flush()
      return true
    } catch (e) {
      root.finish()
      return false
    }
  }

  function handle(line, connection) {
    var message
    try {
      message = JSON.parse(String(line))
    } catch (e) {
      return
    }

    if (message.type === "auth_request") {
      if (root.client && root.client !== connection) {
        connection.write(JSON.stringify({ event: "busy" }) + "\n")
        connection.flush()
        connection.connected = false
        return
      }
      root.client = connection
      root.user = String(message.user || "")
      root.service = String(message.service || "sudo")
      root.command = String(message.command || "")
      root.cwd = String(message.cwd || "")
      root.tty = String(message.tty || "")
      root.requestPid = Number(message.pid || 0)
      root.parentName = String(message.parent || "")
      root.parentPid = Number(message.parent_pid || 0)
      root.opened = true
      root.checking = false
      root.cancelling = false
      root.fingerprintActive = false
      root.fingerprintEnabled = message.fingerprint !== false
      root.statusError = false
      root.status = root.fingerprintEnabled
        ? I18n.t("auth.touch", "Touch the sensor or type your password")
        : I18n.t("auth.passwordOnly", "Enter your password")
      passwordInput.text = ""
      if (root.fingerprintEnabled) {
        Qt.callLater(function() { root.startFingerprint() })
      } else {
        Qt.callLater(function() {
          passwordInput.enabled = true
          passwordInput.forceActiveFocus()
        })
      }
      return
    }

    switch (String(message.event || "")) {
      case "success":
        root.finish()
        break
      case "password_failed":
        root.checking = false
        root.fingerprintActive = false
        root.statusError = true
        root.status = I18n.t("auth.passwordFailed", "Wrong password")
        passwordInput.text = ""
        Qt.callLater(function() {
          passwordInput.enabled = true
          passwordInput.forceActiveFocus()
        })
        break
      case "fingerprint_wait":
        root.fingerprintActive = true
        root.statusError = false
        root.status = I18n.t("auth.waiting", "Touch the fingerprint sensor…")
        break
      case "fingerprint_failed":
        root.fingerprintActive = false
        root.statusError = true
        root.status = I18n.t("auth.fingerprintFailed", "Fingerprint not recognized")
        break
      case "cancelled":
        root.finish()
        break
      case "busy":
        root.statusError = true
        root.status = I18n.t("auth.busy", "Another authentication is already open")
        break
    }
  }

  function startFingerprint() {
    if (!root.opened || root.cancelling || !root.fingerprintEnabled) return
    root.statusError = false
    root.fingerprintActive = true
    root.status = I18n.t("auth.waiting", "Touch the fingerprint sensor…")
    root.send({ action: "fingerprint" })
  }

  function submitPassword() {
    if (!root.opened || root.checking || root.cancelling) return
    var password = passwordInput.text
    if (password.length === 0) return
    root.checking = true
    root.fingerprintActive = false
    root.statusError = false
    root.status = I18n.t("auth.checking", "Checking…")
    passwordInput.text = ""
    passwordInput.enabled = false
    if (!root.send({ action: "password", password: password })) {
      root.checking = false
      passwordInput.enabled = true
    }
  }

  function cancel() {
    if (root.cancelling) return
    if (!root.client) {
      root.finish()
      return
    }
    root.cancelling = true
    root.statusError = false
    root.status = I18n.t("auth.cancelling", "Cancelling…")
    // Keep the socket open until the helper acknowledges. Closing here can
    // make the helper see EOF, return "no GUI", and fall through to pam_unix.
    if (!root.send({ action: "cancel" })) root.finish()
  }

  function finish() {
    root.opened = false
    root.checking = false
    root.cancelling = false
    root.fingerprintActive = false
    root.statusError = false
    root.status = ""
    root.command = ""
    root.cwd = ""
    root.tty = ""
    root.requestPid = 0
    root.parentName = ""
    root.parentPid = 0
    passwordInput.text = ""
    passwordInput.enabled = true
    root.client = null
  }

  SocketServer {
    id: server
    active: root.socketPath !== ""
    path: root.socketPath

    handler: Socket {
      id: connection

      parser: SplitParser {
        splitMarker: "\n"
        onRead: function(line) { root.handle(line, connection) }
      }

      onConnectedChanged: {
        if (!connected && root.client === connection) root.finish()
      }
    }
  }

  OverlayWindow {
    id: window
    shown: root.opened
    shownKeyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "omarchy-auth"

    onShownChanged: {
      if (shown) {
        Qt.callLater(function() {
          passwordInput.enabled = true
          passwordInput.forceActiveFocus()
        })
      }
    }

    Rectangle {
      anchors.fill: parent
      color: Commons.Color.menu.scrim
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.AllButtons
      onClicked: {}
    }

    BorderSurface {
      id: card
      anchors.centerIn: parent
      width: Math.min(Style.space(440), Math.max(Style.space(300), window.width - Style.gapsOut * 2))
      height: dialog.implicitHeight + card.padding * 2
      color: Commons.Color.popups.background
      borderSpec: Border.surfaceSpec("popups", "border", Commons.Color.popups.border, Math.max(1, Style.space(2)))
      radius: Style.cornerRadius
      padding: Style.space(18)

      Column {
        id: dialog
        anchors.fill: parent
        anchors.margins: card.padding
        spacing: Style.space(12)

        Text {
          width: parent.width
          text: I18n.t("auth.title", "Authentication")
          color: Commons.Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          font.bold: true
        }

        Text {
          width: parent.width
          text: {
            var value = root.user.length > 0 ? root.service + " · " + root.user : root.service
            if (root.requestPid > 0) value += " · pid " + root.requestPid
            return value
          }
          color: Commons.Color.popups.text
          opacity: 0.6
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }

        Text {
          width: parent.width
          visible: root.command.length > 0
          text: root.command
          color: Commons.Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.Wrap
          maximumLineCount: 4
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          visible: root.parentName.length > 0 || root.tty.length > 0 || root.cwd.length > 0
          text: {
            var parts = []
            if (root.parentName.length > 0) parts.push(root.parentName + (root.parentPid > 0 ? " (" + root.parentPid + ")" : ""))
            if (root.tty.length > 0) parts.push(root.tty)
            if (root.cwd.length > 0) parts.push(root.cwd)
            return I18n.t("auth.from", "Requested by") + ": " + parts.join(" · ")
          }
          color: Commons.Color.popups.text
          opacity: 0.55
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.Wrap
          maximumLineCount: 2
          elide: Text.ElideRight
        }

        TextField {
          id: passwordInput
          width: parent.width
          password: true
          placeholderText: I18n.t("auth.password", "Password")
          foreground: Commons.Color.popups.text
          accent: Commons.Color.accent
          onAccepted: root.submitPassword()
          Keys.onEscapePressed: root.cancel()
        }

        Row {
          width: parent.width
          spacing: Style.space(8)

          Button {
            visible: root.fingerprintEnabled
            text: I18n.t("auth.fingerprint", "Fingerprint")
            iconText: "󰈷"
            foreground: Commons.Color.popups.text
            accent: Commons.Color.accent
            bordered: true
            focusable: true
            onClicked: root.startFingerprint()
          }

          Item {
            width: Math.max(0, parent.width
              - (parent.children[0].visible ? parent.children[0].width : 0)
              - parent.children[2].width
              - parent.spacing * 2)
            height: 1
          }

          Button {
            text: I18n.t("auth.cancel", "Cancel")
            foreground: Commons.Color.popups.text
            accent: Commons.Color.accent
            bordered: true
            focusable: true
            onClicked: root.cancel()
          }
        }

        Text {
          width: parent.width
          visible: root.status.length > 0
          text: root.status
          color: root.statusError ? Commons.Color.urgent : Commons.Color.popups.text
          opacity: root.statusError ? 1.0 : 0.65
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
