import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Ui
import qs.Commons
import qs.Commons as Commons

BarWidget {
  id: root
  moduleName: "omarchy.media"

  readonly property var mediaService: bar?.shell?.firstPartyServiceFor("omarchy.media")
  readonly property var activePlayer: mediaService ? mediaService.activePlayer : null
  readonly property var sourcePlayers: mediaService ? mediaService.sourcePlayers : []

  readonly property bool hasMedia: activePlayer !== null && (activePlayer.trackTitle || activePlayer.trackArtist)
  readonly property bool isPlaying: !!activePlayer && !!activePlayer.isPlaying
  readonly property string playIcon: activePlayer && activePlayer.isPlaying ? "󰏤" : "󰐊"
  readonly property string title: activePlayer ? (activePlayer.trackTitle || "") : ""
  readonly property string artist: activePlayer ? (activePlayer.trackArtist || "") : ""

  property bool popupOpen: false

  // MPRIS volume is not universal: Chromium exposes no Volume property at
  // all. Fall back to the player's own PipeWire stream, then to the default
  // sink, so the wheel always changes what you hear.
  readonly property var audioNode: {
    var player = root.activePlayer
    if (!player) return null
    var wanted = []
    var identity = String(player.identity || "").toLowerCase()
    var entry = String(player.desktopEntry || "").toLowerCase()
    if (identity.length > 0) wanted.push(identity)
    if (entry.length > 0 && wanted.indexOf(entry) < 0) wanted.push(entry)
    if (wanted.length === 0) return null
    var nodes = Pipewire.nodes ? Pipewire.nodes.values : []
    for (var index = 0; index < nodes.length; index++) {
      var node = nodes[index]
      // Playback streams report isSink=true (the audio panel relies on the
      // same quirk), so only isStream and a bound audio block matter.
      if (!node || !node.isStream || !node.audio) continue
      var properties = ({})
      try {
        properties = node.properties || ({})
      } catch (error) {
        properties = ({})
      }
      var app = String(properties["application.name"] || "").toLowerCase()
      var binary = String(properties["application.process.binary"] || "").toLowerCase()
      if (wanted.indexOf(app) >= 0 || wanted.indexOf(binary) >= 0) return node
    }
    return null
  }

  function adjustPlayerVolume(delta) {
    var player = root.activePlayer
    if (!player) return false
    // Prefer the player's own PipeWire stream: Chromium advertises MPRIS
    // Volume but ignores writes, while its stream volume always works.
    var node = root.audioNode
    if (node && node.audio) {
      node.audio.volume = Math.max(0, Math.min(1.5, node.audio.volume + delta))
      return true
    }
    if (player.volumeSupported) {
      var current = Number(player.volume)
      if (isFinite(current)) {
        player.volume = Math.max(0, Math.min(1, current + delta))
        return true
      }
    }
    var sink = Pipewire.defaultAudioSink
    if (sink && sink.audio) {
      sink.audio.volume = Math.max(0, Math.min(1, sink.audio.volume + delta))
      return true
    }
    return false
  }

  // Same shape as the other bar panels, so `shell toggle omarchy.media` and
  // the bar's popout coordinator can drive it.
  readonly property bool opened: popupOpen
  function open() { popupOpen = true }
  function close() { popupOpen = false }
  function toggle() { popupOpen = !popupOpen }
  property real maxLabelWidth: 180

  visible: hasMedia
  implicitWidth: hasMedia ? row.implicitWidth + Style.space(14) : 0
  implicitHeight: barSize

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Style.space(6)

    Text {
      id: glyph
      textFormat: Text.PlainText
      anchors.verticalCenter: parent.verticalCenter
      text: root.playIcon
      color: activePlayer && activePlayer.isPlaying ? root.bar.barForeground : Qt.darker(root.bar.barForeground, 1.5)
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.body
      Behavior on color {
        enabled: !root.bar || root.bar.foregroundAnimationEnabled
        ColorAnimation { duration: Style.duration(160) }
      }
    }

    Item {
      id: scrollClip
      width: Math.min(root.maxLabelWidth, labelText.implicitWidth)
      height: glyph.height
      clip: true
      anchors.verticalCenter: parent.verticalCenter
      visible: !root.bar.vertical && root.title !== ""

      Text {
        id: labelText
        textFormat: Text.PlainText
        text: root.title + (root.artist ? "  ·  " + root.artist : "")
        color: root.bar.barForeground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.body
        anchors.verticalCenter: parent.verticalCenter

        property bool needsScroll: implicitWidth > scrollClip.width

        // Each frame of the scroll redraws the bar, so it only runs while the
        // track is playing and the bar is on screen to show it.
        NumberAnimation on x {
          id: scrollAnim
          running: labelText.needsScroll && root.isPlaying && root.visible && !root.bar.barHidden && !root.popupOpen && !root.bar.vertical && !Style.reduceMotion
          // Stopped, the title reads from its start again.
          onRunningChanged: if (!running) labelText.x = 0
          loops: Animation.Infinite
          duration: Style.duration(Math.max(6000, labelText.implicitWidth * 25))
          from: scrollClip.width
          to: -labelText.implicitWidth
          easing.type: Easing.Linear
        }
      }
    }
  }

  // Scriptable volume, and the headless check for the pipewire fallback.
  ShellIpc {
    target: "omarchy.media"
    function volumeUp(): void { root.adjustPlayerVolume(0.05) }
    function volumeDown(): void { root.adjustPlayerVolume(-0.05) }
    function volumeStatus(): string {
      var node = root.audioNode
      return JSON.stringify({
        player: root.activePlayer ? String(root.activePlayer.identity || "") : "",
        mprisVolume: root.activePlayer ? root.activePlayer.volumeSupported : false,
        node: node ? String(node.name || "") : "",
        sources: (function() {
          var list = []
          for (var index = 0; index < root.sourcePlayers.length; index++) {
            var player = root.sourcePlayers[index]
            if (player) list.push(String(player.identity || "") + "|" + String(player.dbusName || ""))
          }
          return list
        })(),
        nodeVolume: node && node.audio ? node.audio.volume : null,
        playerVolume: root.activePlayer ? root.activePlayer.volume : null,
        streams: (function() {
          var list = []
          var nodes = Pipewire.nodes ? Pipewire.nodes.values : []
          for (var index = 0; index < nodes.length; index++) {
            var node = nodes[index]
            if (!node || !node.isStream) continue
            var properties = ({})
            try { properties = node.properties || ({}) } catch (error) { properties = ({}) }
            list.push({
              name: String(node.name || ""),
              isSink: node.isSink === true,
              hasAudio: !!node.audio,
              app: String(properties["application.name"] || ""),
              binary: String(properties["application.process.binary"] || "")
            })
          }
          return list
        })()
      })
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.activePlayer ? Qt.PointingHandCursor : Qt.ArrowCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    onClicked: function(mouse) {
      if (!root.activePlayer && mouse.button !== Qt.LeftButton) return
      if (mouse.button === Qt.MiddleButton) {
        if (root.mediaService) root.mediaService.runAction("next", false)
      } else if (mouse.button === Qt.RightButton) {
        // Right click is the transport click: pause/resume without opening
        // the panel. The panel has its own pause button for the same job.
        if (root.mediaService) root.mediaService.runAction("playPause", false)
      } else {
        root.toggle()
      }
    }
    onWheel: function(wheel) {
      wheel.accepted = true
      if (!root.activePlayer) return
      // The wheel is the player's volume. Players that do not expose MPRIS
      // volume keep the old track skipping, so the gesture is never dead.
      if (root.adjustPlayerVolume(wheel.angleDelta.y > 0 ? 0.05 : -0.05)) return
      if (wheel.angleDelta.y > 0 && root.mediaService) root.mediaService.runAction("previous", false)
      else if (wheel.angleDelta.y < 0 && root.mediaService) root.mediaService.runAction("next", false)
    }
    onEntered: if (root.bar) root.bar.showTooltip(root, root.hasMedia ? (root.title + (root.artist ? " — " + root.artist : "")) : "")
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  // KeyboardPanel rather than PopupCard: the popup needs Escape and
  // outside-click dismissal, and only the keyboard-panel surface takes
  // keyboard focus while a fullscreen app is in front.
  KeyboardPanel {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(320))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(10)

      // Wheel over the panel is the player volume too, not a scroll of the
      // card. A handler rather than a MouseArea keeps the controls clickable.
      WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) {
          if (root.adjustPlayerVolume(event.angleDelta.y > 0 ? 0.05 : -0.05))
            event.accepted = true
        }
      }

      Row {
        spacing: Style.space(10)
        width: parent.width

        BorderSurface {
          width: Style.space(64)
          height: Style.space(64)
          radius: Style.spacing.labelGap
          color: Style.normalFillFor(root.bar.foreground, Commons.Color.accent)
          borderSpec: Border.controlSpec("normal", root.bar.foreground, Commons.Color.accent)

          // Decode the art at the size it is drawn, not the size the player
          // serves it at. The popup is built on every monitor at startup.
          SizedImage {
            anchors.fill: parent
            anchors.margins: Style.space(2)
            crop: true
            url: root.activePlayer && root.activePlayer.trackArtUrl ? root.activePlayer.trackArtUrl : ""
            visible: url != ""
          }

          Text {
            anchors.centerIn: parent
            visible: !root.activePlayer || !root.activePlayer.trackArtUrl
            text: "󰝚"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.displayLarge
          }
        }

        Column {
          spacing: Style.space(4)
          width: parent.width - Style.space(74)

          Text {
            textFormat: Text.PlainText
            text: root.title || I18n.t("media.nothingPlaying")
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
            elide: Text.ElideRight
            width: parent.width
          }

          Text {
            textFormat: Text.PlainText
            text: root.artist
            color: Qt.darker(root.bar.foreground, 1.3)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
            width: parent.width
            visible: text !== ""
          }

          Text {
            textFormat: Text.PlainText
            text: root.activePlayer && root.activePlayer.trackAlbum ? root.activePlayer.trackAlbum : ""
            color: Qt.darker(root.bar.foreground, 1.6)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            width: parent.width
            visible: text !== ""
          }
        }
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(6)
        // Transport controls keep previous, play, next in every language,
        // matching their glyphs; media controls are not mirrored.
        LayoutMirroring.enabled: false
        LayoutMirroring.childrenInherit: true

        Button {
          iconText: "󰒮"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.activePlayer && root.activePlayer.canGoPrevious
          opacity: enabled ? 1.0 : 0.4
          onClicked: if (root.mediaService) root.mediaService.runAction("previous", false, root.mediaService.playerKey(root.activePlayer))
        }

        Button {
          iconText: root.activePlayer && root.activePlayer.isPlaying ? "󰏤" : "󰐊"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.panelGap
          verticalPadding: Style.spacing.controlPaddingY
          iconSize: Style.font.iconLarge
          enabled: root.activePlayer && (root.activePlayer.canTogglePlaying || root.activePlayer.canPlay || root.activePlayer.canPause)
          opacity: enabled ? 1.0 : 0.4
          onClicked: if (root.mediaService) root.mediaService.runAction("playPause", false, root.mediaService.playerKey(root.activePlayer))
        }

        Button {
          iconText: "󰒭"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.activePlayer && root.activePlayer.canGoNext
          opacity: enabled ? 1.0 : 0.4
          onClicked: if (root.mediaService) root.mediaService.runAction("next", false, root.mediaService.playerKey(root.activePlayer))
        }
      }

      PanelSeparator {
        visible: root.sourcePlayers.length > 1
        foreground: root.bar.foreground
      }

      Column {
        id: sourceList
        visible: root.sourcePlayers.length > 1
        width: parent.width
        spacing: Style.space(4)

        Repeater {
          model: root.sourcePlayers

          BorderSurface {
            id: sourceRow
            required property var modelData

            readonly property var player: modelData
            readonly property bool selected: root.activePlayer && player
              && root.mediaService.playerKey(root.activePlayer) === root.mediaService.playerKey(player)
            readonly property string sourceTitle: player ? (player.trackTitle || player.identity || player.desktopEntry || I18n.t("media.mediaSource")) : I18n.t("media.mediaSource")
            readonly property string sourceDetail: player && player.trackArtist ? player.trackArtist : (player && player.identity ? player.identity : "")

            width: sourceList.width
            height: sourceInner.implicitHeight + Style.space(10)
            radius: Style.spacing.labelGap
            color: selected ? Style.selectedFillFor(root.bar.foreground, Commons.Color.accent) : "transparent"
            borderSpec: selected ? Border.controlSpec("normal", root.bar.foreground, Commons.Color.accent) : Border.none()

            Row {
              id: sourceInner
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: sourceRow.borderLeft + Style.space(8)
              anchors.rightMargin: sourceRow.borderRight + Style.space(8)
              spacing: Style.space(8)

              Text {
                textFormat: Text.PlainText
                text: sourceRow.player && sourceRow.player.isPlaying ? "󰏤" : "󰐊"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
                width: Style.space(18)
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenter: parent.verticalCenter
              }

              Column {
                width: parent.width - Style.space(26)
                spacing: Style.space(1)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  textFormat: Text.PlainText
                  text: sourceRow.sourceTitle
                  color: root.bar.foreground
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: sourceRow.selected
                  elide: Text.ElideRight
                  width: parent.width
                }

                Text {
                  textFormat: Text.PlainText
                  text: sourceRow.sourceDetail
                  color: Qt.darker(root.bar.foreground, 1.5)
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                  width: parent.width
                  visible: text !== ""
                }
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: if (root.mediaService) root.mediaService.selectPlayer(root.mediaService.playerKey(sourceRow.player))
            }
          }
        }
      }
    }
  }
}
