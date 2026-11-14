import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "ClipboardHistory.js" as ClipboardHistory

// Clipboard history overlay. One compact column: text rows are a single line,
// image rows carry a 24px thumbnail. No permanent preview column; hovering an
// image opens a floating preview sized from the image resolution relative to
// the current monitor.
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
  property int hoverImageW: 0
  property int hoverImageH: 0
  property string pendingSizePath: ""

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

  // Panel geometry stays in raw logical pixels so a larger shell font does not
  // silently turn the 380px card back into a wide panel.
  readonly property int contentMargin: 14
  readonly property int rowHeight: 40
  readonly property int listSpacing: 2
  readonly property int headerHeight: 56
  readonly property int footerHeight: 16
  readonly property int contentGap: 8
  readonly property int emptyHeight: 120
  readonly property int minCardHeight: 330
  readonly property int maxCardHeight: 380
  readonly property int cardWidth: Math.min(380, Math.max(320, panel.width - 48))

  // Six rows fit the height range; the ListView scrolls the rest.
  readonly property int cardHeight: {
    var rows = Math.min(displayModel.count, 6)
    var listHeight = rows > 0 ? rows * rowHeight + (rows - 1) * listSpacing : emptyHeight
    return Math.min(maxCardHeight, Math.max(minCardHeight,
      contentMargin * 2 + headerHeight + footerHeight + contentGap * 2 + listHeight))
  }

  readonly property real dpr: Math.max(1, panel.devicePixelRatio || 1)
  readonly property real monitorW: Math.max(1, panel.width * dpr)
  readonly property real monitorH: Math.max(1, panel.height * dpr)

  // Hover preview: compare the image's pixel size with the current monitor and
  // pick a 2x / 1x / 0.5x coefficient. Then cap it so a full-screen screenshot
  // still leaves some context visible behind it.
  readonly property var hoverPreviewSize: {
    var monitorW = root.monitorW
    var monitorH = root.monitorH
    if (root.hoverImageW <= 0 || root.hoverImageH <= 0) {
      var fallbackW = Math.min(480, Math.max(240, panel.width - 48))
      return { w: fallbackW, h: Math.round(fallbackW * 9 / 16) }
    }

    var cover = Math.max(root.hoverImageW / monitorW, root.hoverImageH / monitorH)
    var coef = cover <= 0.5 ? 2 : (cover <= 1 ? 1 : 0.5)
    var w = root.hoverImageW * coef
    var h = root.hoverImageH * coef
    var scale = Math.min(1, (monitorW * 0.45) / w, (monitorH * 0.55) / h)
    return {
      w: Math.max(1, (w * scale) / root.dpr),
      h: Math.max(1, (h * scale) / root.dpr)
    }
  }

  readonly property bool hasPinned: {
    for (var i = 0; i < root.history.length; i++) {
      if (root.history[i] && root.history[i].pinned === true) return true
    }
    return false
  }
  readonly property var tabs: root.hasPinned
    ? ["all", "text", "images", "pinned"]
    : ["all", "text", "images"]

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
    root.hoverImageW = 0
    root.hoverImageH = 0
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
    root.hoverImageW = 0
    root.hoverImageH = 0
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

  function setFilter(next) {
    root.filterText = next
    root.selectedIndex = 0
    root.cursorActive = true
    root.hoveredIndex = -1
    root.hoverPendingIndex = -1
    root.hoverImageW = 0
    root.hoverImageH = 0
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
    root.hoverImageW = 0
    root.hoverImageH = 0
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
    root.hoverImageW = 0
    root.hoverImageH = 0
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
      if (root.hoverPendingIndex < 0) return
      root.hoveredIndex = root.hoverPendingIndex
      root.hoverPendingIndex = -1

      var row = root.hoveredRow
      if (!row || row.entryType !== "image" || !row.path) return
      if (row.historyIndex === root.pinHoverId) return

      root.hoverImageW = 0
      root.hoverImageH = 0
      root.pendingSizePath = row.path
      sizeProc.command = ["image-size", row.path]
      sizeProc.running = true
    }
  }

  Process {
    id: sizeProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var row = root.hoveredRow
        if (!row || row.path !== root.pendingSizePath) return
        var parts = String(text).trim().split(/\s+/)
        if (parts.length < 2) return
        var w = Number(parts[0])
        var h = Number(parts[1])
        if (isFinite(w) && isFinite(h) && w > 0 && h > 0) {
          root.hoverImageW = w
          root.hoverImageH = h
        }
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
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: Style.bar.sizeHorizontal + 6
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
                radius: 1
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

        ListView {
          id: resultList
          anchors.fill: parent
          model: displayModel
          clip: true
          spacing: root.listSpacing
          boundsBehavior: Flickable.StopAtBounds

          delegate: Rectangle {
            id: row
            required property int index
            required property string entryType
            required property string previewText
            required property string previewImage
            required property string path
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

              Item {
                id: thumbArea
                visible: row.entryType === "image"
                width: 44
                height: 32
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                SizedImage {
                  anchors.centerIn: parent
                  width: 40
                  height: 24
                  crop: true
                  url: row.previewImage
                  asynchronous: true
                  smooth: true
                }

                HoverHandler {
                  id: thumbHover
                  onHoveredChanged: {
                    if (thumbHover.hovered) {
                      root.hoverPendingIndex = row.index
                      hoverTimer.restart()
                    } else {
                      hoverTimer.stop()
                      if (root.hoverPendingIndex === row.index) root.hoverPendingIndex = -1
                      if (root.hoveredIndex === row.index) {
                        root.hoveredIndex = -1
                        root.hoverImageW = 0
                        root.hoverImageH = 0
                      }
                    }
                  }
                }
              }

              Text {
                textFormat: Text.PlainText
                anchors.left: thumbArea.visible ? thumbArea.right : parent.left
                anchors.leftMargin: thumbArea.visible ? 8 : 0
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
                opacity: row.pinned ? 0.95 : (row.hovered ? 0.8 : 0)
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
          width: parent.width - 24
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
        text: "←→ tabs · ↑↓ · Enter copy · ^P pin · Del · Esc"
        color: root.foreground
        opacity: 0.45
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
      }
    }

    Rectangle {
      id: hoverPreview
      visible: root.opened && root.hoveredImage !== ""
      width: root.hoverPreviewSize.w
      height: root.hoverPreviewSize.h
      z: 50
      radius: root.cornerRadius
      color: root.background
      border.width: 1
      border.color: Util.alpha(root.border, 0.6)

      x: Math.max(12, (surface.width - width) / 2)
      y: Math.max(12, Math.min(surface.height - height - 12,
        card.y + card.height + 12))

      Image {
        anchors.fill: parent
        anchors.margins: 8
        source: root.hoveredImage
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        sourceSize.width: Math.max(1, Math.ceil(root.hoverPreviewSize.w * root.dpr))
        sourceSize.height: Math.max(1, Math.ceil(root.hoverPreviewSize.h * root.dpr))
      }
    }
  }
}
