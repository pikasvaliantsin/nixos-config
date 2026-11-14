import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Keybinding sheet: every bind from the live niri config, grouped by the
// section comments in binds.kdl, with a filter field. `omarchy-keybinds`
// turns the file into JSON so the sheet never drifts from the compositor.
Item {
  id: root

  property bool opened: false
  property string query: ""
  property var sections: []
  property bool loading: false
  property string errorText: ""

  readonly property int total: {
    var count = 0
    for (var s = 0; s < sections.length; s++) count += sections[s].items.length
    return count
  }

  readonly property var filteredSections: {
    var needle = query.trim().toLowerCase()
    var out = []
    for (var s = 0; s < root.sections.length; s++) {
      var section = root.sections[s]
      var items = []
      for (var i = 0; i < section.items.length; i++) {
        var item = section.items[i]
        var haystack = (item.keys + " " + item.title + " " + item.action).toLowerCase()
        if (needle === "" || haystack.indexOf(needle) >= 0) items.push(item)
      }
      if (items.length > 0) out.push({ title: section.title, items: items })
    }
    return out
  }

  readonly property var rows: {
    var out = []
    for (var s = 0; s < filteredSections.length; s++) {
      var section = filteredSections[s]
      out.push({ kind: "section", title: section.title })
      for (var i = 0; i < section.items.length; i++) {
        var item = section.items[i]
        out.push({ kind: "item", keys: item.keys, title: item.title, action: item.action })
      }
    }
    return out
  }

  readonly property int filteredCount: {
    var count = 0
    for (var s = 0; s < filteredSections.length; s++) count += filteredSections[s].items.length
    return count
  }

  readonly property int cardWidth: Math.min(Style.space(980), Math.max(Style.space(620), panel.width - Style.gapsOut * 4))
  readonly property int cardHeight: Math.min(Style.space(660), Math.max(Style.space(420), panel.height - Style.gapsOut * 6))

  function open() {
    root.opened = true
    root.query = ""
    if (search) search.text = ""
    root.load()
    focusTimer.restart()
  }

  function close() {
    root.opened = false
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function load() {
    if (proc.running) return
    root.errorText = ""
    root.loading = true
    proc.running = true
  }

  // A missing helper never exits, so a stalled load has to fail visibly.
  Timer {
    interval: 2500
    running: root.loading
    onTriggered: {
      if (!root.loading) return
      root.loading = false
      if (root.sections.length === 0) root.errorText = "Cannot read the keybindings"
    }
  }

  Process {
    id: proc
    command: ["omarchy-keybinds"]
    onExited: function(code, status) {
      if (!root.loading) return
      root.loading = false
      if (code !== 0 || root.sections.length === 0)
        root.errorText = "Cannot read the keybindings"
    }
    stdout: StdioCollector {
      onStreamFinished: {
        var parsed = null
        try { parsed = JSON.parse(text) } catch (error) { parsed = null }
        root.loading = false
        if (!parsed || !parsed.sections) {
          root.errorText = "Cannot read the keybindings"
          return
        }
        root.sections = parsed.sections
      }
    }
  }

  ShellIpc {
    target: "keybinds"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function reload(): void { root.load() }
    function status(): string {
      return JSON.stringify({ opened: root.opened, sections: root.sections.length, count: root.total,
                              filtered: root.filteredCount, query: root.query,
                              focus: search ? search.activeFocus : false })
    }
  }

  // One-shot focus retry after the surface maps; a single forceActiveFocus
  // before the window is active is dropped by Qt.
  Timer {
    id: focusTimer
    interval: 140
    onTriggered: if (root.opened && search) search.forceActiveFocus()
  }

  OverlayWindow {
    id: panel
    shown: root.opened
    shownKeyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "omarchy-keybinds"

    // Focus after the surface maps; forceActiveFocus before that is dropped.
    onShownChanged: if (shown) focusTimer.restart()
    onBackingWindowVisibleChanged: if (shown && backingWindowVisible) focusTimer.restart()

    Shortcut { sequence: "Escape"; enabled: root.opened; onActivated: root.close() }

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
          spacing: Style.space(10)

          Text {
            text: "Keybindings"
            color: Commons.Color.menu.text
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
          }

          TextField {
            id: search
            Layout.fillWidth: true
            placeholderText: "Search keys, actions…"
            foreground: Commons.Color.menu.text
            accent: Commons.Color.accent
            Keys.onEscapePressed: root.close()
            onTextChanged: root.query = text
          }

          Text {
            text: root.loading ? "Loading…" : (root.query !== "" ? root.filteredCount + " / " + root.total : root.total + " keys")
            color: Commons.Color.menu.text
            opacity: 0.5
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }

          Text {
            text: "Esc"
            color: Commons.Color.menu.text
            opacity: 0.4
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

        ListView {
          id: list
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          model: root.rows
          spacing: Style.space(1)
          boundsBehavior: Flickable.StopAtBounds
          QQC.ScrollBar.vertical: QQC.ScrollBar { policy: QQC.ScrollBar.AsNeeded }

          delegate: Item {
            id: rowItem
            required property var modelData

            width: list.width
            height: modelData.kind === "section"
              ? sectionText.implicitHeight + Style.space(12)
              : Style.space(22)

            Text {
              id: sectionText
              visible: rowItem.modelData.kind === "section"
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              anchors.bottomMargin: Style.space(3)
              text: rowItem.modelData.kind === "section" ? rowItem.modelData.title : ""
              color: Commons.Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
              elide: Text.ElideRight
            }

            Row {
              visible: rowItem.modelData.kind === "item"
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(10)

              Text {
                width: Style.space(210)
                text: rowItem.modelData.kind === "item" ? rowItem.modelData.keys : ""
                color: Commons.Color.menu.text
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                width: Math.max(0, parent.width - Style.space(210) - Style.space(10))
                text: rowItem.modelData.kind === "item" ? rowItem.modelData.title : ""
                color: Commons.Color.menu.text
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }
        }

        Text {
          Layout.fillWidth: true
          visible: !root.loading && root.rows.length === 0
          text: root.errorText !== "" ? root.errorText : "Nothing matches"
          color: root.errorText !== "" ? Commons.Color.urgent : Commons.Color.menu.text
          opacity: root.errorText !== "" ? 1 : 0.5
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          horizontalAlignment: Text.AlignHCenter
        }
      }
    }
  }
}
