import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Custom
import qs.Ui

BarIndicator {
  id: root

  property bool granted: false
  property bool refreshPending: false
  property bool menuOpen: false

  // Expiry epoch from the helper's marker file, and a 1 s clock while the
  // grant is active so the tooltip can count down.
  property int expiresAt: 0
  property int nowSeconds: Math.floor(Date.now() / 1000)
  readonly property int remainingSeconds: root.expiresAt > 0
    ? Math.max(0, root.expiresAt - root.nowSeconds) : 0

  readonly property string expiryLabel: {
    var total = root.remainingSeconds
    if (total <= 0) return ""
    var minutes = Math.floor(total / 60)
    var seconds = total % 60
    if (minutes >= 60)
      return Math.floor(minutes / 60) + "h " + (minutes % 60 < 10 ? "0" : "") + (minutes % 60) + "m"
    return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
  }

  activeTooltipText: root.expiryLabel !== ""
    ? I18n.t("bar.disablePasswordlessSudo") + " · " + root.expiryLabel
    : I18n.t("bar.disablePasswordlessSudo")

  HoverHandler { id: hoverHandler }

  Timer {
    interval: 1000
    running: root.granted
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      root.nowSeconds = Math.floor(Date.now() / 1000)
      // The bar copies the text when it shows the tooltip, so a live countdown
      // has to write it back while this button owns the tooltip.
      if (hoverHandler.hovered && root.bar && root.bar.tooltipTarget === root)
        root.bar.tooltipText = root.activeTooltipText
    }
  }

  FileView {
    id: markerFile
    path: Quickshell.env("XDG_RUNTIME_DIR") + "/omarchy-sudo-passwordless"
    watchChanges: true
    printErrors: false
    onLoaded: root.readMarker(text())
    onLoadFailed: root.expiresAt = 0
    onFileChanged: reload()
  }

  function readMarker(raw) {
    var value = parseInt(String(raw || "").trim(), 10)
    root.expiresAt = isFinite(value) ? value : 0
  }

  function close() { root.menuOpen = false }

  active: granted
  activeText: "󰟵"
  inactiveText: "󰟵"
  inactiveTooltipText: I18n.t("bar.passwordlessSudo")
  useActiveColor: true
  activeColor: Commons.Color.urgent

  function refresh() {
    // The marker appears only after a grant, so re-read it on every poll.
    if (markerFile.path !== "") markerFile.reload()
    if (!root.bar) return
    if (statusProc.running) {
      root.refreshPending = true
      return
    }
    root.refreshPending = false
    statusProc.running = true
  }

  onBarChanged: refresh()
  Component.onCompleted: refresh()

  // The state marker is a plain file under /run/user, so polling it is cheap.
  // It lets the button notice a grant started from the terminal.
  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Connections {
    target: root.indicatorHost
    ignoreUnknownSignals: true
    function onRefreshRequested() { root.refresh() }
  }

  Process {
    id: statusProc
    command: ["omarchy-sudo-passwordless", "--active"]
    onExited: function(exitCode, exitStatus) {
      root.granted = exitCode === 0 && exitStatus === 0
      if (root.refreshPending) Qt.callLater(root.refresh)
    }
  }

  Process {
    id: disableProc
    command: ["omarchy-sudo-passwordless", "--disable"]
    onExited: function(exitCode, exitStatus) {
      if ((exitCode !== 0 || exitStatus !== 0) && root.bar)
        Util.execArgv(["omarchy-notification-send", I18n.t("bar.passwordlessSudoDisableFailed"), I18n.t("bar.passwordlessSudoDisableFailedBody")])
      if (root.indicatorHost) root.indicatorHost.refresh()
      else root.refresh()
    }
  }

  onGrantedChanged: if (root.granted) root.menuOpen = false

  onPressed: function() {
    if (!root.bar || disableProc.running) return
    if (root.granted) {
      root.menuOpen = false
      disableProc.running = true
    } else {
      root.menuOpen = !root.menuOpen
    }
  }

  SudoMenu {
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.menuOpen
  }
}
