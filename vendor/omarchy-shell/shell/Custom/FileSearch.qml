import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// dsearch-backed file finder. It is one full-screen surface (scrim, card,
// keyboard) so Escape and outside-click behave like the clipboard.
Item {
  id: root

  property bool opened: false
  property string query: ""
  property var results: []
  property int selectedIndex: 0
  property string message: ""
  property bool searching: false
  property int searchSerial: 0
  property string pendingOutput: ""

  readonly property int cardWidth: Math.min(Style.space(580), Math.max(Style.space(320), panel.width - Style.gapsOut * 4))
  readonly property int rowHeight: Style.space(46)
  readonly property string dsearchPath: "/etc/profiles/per-user/" + Quickshell.env("USER") + "/bin/dsearch"

  function open(payload) {
    if (root.opened) return
    root.opened = true
    root.query = ""
    root.results = []
    root.selectedIndex = 0
    root.message = ""
    root.searching = false
    Qt.callLater(function() {
      searchInput.text = ""
      searchInput.forceActiveFocus()
    })
  }

  function close() {
    root.opened = false
    root.searching = false
    root.results = []
    root.message = ""
    root.query = ""
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open("{}")
  }

  function runSearch() {
    var text = String(root.query || "").trim()
    root.message = ""
    if (text.length === 0) {
      root.results = []
      root.selectedIndex = 0
      return
    }

    root.searchSerial++
    root.searching = true
    root.pendingOutput = ""
    searchProc.command = [root.dsearchPath, "search", "--json", "--limit", "50", "--type", "file", "--fuzzy", text]
    searchProc.running = true
  }

  function parseResults(raw) {
    var parsed
    try {
      parsed = JSON.parse(String(raw || "{}"))
    } catch (e) {
      root.results = []
      root.message = "Search failed"
      return
    }
    var hits = parsed && Array.isArray(parsed.hits) ? parsed.hits : []
    var next = []
    for (var i = 0; i < hits.length; i++) {
      var path = String(hits[i] && hits[i].id || "")
      if (!path) continue
      var slash = path.lastIndexOf("/")
      var name = slash >= 0 ? path.substring(slash + 1) : path
      var dir = slash >= 0 ? path.substring(0, slash) : ""
      next.push({ path: path, name: name, dir: dir })
    }
    root.results = next
    root.selectedIndex = next.length > 0 ? 0 : -1
    root.message = next.length === 0 ? "No files found" : ""
  }

  function activate() {
    var row = root.results[root.selectedIndex]
    if (!row) return
    Quickshell.execDetached(["xdg-open", row.path])
    root.close()
  }

  function reveal() {
    var row = root.results[root.selectedIndex]
    if (!row || !row.dir) return
    Quickshell.execDetached(["xdg-open", row.dir])
    root.close()
  }

  function copyPath() {
    var row = root.results[root.selectedIndex]
    if (!row) return
    Quickshell.execDetached(["wl-copy", row.path])
    root.message = "Path copied"
  }

  function moveSelection(delta) {
    if (root.results.length === 0) return
    root.selectedIndex = Math.max(0, Math.min(root.results.length - 1, root.selectedIndex + delta))
    resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
  }

  ShellIpc {
    target: "local.file-search"

    function open(payloadJson): void { root.open(payloadJson) }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  Timer {
    id: debounce
    interval: 120
    onTriggered: root.runSearch()
  }

  Process {
    id: searchProc
    stdout: SplitParser {
      onRead: function(line) { root.pendingOutput += line + "\n" }
    }
    onExited: {
      root.searching = false
      root.parseResults(root.pendingOutput)
      root.pendingOutput = ""
    }
  }

  OverlayWindow {
    id: panel
    shown: root.opened
    shownKeyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "omarchy-file-search"

    onShownChanged: {
      if (shown) {
        Qt.callLater(function() {
          searchInput.forceActiveFocus()
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
      onClicked: root.close()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: content.implicitHeight + card.padding * 2
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: Style.bar.sizeHorizontal + Style.gapsOut
      color: Commons.Color.menu.background
      borderSpec: Border.surfaceSpec("menu", "border", Commons.Color.menu.border, Math.max(1, Style.space(2)))
      radius: Style.cornerRadius
      padding: Style.space(14)

      MouseArea {
        anchors.fill: parent
        onClicked: {}
      }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(8)

        TextField {
          id: searchInput
          width: parent.width
          placeholderText: "Search files…"
          foreground: Commons.Color.menu.text
          accent: Commons.Color.accent
          Keys.onEscapePressed: root.close()
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Down) {
              root.moveSelection(1)
              event.accepted = true
            } else if (event.key === Qt.Key_Up) {
              root.moveSelection(-1)
              event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              if (event.modifiers & Qt.ControlModifier) root.reveal()
              else root.activate()
              event.accepted = true
            } else if (event.key === Qt.Key_C && (event.modifiers & Qt.ControlModifier)) {
              root.copyPath()
              event.accepted = true
            }
          }
          onTextChanged: {
            root.query = text
            debounce.restart()
          }
        }

        ListView {
          id: resultList
          width: parent.width
          height: Math.min(Style.space(360), Math.max(root.rowHeight, root.results.length * root.rowHeight))
          clip: true
          model: root.results
          currentIndex: root.selectedIndex
          boundsBehavior: Flickable.StopAtBounds

          delegate: Rectangle {
            required property var modelData
            required property int index

            width: resultList.width
            height: root.rowHeight
            radius: Style.space(8)
            color: index === root.selectedIndex ? Commons.Color.menu.selectedBackground : "transparent"

            Text {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              text: "󰈔"
              color: Commons.Color.menu.text
              opacity: 0.7
              font.family: Style.font.family
              font.pixelSize: Style.font.body
            }

            Column {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(32)
              anchors.right: parent.right
              anchors.rightMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(1)

              Text {
                width: parent.width
                text: modelData.name
                color: Commons.Color.menu.text
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                text: modelData.dir
                color: Commons.Color.menu.text
                opacity: 0.5
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                elide: Text.ElideMiddle
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              onEntered: root.selectedIndex = index
              onClicked: {
                root.selectedIndex = index
                root.activate()
              }
            }
          }
        }

        Text {
          width: parent.width
          visible: root.message.length > 0
          text: root.message
          color: Commons.Color.menu.text
          opacity: 0.6
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        Text {
          width: parent.width
          text: "Enter open · Ctrl+Enter reveal · Ctrl+C copy path · Esc close"
          color: Commons.Color.menu.text
          opacity: 0.4
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }
  }
}
