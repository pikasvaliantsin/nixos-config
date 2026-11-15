import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Theme and wallpaper deck, in the spirit of Omarchy's own picker: the
// selected preview is a wide card in the middle, the neighbours peek out from
// behind it, fanned and rotated, and the name sits under the deck. No panel
// frame: the desktop stays visible behind a scrim.
Item {
  id: root

  property bool opened: false
  property string mode: "themes"
  property var items: []
  property int index: 0
  property bool loading: false
  property string notice: ""
  property string errorText: ""

  // Theme install receiver: `i` opens a URL field, theme-install clones and
  // applies in the background, and the deck reloads on the new theme.
  property bool urlInputActive: false
  property bool installing: false
  property string installStatus: ""
  property string installOutput: ""
  property string installError: ""
  property string pendingInstallSelection: ""

  readonly property bool isThemes: mode === "themes"
  readonly property var currentItem: items.length === 0 ? null : items[Math.max(0, Math.min(index, items.length - 1))]

  readonly property int deckWidth: Math.min(Style.space(780), Math.max(Style.space(420), panel.width - Style.gapsOut * 10))
  readonly property int deckHeight: Math.round(deckWidth * 0.56)

  readonly property var visibleCards: {
    var list = []
    for (var i = 0; i < root.items.length; i++) {
      var offset = i - root.index
      if (Math.abs(offset) <= 2)
        list.push({ index: i, offset: offset, item: root.items[i] })
    }
    return list
  }

  function itemTitle(item) {
    if (!item) return ""
    if (root.isThemes) return String(item.name || "")
    var path = String(item)
    var cut = path.lastIndexOf("/")
    return cut >= 0 ? path.slice(cut + 1) : path
  }

  function itemFile(item) {
    if (!item) return ""
    return root.isThemes ? String(item.preview || "") : String(item)
  }

  function openWith(nextMode) {
    root.mode = nextMode
    root.opened = true
    root.items = []
    root.index = 0
    root.notice = ""
    root.errorText = ""
    root.urlInputActive = false
    root.installing = false
    root.installStatus = ""
    root.pendingInstallSelection = ""
    root.loading = true
    listProc.running = false
    listProc.command = ["omarchy-gallery", root.mode]
    listProc.running = true
  }

  // The hotkey opens and closes: a second press on the same deck hides it.
  function toggleWith(nextMode) {
    if (root.opened && root.mode === nextMode) {
      root.close()
      return
    }
    root.openWith(nextMode)
  }

  function close() {
    root.opened = false
  }

  function move(step) {
    if (root.items.length === 0) return
    root.index = (root.index + step + root.items.length) % root.items.length
    root.notice = ""
  }

  function applyCurrent() {
    if (root.urlInputActive || root.installing) return
    if (!root.currentItem || root.loading) return
    root.errorText = ""
    if (root.isThemes)
      applyProc.command = ["theme-set", String(root.currentItem.name || "")]
    else
      applyProc.command = ["omarchy-gallery", "wallpaper", String(root.index)]
    applyProc.running = true
  }

  function startUrlInput() {
    if (!root.isThemes || root.installing) return
    root.urlInputActive = true
    root.installStatus = ""
    root.errorText = ""
    Qt.callLater(function() {
      if (!urlField) return
      urlField.text = ""
      urlField.forceActiveFocus()
    })
  }

  function cancelUrlInput() {
    root.urlInputActive = false
    if (!root.installing) root.installStatus = ""
    if (urlField) urlField.text = ""
  }

  function dismiss() {
    if (root.urlInputActive) root.cancelUrlInput()
    else root.close()
  }

  function installFromInput() {
    if (root.installing) return
    var url = urlField ? String(urlField.text).trim() : ""
    if (url === "") return
    root.installOutput = ""
    root.installError = ""
    root.installStatus = "Installing…"
    root.installing = true
    installProc.command = ["theme-install", url]
    installProc.running = true
  }

  function lastLine(value) {
    var lines = String(value || "").trim().split("\n")
    return lines.length > 0 ? lines[lines.length - 1] : ""
  }

  Process {
    id: listProc
    onExited: function(code, status) {
      if (!root.loading) return
      root.loading = false
      if (root.items.length === 0) root.errorText = "Cannot read the list"
    }
    stdout: StdioCollector {
      onStreamFinished: {
        root.loading = false
        var parsed = null
        try { parsed = JSON.parse(text) } catch (error) { parsed = null }
        if (!parsed || !parsed.items) {
          root.errorText = "Cannot read the list"
          return
        }
        root.items = parsed.items
        var wanted = root.pendingInstallSelection
        if (wanted !== "") {
          root.pendingInstallSelection = ""
          var installedAt = 0
          for (var j = 0; j < root.items.length; j++)
            if (String(root.items[j].name || "") === wanted) installedAt = j
          root.index = installedAt
        } else if (root.isThemes) {
          var at = 0
          for (var i = 0; i < root.items.length; i++)
            if (String(root.items[i].name || "") === String(parsed.current || "")) at = i
          root.index = at
        } else {
          root.index = Math.max(0, Math.min(Number(parsed.index) || 0, root.items.length - 1))
        }
      }
    }
  }

  Process {
    id: applyProc
    onExited: function(code, status) {
      if (code !== 0 || status !== 0) {
        root.errorText = "Apply failed"
        return
      }
      root.notice = root.isThemes ? "Theme applied" : "Wallpaper applied"
      // Picking a theme ends the interaction. Wallpapers keep the deck open
      // so several can be tried without reopening it each time.
      if (root.isThemes) closeAfterApply.restart()
    }
  }

  Timer {
    id: closeAfterApply
    interval: 220
    onTriggered: root.close()
  }

  Process {
    id: installProc
    onExited: function(code, status) {
      root.installing = false
      if (code !== 0 || status !== 0) {
        var message = root.lastLine(root.installError !== "" ? root.installError : installStderr.text)
        root.installStatus = message === "" ? "Install failed" : message
        return
      }

      var output = root.installOutput !== "" ? root.installOutput : installStdout.text
      var lines = String(output || "").trim().split("\n")
      var installed = ""
      for (var i = 0; i < lines.length; i++)
        if (lines[i].indexOf("theme-installed ") === 0)
          installed = lines[i].slice("theme-installed ".length)

      root.urlInputActive = false
      if (urlField) urlField.text = ""
      root.installStatus = installed === "" ? "Theme installed" : "Installed " + installed
      root.notice = root.installStatus
      root.pendingInstallSelection = installed
      clearInstallStatus.restart()

      // theme-install applies the theme; reload the deck so the new entry is
      // visible instead of leaving the old list on screen.
      root.loading = true
      listProc.running = false
      listProc.command = ["omarchy-gallery", root.mode]
      listProc.running = true
    }
    stdout: StdioCollector {
      id: installStdout
      waitForEnd: true
      onStreamFinished: root.installOutput = text
    }
    stderr: StdioCollector {
      id: installStderr
      waitForEnd: true
      onStreamFinished: root.installError = text
    }
  }

  ShellIpc {
    target: "gallery"

    function themes(): void { root.toggleWith("themes") }
    function wallpapers(): void { root.toggleWith("wallpapers") }
    function close(): void { root.close() }
    function next(): void { root.move(1) }
    function previous(): void { root.move(-1) }
    function apply(): void { root.applyCurrent() }
    function prompt(): string {
      root.startUrlInput()
      return "ok"
    }
    function install(url: string): string {
      if (!root.isThemes) return "not-themes"
      root.urlInputActive = true
      root.installStatus = ""
      if (urlField) urlField.text = String(url || "")
      root.installFromInput()
      return root.installing ? "installing" : "unknown"
    }
    function status(): string {
      return JSON.stringify({
        opened: root.opened,
        mode: root.mode,
        index: root.index,
        count: root.items.length,
        name: root.itemTitle(root.currentItem),
        loading: root.loading,
        error: root.errorText
      })
    }
  }

  OverlayWindow {
    id: panel
    shown: root.opened
    shownKeyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "omarchy-gallery"

    // Shortcuts live in the overlay window; ones on the shell root never see
    // this surface's keys.
    Shortcut { sequence: "Escape"; enabled: root.opened; onActivated: root.dismiss() }
    Shortcut {
      sequence: "i"
      enabled: root.opened && root.isThemes && !root.urlInputActive && !root.installing
      onActivated: root.startUrlInput()
    }
    Shortcut { sequence: "Left"; enabled: root.opened && !root.urlInputActive; onActivated: root.move(-1) }
    Shortcut { sequence: "Right"; enabled: root.opened && !root.urlInputActive; onActivated: root.move(1) }
    Shortcut { sequence: "Up"; enabled: root.opened && !root.urlInputActive; onActivated: root.move(-1) }
    Shortcut { sequence: "Down"; enabled: root.opened && !root.urlInputActive; onActivated: root.move(1) }
    Shortcut { sequence: "Return"; enabled: root.opened && !root.urlInputActive; onActivated: root.applyCurrent() }
    Shortcut { sequence: "Enter"; enabled: root.opened && !root.urlInputActive; onActivated: root.applyCurrent() }

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, 0.62)
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.AllButtons
      onClicked: root.close()
    }

    Column {
      anchors.centerIn: parent
      spacing: Style.space(22)

      // Mode label, quiet enough to stay out of the way.
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.isThemes ? "Themes" : "Wallpapers"
        color: Commons.Color.menu.text
        opacity: 0.45
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }

      Item {
        id: deck
        width: Math.round(root.deckWidth * 2.2)
        height: Math.round(root.deckHeight * 1.22)

        WheelHandler {
          onWheel: function(event) {
            root.move(event.angleDelta.y > 0 ? -1 : 1)
            event.accepted = true
          }
        }

        Repeater {
          model: root.visibleCards

          delegate: Item {
            id: tile
            required property var modelData

            readonly property int offset: modelData.offset
            readonly property bool current: offset === 0
            readonly property var item: modelData.item
            readonly property var meta: item && typeof item === "object" ? item : ({})
            readonly property string file: root.itemFile(item)
            readonly property bool hasPreview: file.charAt(0) === "/"
            readonly property real rank: Math.abs(offset)

            z: current ? 30 : (rank === 1 ? 20 : 10)
            width: current ? root.deckWidth
              : Math.round(root.deckWidth * (rank === 1 ? 0.84 : 0.7))
            height: Math.round(width * 0.56)
            x: deck.width / 2
              + offset * root.deckWidth * (rank === 1 ? 0.42 : 0.66)
              - width / 2
            y: (deck.height - height) / 2 + rank * Style.space(8)
            rotation: offset === 0 ? 0 : (offset < 0 ? -6 : 6) * rank
            opacity: current ? 1 : (rank === 1 ? 0.9 : 0.75)

            Behavior on x {
              enabled: !Style.reduceMotion
              NumberAnimation { duration: Style.duration(240); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut }
            }
            Behavior on width {
              enabled: !Style.reduceMotion
              NumberAnimation { duration: Style.duration(240); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut }
            }
            Behavior on height {
              enabled: !Style.reduceMotion
              NumberAnimation { duration: Style.duration(240); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut }
            }
            Behavior on rotation {
              enabled: !Style.reduceMotion
              NumberAnimation { duration: Style.duration(240); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut }
            }
            Behavior on opacity {
              enabled: !Style.reduceMotion
              NumberAnimation { duration: Style.duration(180) }
            }

            // Soft drop shadow, drawn as a dark offset card behind the preview.
            Rectangle {
              anchors.fill: parent
              anchors.topMargin: Style.space(10)
              radius: Style.cornerRadius + Style.space(2)
              color: "#00000055"
              visible: tile.current
            }

            Rectangle {
              id: surface
              anchors.fill: parent
              radius: Style.cornerRadius
              color: Commons.Color.menu.background
              border.width: tile.current ? Math.max(1, Style.space(2)) : 1
              border.color: tile.current
                ? Commons.Color.accent
                : Qt.rgba(Commons.Color.menu.border.r, Commons.Color.menu.border.g,
                          Commons.Color.menu.border.b, 0.35)
              clip: true

              Image {
                anchors.fill: parent
                source: tile.hasPreview ? "file://" + tile.file : ""
                visible: tile.hasPreview
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
              }

              // Native themes ship no screenshot; draw their palette.
              Rectangle {
                anchors.fill: parent
                visible: !tile.hasPreview
                color: tile.meta.bg ? String(tile.meta.bg) : Commons.Color.menu.background

                Column {
                  anchors.centerIn: parent
                  spacing: Style.space(8)

                  Repeater {
                    model: [tile.meta.fg || "#ffffff", tile.meta.accent || "#52e5d5", tile.meta.bg || "#000000"]

                    delegate: Rectangle {
                      required property var modelData
                      width: Math.max(Style.space(30), Math.min(tile.width * 0.5, Style.space(180)))
                      height: Style.space(18)
                      radius: Style.space(3)
                      color: String(modelData)
                      border.width: 1
                      border.color: Qt.rgba(1, 1, 1, 0.16)
                    }
                  }
                }
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (tile.current) root.applyCurrent()
                else root.index = tile.modelData.index
              }
            }
          }
        }

        Text {
          anchors.centerIn: parent
          visible: !root.loading && root.items.length === 0
          text: root.errorText !== "" ? root.errorText : "Nothing here"
          color: root.errorText !== "" ? Commons.Color.urgent : Commons.Color.menu.text
          opacity: root.errorText !== "" ? 1 : 0.5
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }
      }

      Column {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(6)

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.notice !== "" ? root.notice : root.itemTitle(root.currentItem)
          color: root.errorText !== "" ? Commons.Color.urgent : Commons.Color.menu.text
          font.family: Style.font.family
          font.pixelSize: Style.font.display
          font.bold: true
          style: Text.Outline
          styleColor: Commons.Color.menu.background
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.errorText !== "" ? root.errorText : (root.isThemes ? "Enter applies the theme" : "Enter applies the wallpaper")
          color: Commons.Color.menu.text
          opacity: 0.55
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.urlInputActive || root.installing || root.installStatus !== ""
        width: Math.min(root.deckWidth, Style.space(560))
        height: urlColumn.implicitHeight + Style.space(24)
        radius: Style.cornerRadius
        color: Commons.Color.menu.background
        border.width: 1
        border.color: Qt.rgba(Commons.Color.menu.border.r, Commons.Color.menu.border.g,
                              Commons.Color.menu.border.b, 0.55)

        Column {
          id: urlColumn
          anchors.centerIn: parent
          width: parent.width - Style.space(32)
          spacing: Style.space(8)

          TextField {
            id: urlField
            width: parent.width
            visible: root.urlInputActive
            enabled: !root.installing
            foreground: Commons.Color.menu.text
            placeholderText: "https://github.com/<owner>/omarchy-<name>-theme"
            onAccepted: root.installFromInput()
            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Escape) {
                root.cancelUrlInput()
                event.accepted = true
              }
            }
          }

          Text {
            width: parent.width
            visible: root.installStatus !== ""
            text: root.installStatus
            color: root.installStatus.indexOf("Installed") === 0
              ? Commons.Color.menu.text : Commons.Color.urgent
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WrapAnywhere
            maximumLineCount: 2
            elide: Text.ElideRight
          }
        }
      }

      Timer {
        id: clearInstallStatus
        interval: 5000
        onTriggered: if (!root.installing && root.installStatus.indexOf("Installed") === 0) root.installStatus = ""
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.isThemes
          ? "← → select · Enter apply · i install · Esc close"
          : "← → select · Enter apply · Esc close"
        color: Commons.Color.menu.text
        opacity: 0.35
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
  }
}
