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
// One overlay, two lists served by `omarchy-gallery`: themes apply through
// theme-set, wallpapers through the same sorted list bg-cycle uses, so the
// chosen index survives and arrows in the carousel match the keyboard cycle.
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

  readonly property int cardWidth: Math.min(Style.space(920), Math.max(Style.space(560), panel.width - Style.gapsOut * 4))
  readonly property int cardHeight: Math.min(Style.space(520), Math.max(Style.space(380), panel.height - Style.gapsOut * 6))
  readonly property int tileWidth: Style.space(250)
  readonly property int tileHeight: Style.space(290)
  readonly property int tileGap: Style.space(14)

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
    // A missing helper must surface as an error, not an endless spinner.
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

    function themes(): void { root.openWith("themes") }
    function wallpapers(): void { root.openWith("wallpapers") }
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

  Shortcut { sequence: "Escape"; enabled: root.opened; onActivated: root.close() }
  Shortcut { sequence: "Left"; enabled: root.opened; onActivated: root.move(-1) }
  Shortcut { sequence: "Right"; enabled: root.opened; onActivated: root.move(1) }
  Shortcut { sequence: "Return"; enabled: root.opened; onActivated: root.applyCurrent() }

  OverlayWindow {
    id: panel
    shown: root.opened
    shownKeyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "omarchy-gallery"

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
            x: stage.width / 2 - root.index * (root.tileWidth + root.tileGap) - root.tileWidth / 2
            Behavior on x {
              enabled: !Style.reduceMotion
              NumberAnimation {
                duration: Style.duration(220)
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

                width: root.tileWidth
                height: root.tileHeight
                scale: current ? 1.0 : 0.9
                opacity: current ? 1 : 0.45

                Behavior on scale {
                  enabled: !Style.reduceMotion
                  NumberAnimation { duration: Style.duration(160) }
                }
                Behavior on opacity {
                  enabled: !Style.reduceMotion
                  NumberAnimation { duration: Style.duration(160) }
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
                  anchors.margins: Style.space(6)
                  height: parent.height - label.implicitHeight - Style.space(20)
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
                      spacing: Style.space(8)

                      Repeater {
                        model: [tile.meta.fg || "#ffffff", tile.meta.accent || "#52e5d5", tile.meta.bg || "#000000"]

                        delegate: Rectangle {
                          required property var modelData
                          width: Style.space(96)
                          height: Style.space(16)
                          radius: Style.space(3)
                          color: String(modelData)
                          border.width: 1
                          border.color: Qt.rgba(1, 1, 1, 0.16)
                        }
                      }
                    }
                  }
                }

                Text {
                  id: label
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.bottom: parent.bottom
                  anchors.margins: Style.space(10)
                  text: root.itemTitle(tile.modelData)
                  color: Commons.Color.menu.text
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  font.bold: tile.current
                  elide: Text.ElideMiddle
                  horizontalAlignment: Text.AlignHCenter
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
