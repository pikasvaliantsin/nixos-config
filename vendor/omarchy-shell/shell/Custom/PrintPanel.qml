import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Custom
import qs.Ui

// The print folder, its documents, and their printed state. A row check picks
// a document for the next batch; printed documents can be checked again to
// reprint them. "Print new" sends only documents the helper has not recorded
// yet. Hovering a row (or moving the keyboard cursor) previews its first page
// or image in the right column.
KeyboardPanel {
  id: root

  contentWidth: root.fittedContentWidth(Style.space(770))
  contentHeight: root.fittedContentHeight(panelBody.implicitHeight, Style.space(640))
  focusTarget: keyCatcher

  // Keyboard cursor over the document rows: Up/Down move, Space/Enter pick the
  // row for the next batch. Hovering a row also moves the cursor, so the
  // preview stays on the document the pointer last visited without a click.
  property int cursor: -1

  // Preview state. `previewToken` rejects a render that finishes after the
  // pointer has already moved to another row.
  property int previewToken: 0
  property string previewSource: ""
  property string previewText: ""
  property string previewError: ""
  property bool previewLoading: false
  property real fullscreenCooldownUntil: 0

  signal fullscreenRequested(var doc)

  readonly property var previewDoc: {
    var docs = PrintService.documents
    if (root.cursor >= 0 && root.cursor < docs.length) return docs[root.cursor]
    return null
  }

  onPreviewDocChanged: root.loadPreview()
  Component.onCompleted: root.loadPreview()

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
    if (!flick || !listColumn) return
    var row = listColumn.children[cursor]
    if (!row) return
    if (row.y < flick.contentY) flick.contentY = row.y
    else if (row.y + row.height > flick.contentY + flick.height) {
      flick.contentY = row.y + row.height - flick.height
    }
  }

  function setHovered(doc) {
    if (doc) {
      for (var i = 0; i < PrintService.documents.length; i++) {
        if (PrintService.documents[i].path === doc.path) {
          root.cursor = i
          return
        }
      }
    }
  }

  function canFullscreen() {
    var doc = root.previewDoc
    return !!doc && /\.(pdf|png|jpe?g|webp)$/i.test(String(doc.name || ""))
  }

  function openFullscreen() {
    var doc = root.previewDoc
    if (!root.canFullscreen()) return
    if (Date.now() < root.fullscreenCooldownUntil) return
    if (fullscreenHover) fullscreenHover.stop()
    root.fullscreenRequested(doc)
  }

  function loadPreview() {
    root.previewToken += 1
    var token = root.previewToken
    root.previewSource = ""
    root.previewText = ""
    root.previewError = ""
    root.previewLoading = false

    var doc = root.previewDoc
    if (!doc) return

    var name = String(doc.name || "")
    if (/\.(png|jpe?g|webp)$/i.test(name)) {
      root.previewSource = Util.fileUrl(doc.path)
      return
    }
    if (/\.pdf$/i.test(name)) {
      if (!previewProc) return
      root.previewLoading = true
      previewProc.target = doc.path
      previewProc.token = token
      if (previewProc.running) previewProc.running = false
      previewProc.running = true
      return
    }
    if (/\.txt$/i.test(name)) {
      if (!textProc) return
      root.previewLoading = true
      textProc.target = doc.path
      textProc.token = token
      if (textProc.running) textProc.running = false
      textProc.running = true
      return
    }
    root.previewError = "No preview for this format"
  }

  onOpenChanged: {
    if (open) {
      PrintService.clearMessage()
      PrintService.refresh()
      root.cursor = PrintService.documents.length > 0 ? 0 : -1
      root.loadPreview()
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
      onEntered: root.setHovered(row.doc)
    }

    // MouseArea hover can be shadowed by the row's text/checkbox children in
    // some styles; the handler sees the whole row regardless and pins the
    // preview to this document without a click.
    HoverHandler {
      onHoveredChanged: if (hovered) root.setHovered(row.doc)
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

  Item {
    id: panelBody

    anchors.fill: parent
    implicitHeight: keyCatcher.implicitHeight

    PanelKeyCatcher {
      id: keyCatcher

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
        } else if (text === "f") {
          root.openFullscreen()
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
          spacing: Style.space(10)

          Column {
            id: listPane

            Layout.fillWidth: true
            Layout.preferredWidth: Style.space(460)
            Layout.fillHeight: true
            spacing: Style.space(8)

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

            Item {
              id: flickHolder
              width: parent.width
              height: Math.min(listColumn.implicitHeight, Style.space(310))

              Flickable {
                id: flick
                anchors.fill: parent
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

          Rectangle {
            id: previewPane

            Layout.preferredWidth: Style.space(280)
            Layout.minimumWidth: Style.space(200)
            Layout.fillHeight: true
            implicitHeight: Style.space(300)
            radius: Style.cornerRadius
            color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g,
                           Commons.Color.foreground.b, 0.035)
            border.width: 1
            border.color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g,
                                  Commons.Color.foreground.b, 0.12)

            Column {
              anchors.fill: parent
              anchors.margins: Style.space(10)
              spacing: Style.space(8)

              RowLayout {
                id: previewHeader
                width: parent.width
                spacing: Style.space(4)

                Text {
                  id: previewTitle
                  Layout.fillWidth: true
                  text: root.previewDoc
                    ? String(root.previewDoc.name || "")
                    : "PREVIEW"
                  textFormat: Text.PlainText
                  elide: Text.ElideMiddle
                  color: root.previewDoc ? Commons.Color.foreground : Commons.Color.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }

                PanelActionButton {
                  iconText: "\uf065"
                  tooltipText: "Fullscreen preview"
                  foreground: Commons.Color.foreground
                  enabled: root.canFullscreen()
                  onClicked: root.openFullscreen()
                }
              }

              Item {
                id: previewStage
                width: parent.width
                height: Math.max(0, parent.height - previewHeader.implicitHeight
                                 - previewHint.implicitHeight - Style.space(16))
                clip: true

                Image {
                  id: previewImage
                  anchors.fill: parent
                  source: root.previewSource
                  visible: source !== "" && status === Image.Ready
                  fillMode: Image.PreserveAspectFit
                  asynchronous: true
                  cache: false

                  onStatusChanged: {
                    if (status === Image.Error && root.previewSource !== "")
                      root.previewError = "Cannot load preview"
                  }
                }

                Text {
                  visible: root.previewText !== "" && !previewImage.visible
                  anchors.fill: parent
                  text: root.previewText
                  textFormat: Text.PlainText
                  wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                  clip: true
                  color: Commons.Color.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }

                Text {
                  anchors.centerIn: parent
                  width: parent.width
                  horizontalAlignment: Text.AlignHCenter
                  visible: root.previewError !== ""
                    || (!previewImage.visible && root.previewText === ""
                        && (root.previewSource === "" || root.previewLoading))
                  text: root.previewError !== ""
                    ? root.previewError
                    : (root.previewLoading ? "Loading preview…" : "Hover a document")
                  textFormat: Text.PlainText
                  wrapMode: Text.WordWrap
                  color: root.previewError !== ""
                    ? Commons.Color.urgent
                    : Commons.Color.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: root.canFullscreen() ? Qt.PointingHandCursor : Qt.ArrowCursor
                  onEntered: if (root.canFullscreen()
                                 && Date.now() >= root.fullscreenCooldownUntil)
                               fullscreenHover.restart()
                  onExited: fullscreenHover.stop()
                  onClicked: root.openFullscreen()
                }
              }

              Text {
                id: previewHint
                width: parent.width
                visible: root.canFullscreen()
                text: "Hover or click for fullscreen"
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Commons.Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }
            }
          }
        }
      }
    }

    Process {
      id: previewProc

      property string target: ""
      property int token: 0

      command: [PrintService.helperPath(), "preview", target]

      stdout: StdioCollector {
        waitForEnd: true
        onStreamFinished: {
          if (previewProc.token !== root.previewToken) return
          var path = String(text || "").trim()
          if (path !== "") root.previewSource = Util.fileUrl(path)
          else root.previewError = "No preview"
        }
      }
      stderr: StdioCollector {
        waitForEnd: true
        onStreamFinished: {
          if (previewProc.token !== root.previewToken) return
          var message = String(text || "").trim()
          if (message !== "") root.previewError = message
        }
      }
      onExited: function(code) {
        if (previewProc.token !== root.previewToken) return
        root.previewLoading = false
        if (code !== 0 && root.previewError === "")
          root.previewError = "Cannot render preview"
      }
    }

    Process {
      id: textProc

      property string target: ""
      property int token: 0

      command: ["head", "-c", "4000", "--", target]

      stdout: StdioCollector {
        waitForEnd: true
        onStreamFinished: {
          if (textProc.token !== root.previewToken) return
          var body = String(text || "")
          if (body.trim() === "") root.previewError = "Empty file"
          else root.previewText = body
        }
      }
      onExited: function(code) {
        if (textProc.token !== root.previewToken) return
        root.previewLoading = false
        if (code !== 0 && root.previewError === "")
          root.previewError = "Cannot read preview"
      }
    }

    // The full-screen reader lives in the bar widget, not here: closing this
    // KeyboardPanel must not take its layer surface down with it.
    Timer {
      id: fullscreenHover
      interval: 500
      repeat: false
      onTriggered: root.openFullscreen()
    }

    // Lives inside the content item: KeyboardPanel's default property is its
    // content list, so a non-Item Connections object at the root would be
    // assigned to it and fail to load the whole panel.
    Connections {
      target: PrintService
      function onDocumentsChanged() {
        if (PrintService.documents.length === 0) root.cursor = -1
        else root.cursor = Math.max(0, Math.min(root.cursor, PrintService.documents.length - 1))
      }
    }
  }
}
