import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "ClipboardHistory.js" as ClipboardHistory

// Clipboard history overlay. Compact card, three permanent tabs (All/Text/
// Images) plus a Pinned tab that only exists while something is pinned.
// Images keep the panel small: the right column shows a modest preview and a
// floating 480x320 preview follows the hovered row.
Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property bool opened: false
  property string filterText: ""
  property string tab: "all"
  property int selectedIndex: 0
  property bool cursorActive: false
  property bool clearConfirmOpen: false
  property var history: []
  property int hoveredIndex: -1
  property int hoverPendingIndex: -1
  property int pinHoverId: -1
  property real hoverRowY: 0

  property string historyPath: Quickshell.env("HOME") + "/.local/state/quickshell/clipboard/history.json"
  property int historyLimit: 500

  // Surface colors come from the [menu] theme tokens, so the clipboard matches
  // the other Omarchy panels.
  property color background: Commons.Color.menu.background
  property color foreground: Commons.Color.menu.text
  property color border: Commons.Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Commons.Color.menu.scrim
  property color selectedBackground: Commons.Color.menu.selectedBackground
  property color selectedText: Commons.Color.menu.selectedText
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily

  // Panel geometry is intentionally in raw logical pixels: the chosen 640px
  // compact card should stay compact even when the user sets a larger shell
  // font. Text still follows Style.font.
  readonly property int contentMargin: 14
  readonly property int rowHeight: 38
  readonly property int listSpacing: 2
  readonly property int headerHeight: 56
  readonly property int footerHeight: 16
  readonly property int contentGap: 8
  readonly property int emptyHeight: 120
  readonly property int minCardHeight: 340
  readonly property int maxCardHeight: 470
  readonly property int cardWidth: Math.min(640, Math.max(520, panel.width - 48))

  // Eight rows fit the compact card; the ListView scrolls the rest. Shorter
  // histories shrink the card instead of leaving empty space.
  readonly property int cardHeight: {
    var rows = Math.min(displayModel.count, 8)
    var listHeight = rows > 0 ? rows * rowHeight + (rows - 1) * listSpacing : emptyHeight
    return Math.min(maxCardHeight, Math.max(minCardHeight,
      contentMargin * 2 + headerHeight + footerHeight + contentGap * 2 + listHeight))
  }

  readonly property int hoverPreviewWidth: Math.min(
    480, Math.max(240, (panel.width - cardWidth) / 2 - 24))
  readonly property int hoverPreviewHeight: Math.round(hoverPreviewWidth * 2 / 3)

  readonly property bool hasPinned: {
    for (var i = 0; i < root.history.length; i++) {
      if (root.history[i] && root.history[i].pinned === true) return true
    }
    return false
  }
  readonly property var tabs: root.hasPinned
    ? ["all", "text", "images", "pinned"]
    : ["all", "text", "images"]

  readonly property var activeRow: (root.selectedIndex >= 0 && root.selectedIndex < displayModel.count)
    ? displayModel.get(root.selectedIndex) : null
  readonly property var hoveredRow: (root.hoveredIndex >= 0 && root.hoveredIndex < displayModel.count)
    ? displayModel.get(root.hoveredIndex) : null
  readonly property string hoveredImage: {
    var row = root.hoveredRow
    if (!row || row.entryType !== "image") return ""
    if (row.historyIndex === root.pinHoverId) return ""
    return row.previewImage
  }

  function tabLabel(id) {
    if (id === "text") return "Text"
    if (id === "images") return "Images"
    if (id === "pinned") return "Pinned"
    return "All"
  }

  function normalizeEntry(value) { return ClipboardHistory.normalizeEntry(value) }
  function entryKey(entry) { return ClipboardHistory.entryKey(entry) }

  function open(payloadJson) {
    root.opened = true
    root.filterText = ""
    root.tab = "all"
    root.selectedIndex = 0
    root.cursorActive = true
    root.clearConfirmOpen = false
    root.hoveredIndex = -1
    root.hoverPendingIndex = -1
    root.pinHoverId = -1
    hoverTimer.stop()
    root.rebuildDisplay()
    historyFile.reload()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.cancelClearHistory()
    root.opened = false
    root.hoveredIndex = -1
    root.hoverPendingIndex = -1
    root.pinHoverId = -1
    hoverTimer.stop()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open("{}")
  }

  function loadHistory(raw) {
    root.history = ClipboardHistory.parseHistory(raw)
    if (root.opened) root.rebuildDisplay()
  }

  function saveHistory() {
    historyFile.setText(JSON.stringify(root.history.slice(0, root.historyLimit), null, 2) + "\n")
  }

  function entryTextStats(index) {
    var entry = root.history[index]
    if (!entry || entry.type !== "text") return ""
    var text = String(entry.text || "")
    var lines = text.split("\n").length
    return text.length + " chars · " + lines + (lines === 1 ? " line" : " lines")
  }

  function setFilter(next) {
    root.filterText = next
    root.selectedIndex = 0
    root.cursorActive = true
    root.hoveredIndex = -1
    root.hoverPendingIndex = -1
    hoverTimer.stop()
    root.rebuildDisplay()
  }

  function setTab(next) {
    if (root.tab === next) return
    root.tab = next
    root.selectedIndex = 0
    root.cursorActive = true
    root.hoveredIndex = -1
    root.hoverPendingIndex = -1
    hoverTimer.stop()
    root.rebuildDisplay()
  }

  function cycleTab(delta) {
    var list = root.tabs
    var index = list.indexOf(root.tab)
    if (index < 0) index = 0
    root.setTab(list[(index + delta + list.length) % list.length])
  }

  function rebuildDisplay() {
    if (root.tab === "pinned" && !root.hasPinned) root.tab = "all"
    root.hoveredIndex = -1
    root.hoverPendingIndex = -1
    root.pinHoverId = -1
    hoverTimer.stop()

    var rows = ClipboardHistory.displayRows(
      root.history, root.filterText, 50,
      Commons.I18n.t, Commons.I18n.tn, Commons.I18n.formatNumber, root.tab)

    displayModel.clear()
    for (var i = 0; i < rows.length; i++) {
      var row = rows[i]
      displayModel.append({
        entryType: row.entryType,
        fullText: row.fullText,
        previewText: row.previewText,
        previewImage: row.previewImage ? Util.fileUrl(row.previewImage) : "",
        path: row.path,
        mime: row.mime,
        pinned: row.pinned,
        entryKey: row.entryKey,
        capturedAt: row.capturedAt,
        historyIndex: row.index
      })
    }

    if (displayModel.count === 0) {
      root.selectedIndex = 0
      root.cursorActive = false
    } else {
      root.selectedIndex = Math.max(0, Math.min(root.selectedIndex, displayModel.count - 1))
      root.cursorActive = true
    }

    Qt.callLater(function() {
      if (displayModel.count > 0) resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
    })
  }

  function select(delta) {
    if (displayModel.count === 0) return
    if (!root.cursorActive) {
      root.cursorActive = true
      root.selectedIndex = delta < 0 ? displayModel.count - 1 : 0
    } else {
      root.selectedIndex = (root.selectedIndex + delta + displayModel.count) % displayModel.count
    }
    root.hoveredIndex = -1
    resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
  }

  function selectAbsolute(index) {
    if (displayModel.count === 0) return
    root.cursorActive = true
    root.selectedIndex = Math.max(0, Math.min(index, displayModel.count - 1))
    root.hoveredIndex = -1
    resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
  }

  function selectByKey(key) {
    for (var i = 0; i < displayModel.count; i++) {
      var row = displayModel.get(i)
      if (row && row.entryKey === key) {
        root.selectedIndex = i
        resultList.positionViewAtIndex(i, ListView.Contain)
        return
      }
    }
  }

  function removeDisplayIndex(index) {
    if (index < 0 || index >= displayModel.count) return
    var row = displayModel.get(index)
    root.history = ClipboardHistory.removeEntryAt(root.history, row.historyIndex)
    root.saveHistory()
    root.hoveredIndex = -1
    root.rebuildDisplay()
    if (displayModel.count === 0) root.cursorActive = false
    root.selectedIndex = Math.min(index, Math.max(0, displayModel.count - 1))
    if (displayModel.count > 0) resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
  }

  function requestClearHistory() {
    if (root.history.length === 0) return
    clearConfirm.selectedIndex = 1
    root.clearConfirmOpen = true
  }

  function cancelClearHistory() {
    root.clearConfirmOpen = false
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function confirmClearHistory() {
    root.history = ClipboardHistory.clearHistory()
    root.saveHistory()
    root.selectedIndex = 0
    root.cursorActive = false
    root.clearConfirmOpen = false
    root.rebuildDisplay()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function togglePin(index) {
    if (index < 0 || index >= displayModel.count) return
    var row = displayModel.get(index)
    var entry = root.history[row.historyIndex]
    if (!entry) return

    var key = root.entryKey(root.normalizeEntry(entry))
    entry.pinned = entry.pinned !== true

    var pinned = []
    var rest = []
    for (var i = 0; i < root.history.length; i++) {
      var value = root.history[i]
      if (value && value.pinned === true) pinned.push(value)
      else rest.push(value)
    }
    root.history = pinned.concat(rest)
    root.saveHistory()
    root.pinHoverId = -1
    root.rebuildDisplay()

    if (root.tab === "pinned" && !root.hasPinned) return
    root.selectByKey(key)
    root.cursorActive = true
  }

  function copyRow(row) {
    if (!row) return
    root.opened = false
    Quickshell.execDetached(["clipboard-copy", String(row.historyIndex)])
  }

  function copyIndex(index) {
    if (index < 0 || index >= displayModel.count) return
    root.copyRow(displayModel.get(index))
  }

  // Preview text is composed imperatively, so rebuild it when the language
  // changes under an open panel.
  Connections {
    target: Commons.I18n
    function onStringsChanged() { if (root.opened) root.rebuildDisplay() }
  }

  ListModel { id: displayModel }

  Timer {
    id: hoverTimer
    interval: 140
    repeat: false
    onTriggered: {
      if (root.hoverPendingIndex >= 0) {
        root.hoveredIndex = root.hoverPendingIndex
        root.hoverPendingIndex = -1
      }
    }
  }

  FileView {
    id: historyFile
    path: root.historyPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadHistory(text())
    onLoadFailed: root.loadHistory("[]")
    onFileChanged: reload()
  }

  OverlayWindow {
    id: panel
    shown: root.opened
    shownKeyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "omarchy-clipboard"

    Rectangle {
      id: surface
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.close()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      anchors.centerIn: parent
      radius: root.cornerRadius
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (root.clearConfirmOpen) {
            if (clearConfirm.handleKey(event)) event.accepted = true
            return
          }

          if (event.key === Qt.Key_Escape) {
            if (root.filterText) root.setFilter("")
            else root.close()
            event.accepted = true
          } else if (Util.editsFilter(event, root.filterText)) {
            root.setFilter(Util.editedFilter(event, root.filterText))
            event.accepted = true
          } else if (event.key === Qt.Key_Delete) {
            if (event.modifiers & Qt.ShiftModifier) root.requestClearHistory()
            else root.removeDisplayIndex(root.selectedIndex)
            event.accepted = true
          } else if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
            root.togglePin(root.selectedIndex)
            event.accepted = true
          } else if (event.key === Qt.Key_Left) {
            root.cycleTab(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_Right) {
            root.cycleTab(1)
            event.accepted = true
          } else if (event.key === Qt.Key_Up) {
            root.select(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_Down) {
            root.select(1)
            event.accepted = true
          } else if (event.key === Qt.Key_PageUp) {
            root.select(-6)
            event.accepted = true
          } else if (event.key === Qt.Key_PageDown) {
            root.select(6)
            event.accepted = true
          } else if (event.key === Qt.Key_Home) {
            root.selectAbsolute(0)
            event.accepted = true
          } else if (event.key === Qt.Key_End) {
            root.selectAbsolute(displayModel.count - 1)
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.cursorActive) root.copyIndex(root.selectedIndex)
            event.accepted = true
          } else if (event.text && event.text.length === 1
                     && event.text.charCodeAt(0) >= 32
                     && event.text.charCodeAt(0) !== 127) {
            root.setFilter(root.filterText + event.text)
            event.accepted = true
          }
        }

        ConfirmDialog {
          id: clearConfirm

          anchors.fill: parent
          opened: root.clearConfirmOpen
          z: 10
          message: Commons.I18n.t("clipboard.deleteHistory")
          confirmText: Commons.I18n.t("common.delete")
          background: root.background
          foreground: root.foreground
          scrim: root.scrim
          selectedBackground: root.selectedBackground
          selectedText: root.selectedText
          fontFamily: root.fontFamily
          cornerRadius: root.cornerRadius
          onCanceled: root.cancelClearHistory()
          onConfirmed: root.confirmClearHistory()
        }
      }

      Item {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: card.contentLeftInset
        anchors.rightMargin: card.contentRightInset
        anchors.topMargin: card.contentTopInset
        height: root.headerHeight

        Text {
          id: search
          textFormat: Text.PlainText
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          height: 30
          text: root.filterText || Commons.I18n.t("clipboard.search")
          color: root.foreground
          opacity: root.filterText ? 1 : 0.55
          font.family: root.fontFamily
          font.pixelSize: Style.font.title
          elide: Text.ElideRight
          verticalAlignment: Text.AlignVCenter
        }

        Row {
          id: tabRow
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: search.bottom
          anchors.topMargin: 4
          height: 22
          spacing: 14

          Repeater {
            model: root.tabs

            delegate: Item {
              required property var modelData
              width: tabText.implicitWidth
              height: tabRow.height

              Text {
                id: tabText
                anchors.verticalCenter: parent.verticalCenter
                text: root.tabLabel(modelData)
                color: root.tab === modelData ? root.selectedText : root.foreground
                opacity: root.tab === modelData ? 1 : 0.55
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }

              Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 2
                radius: height / 2
                color: root.tab === modelData ? root.selectedText : "transparent"
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.setTab(modelData)
              }
            }
          }
        }
      }

      Item {
        id: contentArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: footer.top
        anchors.leftMargin: card.contentLeftInset
        anchors.rightMargin: card.contentRightInset
        anchors.topMargin: root.contentGap
        anchors.bottomMargin: root.contentGap

        Row {
          anchors.fill: parent
          spacing: 0

          Item {
            id: listPane
            width: root.tab === "images" ? parent.width : Math.round(parent.width / 2)
            height: parent.height
            clip: true

            ListView {
              id: resultList
              anchors.fill: parent
              anchors.rightMargin: root.tab === "images" ? 0 : root.contentGap
              model: displayModel
              clip: true
              spacing: root.listSpacing
              boundsBehavior: Flickable.StopAtBounds

              delegate: Rectangle {
                id: row
                required property int index
                required property string entryType
                required property string previewText
                required property string fullText
                required property string previewImage
                required property bool pinned
                required property string capturedAt
                required property int historyIndex

                readonly property bool selected: root.cursorActive && index === root.selectedIndex
                readonly property bool hovered: rowHover.hovered

                width: ListView.view.width
                height: root.rowHeight
                radius: 8
                color: selected ? root.selectedBackground
                  : (hovered ? Util.alpha(root.foreground, 0.05) : "transparent")

                HoverHandler {
                  id: rowHover
                  onHoveredChanged: {
                    if (rowHover.hovered) {
                      root.hoverPendingIndex = row.index
                      root.hoverRowY = row.mapToItem(surface, 0, 0).y
                      hoverTimer.restart()
                    } else {
                      hoverTimer.stop()
                      if (root.hoverPendingIndex === row.index) root.hoverPendingIndex = -1
                      if (root.hoveredIndex === row.index) root.hoveredIndex = -1
                    }
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.selectAbsolute(row.index)
                    root.copyIndex(row.index)
                  }
                }

                Item {
                  anchors.left: parent.left
                  anchors.leftMargin: 10
                  anchors.right: pinButton.left
                  anchors.rightMargin: 4
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom

                  SizedImage {
                    id: thumb
                    visible: row.entryType === "image"
                    width: 28
                    height: 28
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    url: row.previewImage
                    asynchronous: true
                    smooth: true
                  }

                  Text {
                    textFormat: Text.PlainText
                    anchors.left: thumb.visible ? thumb.right : parent.left
                    anchors.leftMargin: thumb.visible ? 8 : 0
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.previewText
                    color: row.selected ? root.selectedText : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                  }
                }

                Item {
                  id: pinButton
                  width: 24
                  height: 24
                  anchors.right: parent.right
                  anchors.rightMargin: 4
                  anchors.verticalCenter: parent.verticalCenter

                  Text {
                    anchors.centerIn: parent
                    text: "\uf08d"
                    color: row.pinned ? root.selectedText : root.foreground
                    opacity: row.pinned ? 0.95 : (row.hovered && root.pinHoverId !== row.historyIndex ? 0.55 : 0)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                  }

                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: function(mouse) { mouse.accepted = true }
                    onClicked: root.togglePin(row.index)
                    onEntered: root.pinHoverId = row.historyIndex
                    onExited: {
                      if (root.pinHoverId === row.historyIndex) root.pinHoverId = -1
                    }
                  }
                }
              }
            }

            Text {
              visible: displayModel.count === 0
              anchors.centerIn: parent
              width: parent.width - Style.space(24)
              horizontalAlignment: Text.AlignHCenter
              textFormat: Text.PlainText
              text: root.history.length === 0
                ? Commons.I18n.t("clipboard.empty")
                : root.filterText
                  ? Commons.I18n.t("common.noMatchesFor").arg(root.filterText)
                  : root.tab === "images" ? "No images"
                  : root.tab === "text" ? "No text clips"
                  : root.tab === "pinned" ? "No pinned clips"
                  : "No clips"
              color: root.foreground
              opacity: 0.7
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
            }
          }

          Item {
            id: previewPane
            visible: root.tab !== "images"
            width: visible ? parent.width - listPane.width : 0
            height: parent.height
            clip: true

            readonly property var row: root.activeRow
            readonly property bool isImage: !!row && row.entryType === "image"

            Rectangle {
              anchors.left: parent.left
              anchors.top: parent.top
              anchors.bottom: parent.bottom
              width: 1
              color: Util.alpha(root.border, 0.28)
            }

            Text {
              visible: !previewPane.row
              anchors.centerIn: parent
              width: parent.width - Style.space(24)
              horizontalAlignment: Text.AlignHCenter
              textFormat: Text.PlainText
              text: "Select an entry"
              color: root.foreground
              opacity: 0.5
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }

            Flickable {
              id: textFlick
              visible: !!previewPane.row && !previewPane.isImage
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.bottom: meta.top
              anchors.leftMargin: root.contentGap
              anchors.bottomMargin: root.contentGap
              clip: true
              contentWidth: width
              contentHeight: textPreview.implicitHeight

              Text {
                id: textPreview
                width: textFlick.width
                textFormat: Text.PlainText
                text: previewPane.row ? previewPane.row.fullText : ""
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                wrapMode: Text.WrapAnywhere
              }
            }

            Item {
              id: imagePane
              visible: !!previewPane.row && previewPane.isImage
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.leftMargin: root.contentGap
              height: Math.round(width * 9 / 16)

              Image {
                anchors.fill: parent
                source: previewPane.isImage ? previewPane.row.previewImage : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
                sourceSize.width: 700
                sourceSize.height: 500
              }
            }

            Text {
              id: meta
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              anchors.leftMargin: root.contentGap
              height: root.footerHeight
              textFormat: Text.PlainText
              text: {
                var row = root.activeRow
                if (!row) return ""
                var parts = []
                if (row.capturedAt) parts.push(row.capturedAt)
                if (row.entryType === "image") parts.push(row.mime || "image")
                else {
                  var stats = root.entryTextStats(row.historyIndex)
                  if (stats) parts.push(stats)
                }
                return parts.join(" · ")
              }
              color: root.foreground
              opacity: 0.55
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              verticalAlignment: Text.AlignVCenter
            }
          }
        }
      }

      Text {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: card.contentLeftInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        height: root.footerHeight
        textFormat: Text.PlainText
        text: "←→ tabs · ↑↓ move · Enter copy · Ctrl+P pin · Del delete · Esc close"
        color: root.foreground
        opacity: 0.45
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
      }
    }

    // Floating image preview: outside the card, so it can be large without
    // making the panel grow. The full image is only decoded while hovered.
    Rectangle {
      id: hoverPreview
      visible: root.opened && root.hoveredImage !== ""
      width: root.hoverPreviewWidth
      height: root.hoverPreviewHeight
      z: 50
      radius: root.cornerRadius
      color: root.background
      border.width: 1
      border.color: Util.alpha(root.border, 0.6)

      readonly property bool fitsRight:
        card.x + card.width + 16 + width <= surface.width - 12
      readonly property bool fitsLeft:
        card.x - 16 - width >= 12

      x: fitsRight
        ? card.x + card.width + 16
        : fitsLeft
          ? card.x - 16 - width
          : Math.max(12, (surface.width - width) / 2)
      y: Math.max(12,
        Math.min(surface.height - height - 12,
          root.hoverRowY + root.rowHeight / 2 - height / 2))

      Image {
        anchors.fill: parent
        anchors.margins: 8
        source: root.hoveredImage
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        sourceSize.width: 960
        sourceSize.height: 640
      }
    }
  }
}
