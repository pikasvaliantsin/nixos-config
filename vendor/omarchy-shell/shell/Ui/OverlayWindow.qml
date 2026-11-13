import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons as Commons

// Map a fresh fullscreen surface on each open. Keep its first frames
// transparent until Qt receives the output's scale, so it opens sharp without
// retaining a parked surface that can be closed when a monitor disconnects.
PanelWindow {
  id: window

  // Whether the overlay is showing. Drive this instead of visible.
  property bool shown: false
  property int shownLayer: WlrLayer.Overlay
  property int shownKeyboardFocus: WlrKeyboardFocus.Exclusive

  property var targetScreen: null
  // The omarchy shell normally runs on Hyprland; on niri there is no
  // Hyprland monitor model, so the overlay must pick a Quickshell screen and
  // skip the Hyprland scale check instead of staying invisible.
  readonly property bool niriActive: Commons.Niri.active
  readonly property bool hyprlandActive: !niriActive && Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") !== ""
  readonly property var targetMonitor: {
    if (!hyprlandActive) return null
    var monitors = Hyprland.monitors.values
    for (var i = 0; i < monitors.length; i++) {
      if (targetScreen && monitors[i].name === targetScreen.name) return monitors[i]
    }
    return null
  }

  // Wait for fullscreen geometry as well as scale so no smaller opening frame
  // is stretched across the output. Fractional scale uses units of 1/120;
  // compare in those units to tolerate floating point rounding.
  readonly property bool contentReady: shown && backingWindowVisible && !!targetScreen
    && width === targetScreen.width && height === targetScreen.height
    && (!hyprlandActive || (!!targetMonitor
      && Math.round(devicePixelRatio * 120) === Math.round(targetMonitor.scale * 120)))
  property bool contentRevealed: false

  onContentReadyChanged: {
    contentRevealed = false
    // Resize and scale notifications arrive while Qt is still updating the
    // window. Reveal on the next turn, once its content layout has caught up.
    if (contentReady) Qt.callLater(function() {
      if (window.contentReady) window.contentRevealed = true
    })
  }

  function focusedScreen() {
    if (hyprlandActive) {
      var monitor = Hyprland.focusedMonitor
      var name = monitor ? String(monitor.name || "") : ""
      for (var i = 0; i < Quickshell.screens.length; i++) {
        if (Quickshell.screens[i].name === name) return Quickshell.screens[i]
      }
    } else if (Commons.Niri.focusedOutput) {
      for (var j = 0; j < Quickshell.screens.length; j++) {
        if (Quickshell.screens[j].name === Commons.Niri.focusedOutput) return Quickshell.screens[j]
      }
    }
    return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
  }

  // Live monitor scaling does not emit a Hyprland monitor event, so its cached
  // scale can lag behind Qt. Refresh on opening and on scale changes while open.
  onShownChanged: {
    targetScreen = shown ? focusedScreen() : null
    if (shown && hyprlandActive) Hyprland.refreshMonitors()
  }
  onDevicePixelRatioChanged: if (shown && hyprlandActive) Hyprland.refreshMonitors()

  Connections {
    target: Quickshell
    function onScreensChanged() {
      if (window.shown && Quickshell.screens.indexOf(window.targetScreen) < 0) {
        window.targetScreen = null
        // Let the removed output finish closing its old window before mapping
        // a replacement, rather than recreating it during Qt's teardown.
        Qt.callLater(function() {
          if (window.shown && !window.targetScreen) window.targetScreen = window.focusedScreen()
        })
      }
    }
  }

  visible: shown && !!targetScreen && (!hyprlandActive || !!targetMonitor)
  screen: targetScreen
  anchors { top: true; left: true; bottom: true; right: true }
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: shownLayer
  WlrLayershell.keyboardFocus: shownKeyboardFocus

  // Opacity preserves keyboard handling while the scale arrives, including
  // search keystrokes and Escape pressed immediately after opening.
  Binding {
    target: window.contentItem
    property: "opacity"
    value: window.contentRevealed ? 1 : 0
  }

  // Right-to-left languages read the overlay mirrored.
  Binding {
    target: window.contentItem
    property: "LayoutMirroring.enabled"
    value: Commons.I18n.rightToLeft
  }
  Binding {
    target: window.contentItem
    property: "LayoutMirroring.childrenInherit"
    value: true
  }
}
