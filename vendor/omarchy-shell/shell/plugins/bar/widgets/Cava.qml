import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Commons
import qs.Ui

// Cava spectrum for the bar.
//
// The process only runs while an MPRIS player is playing (or while someone
// calls `local.cava preview` for a few seconds), so the bar does not pay for
// 30 fps of rendering with nothing to show. Levels arrive one frame per line:
// 16 bar heights in 0..1000 separated by `;`.
BarWidget {
  id: root
  moduleName: "local.cava"

  readonly property string configPath: Quickshell.env("HOME") + "/.config/cava/omarchy-bar.conf"
  readonly property int barCount: 16
  readonly property real maxBarHeight: Math.max(4, barSize - Style.space(10))
  readonly property int barWidth: Style.space(2)
  readonly property int barGap: Style.space(1)
  readonly property var players: Mpris.players ? Mpris.players.values : []
  readonly property bool active: playing || previewing

  property bool playing: false
  property bool previewing: false
  property var levels: []

  visible: active && !vertical
  implicitWidth: visible ? barCount * barWidth + (barCount - 1) * barGap : 0
  implicitHeight: barSize

  function poll() {
    var list = root.players
    var any = false
    for (var index = 0; index < list.length; index++)
      if (list[index] && list[index].isPlaying) any = true
    root.playing = any
  }

  // cava writes `12;45;...` for every frame; keep only the configured bars and
  // clamp so a broken line cannot draw outside the bar.
  function consume(line) {
    var parts = String(line).split(";")
    var values = []
    for (var index = 0; index < root.barCount; index++) {
      var value = parseInt(parts[index], 10)
      values.push(isFinite(value) ? Math.max(0, Math.min(1000, value)) : 0)
    }
    root.levels = values
  }

  function startPreview() {
    root.previewing = true
    previewTimer.restart()
  }

  function stopAll() {
    root.previewing = false
    previewTimer.stop()
    stopTimer.stop()
    cavaProc.running = false
    root.levels = []
  }

  onActiveChanged: {
    if (root.active) {
      stopTimer.stop()
      if (!cavaProc.running) cavaProc.running = true
    } else {
      stopTimer.restart()
    }
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.poll()
  }

  Timer {
    id: previewTimer
    interval: 8000
    onTriggered: root.previewing = false
  }

  // Keep the last frame visible for a moment so a short pause does not flash
  // the bar layout twice.
  Timer {
    id: stopTimer
    interval: 2000
    onTriggered: {
      if (root.active) return
      cavaProc.running = false
      root.levels = []
    }
  }

  Process {
    id: cavaProc
    command: ["cava", "-p", root.configPath]
    stdout: SplitParser {
      onRead: function(line) { root.consume(line) }
    }
    onExited: root.levels = []
  }

  Row {
    anchors.centerIn: parent
    spacing: root.barGap

    Repeater {
      model: root.barCount

      delegate: Rectangle {
        required property int index
        width: root.barWidth
        height: Math.max(1, Math.pow((root.levels[index] || 0) / 1000, 0.7) * root.maxBarHeight)
        anchors.verticalCenter: parent.verticalCenter
        radius: 1
        color: root.bar ? root.bar.barForeground : Commons.Color.foreground
        opacity: 0.85
        Behavior on height {
          enabled: !Style.reduceMotion
          NumberAnimation { duration: Style.duration(80) }
        }
      }
    }
  }

  ShellIpc {
    target: "local.cava"

    // The bar exists per monitor, so a demo has to start every instance.
    function preview(): void {
      root.startPreview()
      root.broadcast("startPreview")
    }
    function stop(): void {
      root.stopAll()
      root.broadcast("stopAll")
    }
    function status(): string {
      return JSON.stringify({
        active: root.active,
        playing: root.playing,
        previewing: root.previewing,
        bars: root.levels.length,
        values: root.levels
      })
    }
  }
}
