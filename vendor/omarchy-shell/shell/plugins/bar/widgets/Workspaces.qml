import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "omarchy.workspaces"

  readonly property string outputName: root.QsWindow.window && root.QsWindow.window.screen
    ? root.QsWindow.window.screen.name : Niri.focusedOutput
  readonly property var displayWorkspaces: Niri.workspaceItems(outputName)

  // niri's focus-workspace takes an index or name, not the internal
  // workspace id (which is a global, non-contiguous number).
  function focusWorkspace(reference) { Niri.focusWorkspace(reference) }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.displayWorkspaces.length
    columnSpacing: root.vertical ? 0 : Style.space(2)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.displayWorkspaces

      WidgetButton {
        required property var modelData

        readonly property var workspace: modelData
        readonly property bool occupied: workspace !== null && workspace.occupied
        readonly property bool focused: workspace !== null && workspace.is_focused

        bar: root.bar
        active: focused
        activeColor: Commons.Color.accent
        labelHorizontalOffset: -Style.space(1)
        consumeWheel: true
        text: String(workspace.name || workspace.idx)
        opacity: occupied || focused ? 1 : 0.5
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Style.space(22)
        fixedHeight: root.barSize
        onPressed: function() { root.focusWorkspace(workspace.name || workspace.idx) }
        onWheelMoved: function(delta) {
          if (root.bar && typeof root.bar.scrollWorkspaces === "function")
            root.bar.scrollWorkspaces(delta)
        }

        Rectangle {
          z: -1
          anchors.centerIn: parent
          width: Style.space(18)
          height: Style.space(18)
          radius: Style.space(6)
          color: focused
            ? Util.alpha(Commons.Color.accent, 0.18)
            : (hover.hovered ? Util.alpha(Commons.Color.foreground, 0.08) : "transparent")
          border.width: focused ? Math.max(1, Style.space(1)) : 0
          border.color: Util.alpha(Commons.Color.accent, 0.70)

          Behavior on color { ColorAnimation { duration: Style.duration(140) } }
          Behavior on border.color { ColorAnimation { duration: Style.duration(140) } }
        }

        HoverHandler { id: hover }
      }
    }
  }
}
