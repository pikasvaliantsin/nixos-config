import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Theme and wallpaper carousel.
//
// One overlay, two lists served by `omarchy-gallery`. The deck is a fan of tall
// slices: the selected one widens into a preview while the neighbours stay
// narrow, like the Omarchy theme picker.
Item {
  id: root

  property bool opened: false
  property string mode: "themes"
  property var items: []
  property int index: 0
  property bool loading: false
  property string notice: ""
  property string errorText: ""

  readonly property bool isThemes: mode === "themes"
  readonly property var currentItem: items.length === 0 ? null : items[Math.max(0, Math.min(index, items.length - 1))]

  readonly property int cardWidth: Math.min(Style.space(1000), Math.max(Style.space(600), panel.width - Style.gapsOut * 4))
  readonly property int cardHeight: Math.min(Style.space(560), Math.max(Style.space(400), panel.height - Style.gapsOut * 6))
  readonly property int sliceWidth: Style.space(62)
  readonly property int activeWidth: Style.space(300)
  readonly property int sliceHeight: Style.space(360)
  readonly property int tileGap: Style.space(8)

  function tileWidthAt(at) {
    return at === root.index ? root.activeWidth : root.sliceWidth
  }

  function stripOffset(at) {
    var x = 0
    for (var i = 0; i < at; i++) x += root.tileWidthAt(i) + root.tileGap
    return x
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
    root.loading = true
    listProc.running = false
    listProc.command = ["omarchy-gallery", root.mode]
    listProc.running = true
  }

  // The bar hotkey opens and closes: pressing it again on the same mode hides
  // the deck instead of reloading it.
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
    if (!root.currentItem || root.loading) return
    root.errorText = ""
    if (root.isThemes)
      applyProc.command = ["theme-set", String(root.currentItem.name || "")]
    else
      applyProc.command = ["omarchy-gallery", "wallpaper", String(root.index)]
    applyProc.running = true
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
        if (root.isThemes) {
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
      if (code !== 0 || status !== 0) root.errorText = "Apply failed"
      else root.notice = root.isThemes ? "Theme applied" : "Wallpaper applied"
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

    onShownChanged: if (shown) Qt.callLater(function() { keys.forceActiveFocus() })

    // Shortcuts belong to the overlay window, not to the shell root: an item
    // outside this surface never sees its keys.
    Shortcut { sequence: "Escape"; enabled: root.opened; onActivated: root.close() }
    Shortcut { sequence: "Left"; enabled: root.opened; onActivated: root.move(-1) }
    Shortcut { sequence: "Right"; enabled: root.opened; onActivated: root.move(1) }
    Shortcut { sequence: "Return"; enabled: root.opened; onActivated: root.applyCurrent() }
    Shortcut { sequence: "Enter"; enabled: root.opened; onActivated: root.applyCurrent() }

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
      width: root.cardWidth
      height: root.cardHeight
      anchors.centerIn: parent
      color: Commons.Color.menu.background
      borderSpec: Border.surfaceSpec("menu", "border", Commons.Color.menu.border, Math.max(1, Style.space(2)))
      radius: Style.cornerRadius
      padding: Style.space(16)

      MouseArea { anchors.fill: parent; onClicked: {} }

      FocusScope {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            root.close()
            event.accepted = true
          } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
            root.move(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
            root.move(1)
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.applyCurrent()
            event.accepted = true
          }
        }

        ColumnLayout {
          anchors.fill: parent
          anchors.leftMargin: card.contentLeftInset
          anchors.topMargin: card.contentTopInset
          anchors.rightMargin: card.contentRightInset
          anchors.bottomMargin: card.contentBottomInset
          spacing: Style.space(10)

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)

            Text {
              text: "Style"
              color: Commons.Color.menu.text
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
            }

            Button {
              text: "Themes"
              fontSize: Style.font.bodySmall
              selected: root.isThemes
              onClicked: if (!root.isThemes) root.openWith("themes")
            }
            Button {
              text: "Wallpapers"
              fontSize: Style.font.bodySmall
              selected: !root.isThemes
              onClicked: if (root.isThemes) root.openWith("wallpapers")
            }

            Item { Layout.fillWidth: true }

            Text {
              text: root.loading ? "Loading…" : (root.items.length + (root.items.length === 1 ? " item" : " items"))
              color: Commons.Color.menu.text
              opacity: 0.5
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }

          Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Commons.Color.menu.border
            opacity: 0.35
          }

          Item {
            id: stage
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            WheelHandler {
              onWheel: function(event) {
                root.move(event.angleDelta.y > 0 ? -1 : 1)
                event.accepted = true
              }
            }

            Row {
              id: strip
              spacing: root.tileGap
              y: (stage.height - height) / 2
              x: stage.width / 2 - root.stripOffset(root.index) - root.tileWidthAt(root.index) / 2
              Behavior on x {
                enabled: !Style.reduceMotion
                NumberAnimation {
                  duration: Style.duration(240)
                  easing.type: Easing.Bezier
                  easing.bezierCurve: Style.easeOut
                }
              }

              Repeater {
                model: root.items

                delegate: Item {
                  id: tile
                  required property var modelData
                  required property int index

                  readonly property bool current: index === root.index
                  readonly property var meta: modelData && typeof modelData === "object" ? modelData : ({})
                  readonly property string file: root.itemFile(modelData)
                  readonly property bool hasPreview: file.charAt(0) === "/"

                  width: root.tileWidthAt(index)
                  height: root.sliceHeight
                  opacity: current ? 1 : 0.5

                  Behavior on width {
                    enabled: !Style.reduceMotion
                    NumberAnimation {
                      duration: Style.duration(240)
                      easing.type: Easing.Bezier
                      easing.bezierCurve: Style.easeOut
                    }
                  }
                  Behavior on opacity {
                    enabled: !Style.reduceMotion
                    NumberAnimation { duration: Style.duration(180) }
                  }

                  Rectangle {
                    anchors.fill: parent
                    radius: Style.cornerRadius
                    color: Commons.Color.menu.background
                    border.width: tile.current ? Math.max(1, Style.space(2)) : 1
                    border.color: tile.current
                      ? Commons.Color.accent
                      : Qt.rgba(Commons.Color.menu.border.r, Commons.Color.menu.border.g,
                                Commons.Color.menu.border.b, 0.35)
                  }

                  Item {
                    id: frame
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: Style.space(6)
                    clip: true

                    Image {
                      id: preview
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
                      radius: Style.space(4)
                      color: tile.meta.bg ? String(tile.meta.bg) : Commons.Color.menu.background

                      Column {
                        anchors.centerIn: parent
                        spacing: Style.space(6)

                        Repeater {
                          model: [tile.meta.fg || "#ffffff", tile.meta.accent || "#52e5d5", tile.meta.bg || "#000000"]

                          delegate: Rectangle {
                            required property var modelData
                            width: Math.max(Style.space(24), tile.width - Style.space(40))
                            height: Style.space(14)
                            radius: Style.space(3)
                            color: String(modelData)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.16)
                          }
                        }
                      }
                    }

                    Text {
                      anchors.left: parent.left
                      anchors.right: parent.right
                      anchors.bottom: parent.bottom
                      anchors.margins: Style.space(8)
                      visible: tile.current
                      text: root.itemTitle(tile.modelData)
                      color: Commons.Color.menu.text
                      style: Text.Outline
                      styleColor: Commons.Color.menu.background
                      font.family: Style.font.family
                      font.pixelSize: Style.font.bodySmall
                      font.bold: true
                      elide: Text.ElideMiddle
                      horizontalAlignment: Text.AlignHCenter
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (tile.current) root.applyCurrent()
                      else root.index = tile.index
                    }
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

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)

            Text {
              Layout.fillWidth: true
              text: {
                if (root.notice !== "") return root.notice
                if (root.errorText !== "") return root.errorText
                if (root.currentItem) return root.isThemes ? "Enter applies the theme" : "Enter applies the wallpaper"
                return "← → select · Enter apply · Esc close"
              }
              color: root.errorText !== "" ? Commons.Color.urgent : Commons.Color.menu.text
              opacity: 0.7
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }

            Text {
              text: "← → select · Enter apply · Esc close"
              color: Commons.Color.menu.text
              opacity: 0.4
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }

            Button {
              text: "Apply"
              fontSize: Style.font.bodySmall
              enabled: root.items.length > 0 && !root.loading
              onClicked: root.applyCurrent()
            }
          }
        }
      }
    }
  }
}
