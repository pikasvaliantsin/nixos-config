import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Custom
import qs.Ui

// The print folder, its documents, and their printed state. A row check picks
// a document for the next batch; printed documents can be checked again to
// reprint them. "Print new" sends only documents the helper has not recorded
// yet.
KeyboardPanel {
  id: root

  contentWidth: root.fittedContentWidth(Style.space(470))
  contentHeight: root.fittedContentHeight(root.loadedContentHeight, Style.space(600))
  focusTarget: root.loadedContent

  // Keyboard cursor over the document rows: Up/Down move, Space/Enter pick the
  // row for the next batch. Mouse clicks stay independent of it.
  property int cursor: -1

  function moveCursor(dy) {
    if (PrintService.documents.length === 0) {
      cursor = -1
      return
    }
    var next = cursor < 0 ? 0 : cursor + dy
    cursor = Math.max(0, Math.min(PrintService.documents.length - 1, next))
    ensureCursorVisible()
  }

  function activateCursor() {
    if (cursor < 0 || cursor >= PrintService.documents.length) return
    PrintService.toggle(PrintService.documents[cursor].path)
  }

  function ensureCursorVisible() {
    if (!keyCatcher || !keyCatcher.listArea || !keyCatcher.flickArea) return
    var row = keyCatcher.listArea.children[cursor]
    if (!row) return
    if (row.y < keyCatcher.flickArea.contentY) keyCatcher.flickArea.contentY = row.y
    else if (row.y + row.height > keyCatcher.flickArea.contentY + keyCatcher.flickArea.height) {
      keyCatcher.flickArea.contentY = row.y + row.height - keyCatcher.flickArea.height
    }
  }

  onOpenChanged: {
    if (open) {
      PrintService.clearMessage()
      PrintService.refresh()
      root.cursor = PrintService.documents.length > 0 ? 0 : -1
    }
  }

  function formatPrintedAt(value) {
    if (!value) return ""
    var date = new Date(value)
    if (isNaN(date.getTime())) return ""
    return Qt.formatDateTime(date, "dd.MM.yyyy HH:mm")
  }

  function statusFor(doc) {
    if (!doc) return ""
    if (doc.printed) {
      var at = root.formatPrintedAt(doc.printedAt)
      return at !== "" ? "Printed " + at : "Printed"
    }
    if (doc.changed) return "Changed since last print"
    return "Not printed"
  }

  function shortFolder() {
    var home = Quickshell.env("HOME")
    var path = PrintService.folder
    if (home && path.indexOf(home) === 0) return "~" + path.slice(home.length)
    return path
  }

  function openFolder() {
    if (PrintService.folder !== "") {
      Util.launchScoped(["xdg-open", PrintService.folder])
    }
  }

  component DocumentRow: Rectangle {
    id: row

    property var doc: null
    property bool selected: false
    property bool hasCursor: false

    signal toggled()

    width: parent ? parent.width : 0
    height: Style.space(46)
    radius: Style.cornerRadius
    color: hover.containsMouse
      ? Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g,
                Commons.Color.foreground.b, 0.07)
      : (row.selected
        ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g,
                  Commons.Color.accent.b, 0.12)
        : (row.hasCursor
          ? Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g,
                    Commons.Color.foreground.b, 0.08)
          : "transparent"))

    MouseArea {
      id: hover
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: row.toggled()
    }

    // Drawn rather than a glyph: the checkbox must keep the same weight and
    // alignment in every Nerd Font build.
    Rectangle {
      id: box
      x: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(17)
      height: width
      radius: Style.space(3)
      color: row.selected ? Commons.Color.accent : "transparent"
      border.width: 1
      border.color: row.selected ? Commons.Color.accent : Commons.Color.muted

      Text {
        visible: row.selected
        anchors.centerIn: parent
        text: "\uf00c"
        color: Commons.Color.background
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }

    Column {
      anchors.left: box.right
      anchors.leftMargin: Style.space(10)
      anchors.right: parent.right
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(1)

      Text {
        width: parent.width
        text: row.doc ? String(row.doc.name || "") : ""
        textFormat: Text.PlainText
        elide: Text.ElideMiddle
        color: Commons.Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }

      Text {
        width: parent.width
        text: root.statusFor(row.doc)
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: row.doc && row.doc.changed
          ? Commons.Color.urgent
          : (row.doc && row.doc.printed ? Commons.Color.muted : Commons.Color.accent)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
  }

  content: PanelKeyCatcher {
    id: keyCatcher

    property alias flickArea: flick
    property alias listArea: listColumn

    anchors.fill: parent
    implicitHeight: column.implicitHeight
    onCloseRequested: root.close()
    onMoveRequested: function(dx, dy) {
      if (dy !== 0) root.moveCursor(dy)
    }
    onActivateRequested: root.activateCursor()
    onTextKey: function(text, modifiers) {
      if (modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return
      if (text === "r") {
        PrintService.clearMessage()
        PrintService.refresh()
      }
    }

    // Lives inside the loaded content: KeyboardPanel's default property is the
    // content list, so a non-Item Connections object at the root would be
    // assigned to it and fail to load the whole panel.
    Connections {
      target: PrintService
      function onDocumentsChanged() {
        if (PrintService.documents.length === 0) root.cursor = -1
        else root.cursor = Math.max(0, Math.min(root.cursor, PrintService.documents.length - 1))
      }
    }

    Column {
      id: column
      width: parent.width
      spacing: Style.space(8)

      RowLayout {
        width: parent.width
        spacing: Style.space(8)

        Text {
          text: "Print"
          color: Commons.Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.heading
          font.bold: true
        }
        Text {
          visible: PrintService.loading
          text: "reading…"
          color: Commons.Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
        Item { Layout.fillWidth: true }

        PanelActionButton {
          iconText: "\uf021"
          tooltipText: "Refresh"
          foreground: Commons.Color.foreground
          enabled: !PrintService.loading && !PrintService.printing
          onClicked: {
            PrintService.clearMessage()
            PrintService.refresh()
          }
        }
        PanelActionButton {
          iconText: "\uf07b"
          tooltipText: root.shortFolder()
          foreground: Commons.Color.foreground
          enabled: PrintService.folder !== ""
          onClicked: root.openFolder()
        }
      }

      RowLayout {
        width: parent.width
        spacing: Style.space(8)

        Text {
          Layout.fillWidth: true
          text: PrintService.printer !== ""
            ? PrintService.printer
            : "No CUPS printer found"
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: PrintService.printer !== ""
            ? Commons.Color.muted
            : Commons.Color.urgent
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }
        Text {
          text: PrintService.documents.length + " documents · "
            + PrintService.newCount + " new"
          color: Commons.Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }

      PanelSeparator { foreground: Commons.Color.foreground }

      RowLayout {
        width: parent.width
        spacing: Style.space(6)

        PanelSectionHeader {
          text: "DOCUMENTS"
          Layout.fillWidth: true
        }
        Button {
          text: "Select new"
          fontSize: Style.font.caption
          foreground: Commons.Color.muted
          horizontalPadding: Style.space(6)
          verticalPadding: Style.space(2)
          enabled: PrintService.newCount > 0
          onClicked: PrintService.selectNew()
        }
        Button {
          text: "Clear"
          fontSize: Style.font.caption
          foreground: Commons.Color.muted
          horizontalPadding: Style.space(6)
          verticalPadding: Style.space(2)
          enabled: PrintService.selectedCount > 0
          onClicked: PrintService.clearSelection()
        }
      }

      Flickable {
        id: flick
        width: parent.width
        height: Math.min(listColumn.implicitHeight, Style.space(300))
        contentWidth: width
        contentHeight: listColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        visible: PrintService.documents.length > 0

        Column {
          id: listColumn
          width: flick.width - (flick.contentHeight > flick.height ? Style.space(8) : 0)
          spacing: Style.space(2)

          Repeater {
            model: PrintService.documents

            delegate: DocumentRow {
              required property var modelData
              required property int index
              doc: modelData
              selected: PrintService.isSelected(modelData.path)
              hasCursor: root.cursor === index
              onToggled: {
                root.cursor = index
                PrintService.toggle(modelData.path)
              }
            }
          }
        }
      }

      Rectangle {
        visible: flick.visible && flick.contentHeight > flick.height
        width: Style.space(3)
        height: Math.max(Style.space(24), flick.visibleArea.heightRatio * flick.height)
        x: flick.width - width - Style.space(2)
        y: flick.visibleArea.yPosition * flick.height + Style.space(2)
        radius: width / 2
        color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g,
                       Commons.Color.foreground.b, 0.25)
      }

      Text {
        visible: PrintService.loaded && PrintService.documents.length === 0
        width: parent.width
        text: "No documents. Drop PDF, image or text files into "
          + root.shortFolder() + "."
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Commons.Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }

      PanelSeparator { foreground: Commons.Color.foreground }

      RowLayout {
        width: parent.width
        spacing: Style.space(6)

        Button {
          Layout.fillWidth: true
          leftAlign: true
          text: PrintService.printing
            ? "Printing…"
            : "Print new" + (PrintService.newCount > 0 ? " (" + PrintService.newCount + ")" : "")
          iconText: "\uf02f"
          enabled: !PrintService.printing && PrintService.printer !== ""
            && PrintService.newCount > 0
          foreground: enabled ? Commons.Color.foreground : Commons.Color.muted
          onClicked: PrintService.printNew()
        }
        Button {
          Layout.fillWidth: true
          leftAlign: true
          text: "Print selected"
            + (PrintService.selectedCount > 0 ? " (" + PrintService.selectedCount + ")" : "")
          iconText: "\uf0c5"
          enabled: !PrintService.printing && PrintService.printer !== ""
            && PrintService.selectedCount > 0
          foreground: enabled ? Commons.Color.foreground : Commons.Color.muted
          onClicked: PrintService.printSelected()
        }
      }

      Text {
        width: parent.width
        visible: text !== ""
        text: PrintService.message !== ""
          ? PrintService.message
          : PrintService.errorText
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: PrintService.message !== ""
          ? (PrintService.messageError ? Commons.Color.urgent : Commons.Color.muted)
          : Commons.Color.urgent
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
  }
}
