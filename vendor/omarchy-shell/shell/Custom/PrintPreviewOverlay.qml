import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Custom
import qs.Ui

// Full-screen document reader for the print panel. PDF pages are rendered by
// `omarchy-print pages` into a content-addressed cache; images are one page.
// The page column scrolls with the wheel, touchpad, arrows, PageUp/PageDown,
// Home/End, and Space. Escape or a click outside the card closes it.
Item {
  id: root

  width: 0
  height: 0

  property bool shown: false
  property var doc: null
  property var targetScreen: null
  property var pages: []
  property real pageScale: 1
  property real pageNaturalWidth: 0
  property real pageNaturalHeight: 0
  property bool loading: false
  property string errorText: ""
  property int token: 0
  property real dismissAfter: 0

  signal closed()

  function canPreview(document) {
    if (!document) return false
    return /\.(pdf|png|jpe?g|webp)$/i.test(String(document.name || ""))
  }

  function open(document) {
    if (!canPreview(document)) return false
    root.doc = document
    root.pages = []
    root.pageScale = 1
    root.pageNaturalWidth = 0
    root.pageNaturalHeight = 0
    root.loading = true
    root.errorText = ""
    root.token += 1
    pagesProc.target = document.path
    pagesProc.token = root.token
    if (pagesProc.running) pagesProc.running = false
    pagesProc.running = true
    root.shown = true
    // Ignore the click that opened the reader: it lands outside the centered
    // card and would otherwise dismiss the surface in its first frame.
    root.dismissAfter = Date.now() + 300
    return true
  }

  function close() {
    if (!root.shown) return
    root.shown = false
    root.token += 1
    if (pagesProc.running) pagesProc.running = false
    root.pages = []
    root.doc = null
    root.loading = false
    root.errorText = ""
    root.closed()
  }

  function scrollBy(delta) {
    var maxY = Math.max(0, pageFlick.contentHeight - pageFlick.height)
    pageFlick.contentY = Math.max(0, Math.min(maxY, pageFlick.contentY + delta))
  }

  OverlayWindow {
    id: window

    shown: root.shown
    shownKeyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "omarchy-print-preview"

    onShownChanged: {
      if (shown) {
        // OverlayWindow picks the focused output when it maps. The print panel
        // may live on another one, so put the reader on the panel's screen.
        if (root.targetScreen) {
          Qt.callLater(function() { window.targetScreen = root.targetScreen })
        }
        Qt.callLater(function() { keyCatcher.forceActiveFocus() })
      }
    }
    onBackingWindowVisibleChanged: {
      if (shown && backingWindowVisible) {
        Qt.callLater(function() { keyCatcher.forceActiveFocus() })
      }
    }

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(Commons.Color.background.r, Commons.Color.background.g,
                     Commons.Color.background.b, 0.90)
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.AllButtons
      onClicked: {
        if (Date.now() >= root.dismissAfter) root.close()
      }
    }

    Rectangle {
      id: card

      // A document-sized reading window, not a full-screen billboard: the card
      // follows the first page's natural (96 dpi) width and height, capped to
      // the output. Narrow receipts get a narrow reader; A4 gets a roughly
      // A4-wide one, and the page column scrolls for further pages.
      width: Math.min(parent.width - Style.space(48),
                      Math.max(Style.space(520),
                               Math.min(Style.space(900),
                                        root.pageNaturalWidth > 0
                                          ? root.pageNaturalWidth + Style.space(48)
                                          : Style.space(760))))
      height: Math.min(parent.height - Style.space(48),
                       Math.max(Style.space(500),
                                root.pageNaturalHeight > 0
                                  ? root.pageNaturalHeight + Style.space(90)
                                  : Style.space(1000)))
      anchors.centerIn: parent
      color: Commons.Color.popups.background
      radius: Style.cornerRadius
      border.width: 1
      border.color: Commons.Color.popups.border

      // Clicks on the card must not reach the scrim behind it. Kept below the
      // content so the Flickable still receives wheel and drag events.
      MouseArea {
        anchors.fill: parent
        onClicked: {}
      }

      Item {
        id: keyCatcher

        anchors.fill: parent
        focus: root.shown
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          var page = pageFlick.height * 0.85
          if (event.key === Qt.Key_Escape) {
            root.close()
          } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
            root.scrollBy(Style.space(90))
          } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
            root.scrollBy(-Style.space(90))
          } else if (event.key === Qt.Key_PageDown || event.key === Qt.Key_Space) {
            root.scrollBy(page)
          } else if (event.key === Qt.Key_PageUp) {
            root.scrollBy(-page)
          } else if (event.key === Qt.Key_Home) {
            pageFlick.contentY = 0
          } else if (event.key === Qt.Key_End) {
            pageFlick.contentY = Math.max(0, pageFlick.contentHeight - pageFlick.height)
          } else {
            return
          }
          event.accepted = true
        }
      }

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.space(14)
        spacing: Style.space(10)

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(8)

          Text {
            Layout.fillWidth: true
            text: root.doc ? String(root.doc.name || "") : ""
            textFormat: Text.PlainText
            elide: Text.ElideMiddle
            color: Commons.Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
          }

          Text {
            visible: root.pages.length > 0
            text: root.pages.length + (root.pages.length === 1 ? " page" : " pages")
            color: Commons.Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }

          PanelActionButton {
            iconText: "\uf00d"
            tooltipText: "Close"
            foreground: Commons.Color.foreground
            onClicked: root.close()
          }
        }

        PanelSeparator {
          Layout.fillWidth: true
          foreground: Commons.Color.foreground
        }

        Item {
          Layout.fillWidth: true
          Layout.fillHeight: true

          Flickable {
            id: pageFlick
            anchors.fill: parent
            contentWidth: width
            contentHeight: pageColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            Column {
              id: pageColumn
              width: pageFlick.width - (pageFlick.contentHeight > pageFlick.height ? Style.space(12) : 0)
              spacing: Style.space(12)

              Repeater {
                model: root.pages

                delegate: Rectangle {
                  required property var modelData
                  required property int index

                  width: Math.min(pageImage.implicitWidth * root.pageScale,
                                  pageColumn.width)
                  height: pageImage.implicitWidth > 0
                    ? width * pageImage.implicitHeight / pageImage.implicitWidth
                    : 0
                  x: (pageColumn.width - width) / 2
                  color: "#ffffff"
                  radius: Style.space(2)
                  clip: true

                  Image {
                    id: pageImage
                    anchors.fill: parent
                    source: Util.fileUrl(modelData)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: true
                    smooth: true

                    onStatusChanged: {
                      if (index === 0 && status === Image.Ready) {
                        root.pageNaturalWidth = implicitWidth * root.pageScale
                        root.pageNaturalHeight = implicitHeight * root.pageScale
                      }
                    }
                  }
                }
              }
            }
          }

          Rectangle {
            visible: pageFlick.contentHeight > pageFlick.height
            width: Style.space(4)
            height: Math.max(Style.space(24), pageFlick.visibleArea.heightRatio * pageFlick.height)
            x: pageFlick.width - width - Style.space(2)
            y: pageFlick.visibleArea.yPosition * pageFlick.height + Style.space(2)
            radius: width / 2
            color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g,
                           Commons.Color.foreground.b, 0.30)
          }

          Text {
            anchors.centerIn: parent
            width: parent.width * 0.8
            horizontalAlignment: Text.AlignHCenter
            visible: root.errorText !== "" || (root.loading && root.pages.length === 0)
            text: root.errorText !== ""
              ? root.errorText
              : "Rendering pages…"
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: root.errorText !== "" ? Commons.Color.urgent : Commons.Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }

          // Take the wheel before Flickable's few-line default so one notch
          // moves a useful part of a page. Clicks are swallowed here, inside
          // the card, so they still cannot close the reader.
          MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onWheel: function(event) {
              var delta = event.pixelDelta.y !== 0
                ? event.pixelDelta.y * 3
                : event.angleDelta.y * 4
              root.scrollBy(-delta)
              event.accepted = true
            }
          }
        }
      }
    }
  }

  Process {
    id: pagesProc

    property string target: ""
    property int token: 0

    command: [PrintService.helperPath(), "pages", target]

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (pagesProc.token !== root.token) return
        var parsed = null
        try { parsed = JSON.parse(String(text || "")) } catch (error) { parsed = null }
        if (!parsed || !Array.isArray(parsed.pages) || parsed.pages.length === 0) {
          root.loading = false
          root.errorText = "Cannot read document pages"
          return
        }
        root.pages = parsed.pages
        root.pageScale = Number(parsed.scale) > 0 ? Number(parsed.scale) : 1
        root.loading = false
        pageFlick.contentY = 0
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (pagesProc.token !== root.token) return
        var message = String(text || "").trim()
        if (message !== "") root.errorText = message
      }
    }
    onExited: function(code) {
      if (pagesProc.token !== root.token) return
      root.loading = false
      if (code !== 0 && root.errorText === "")
        root.errorText = "Cannot render document pages"
    }
  }
}
