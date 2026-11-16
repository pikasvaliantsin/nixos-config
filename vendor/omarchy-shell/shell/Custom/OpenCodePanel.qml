import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Custom
import qs.Ui

// Compact OpenCode-only panel: plan limits, local usage, launch button.
KeyboardPanel {
  id: root

  focusTarget: escapeCatcher

  property real nowMs: Date.now()


  function resetLabel(value) {
    if (!value) return ""
    var d = new Date(value)
    if (isNaN(d.getTime())) return ""

    var absolute = Qt.formatDateTime(d, "dd MMM HH:mm")
    var ms = d.getTime() - root.nowMs
    if (ms <= 0) return "resets now · " + absolute

    var minutes = Math.floor(ms / 60000)
    if (minutes < 1) return "resets in <1m · " + absolute
    if (minutes < 60) return "resets in " + minutes + "m · " + absolute

    var hours = Math.floor(minutes / 60)
    var remMinutes = minutes % 60
    if (hours < 24) {
      return "resets in " + hours + "h"
        + (remMinutes > 0 ? " " + remMinutes + "m" : "")
        + " · " + absolute
    }

    var days = Math.floor(hours / 24)
    var remHours = hours % 24
    return "resets in " + days + "d"
      + (remHours > 0 ? " " + remHours + "h" : "")
      + " · " + absolute
  }

  function number(value) {
    return Commons.I18n.formatNumber(Number(value) || 0)
  }

  // Compact token counts: 215K, 2M, 2B. Counts below a thousand stay plain.
  function compact(value) {
    var n = Number(value) || 0
    var units = [
      { limit: 1e9, suffix: "B" },
      { limit: 1e6, suffix: "M" },
      { limit: 1e3, suffix: "K" }
    ]
    for (var i = 0; i < units.length; i++) {
      if (n >= units[i].limit) {
        var scaled = n / units[i].limit
        var text = scaled >= 100
          ? String(Math.round(scaled))
          : String(Math.round(scaled * 10) / 10)
        return text.replace(/\.0$/, "") + units[i].suffix
      }
    }
    return String(Math.round(n))
  }

  function tokens(value) {
    return root.compact(value) + " tokens"
  }

  function launch() {
    Util.launchScoped(["ghostty", "-e", "opencode"])
    if (root.owner && typeof root.owner.close === "function") root.owner.close()
  }

  contentWidth: root.fittedContentWidth(Style.space(330))
  contentHeight: root.fittedContentHeight(column.implicitHeight)

  onOpenChanged: {
    if (open) {
      root.nowMs = Date.now()
      OpenCodeUsage.refresh()
    }
  }

  Item {
    id: escapeCatcher
    anchors.fill: parent
    focus: true
    Keys.onEscapePressed: function(event) {
      root.close()
      event.accepted = true
    }

    Column {
      id: column
      width: parent.width
      spacing: Style.space(10)

      Timer {
        interval: 30000
        running: root.open
        repeat: true
        onTriggered: root.nowMs = Date.now()
      }

      RowLayout {
        width: parent.width
        spacing: Style.space(8)

        Text {
          text: "OpenCode"
          color: Commons.Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.heading
          font.bold: true
        }
        Text {
          visible: OpenCodeUsage.tier !== ""
          text: OpenCodeUsage.tier
          color: Commons.Color.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }
        Item { Layout.fillWidth: true }
        Text {
          text: OpenCodeUsage.loading ? "refreshing…" : "live"
          color: Commons.Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }

      PanelSeparator { foreground: Commons.Color.foreground }

      PanelSectionHeader {
        text: OpenCodeUsage.limits.length > 0 ? "LIMITS" : "NO PLAN LIMITS"
        width: parent.width
      }

      Repeater {
        model: OpenCodeUsage.limits

        delegate: Column {
          required property var modelData
          width: column.width
          spacing: Style.space(3)

          RowLayout {
            width: parent.width
            Text {
              text: modelData.label || ""
              color: Commons.Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }
            Item { Layout.fillWidth: true }
            Text {
              text: Math.round((Number(modelData.percent) || 0) * 100) + "%"
              color: Commons.Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }
          }

          Rectangle {
            width: parent.width
            height: Math.max(4, Style.space(4))
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.10)

            Rectangle {
              width: parent.width * Math.max(0, Math.min(1, Number(modelData.percent) || 0))
              height: parent.height
              radius: parent.radius
              color: Commons.Color.accent
            }
          }

          Text {
            width: parent.width
            text: root.resetLabel(modelData.resetsAt)
            visible: text !== ""
            color: Commons.Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }
      }

      Text {
        visible: OpenCodeUsage.limits.length === 0
        width: parent.width
        text: OpenCodeUsage.usageStatus || OpenCodeUsage.authHelp || "Local OpenCode usage only"
        color: Commons.Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
      }

      PanelSeparator { foreground: Commons.Color.foreground }

      Text {
        width: parent.width
        text: "Today: " + root.tokens(OpenCodeUsage.todayTokens) + " · "
          + root.number(OpenCodeUsage.todayPrompts) + " prompts · "
          + root.number(OpenCodeUsage.todaySessions) + " sessions"
        color: Commons.Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
      }
      Text {
        width: parent.width
        text: "All time: " + root.tokens(OpenCodeUsage.totalTokens) + " · "
          + root.number(OpenCodeUsage.totalPrompts) + " prompts · "
          + root.number(OpenCodeUsage.totalSessions) + " sessions"
        color: Commons.Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }

      RowLayout {
        width: parent.width
        spacing: Style.space(6)
        Button {
          Layout.fillWidth: true
          leftAlign: true
          text: "Open OpenCode"
          iconText: "󰚩"
          onClicked: root.launch()
        }
        Button {
          text: "Refresh"
          iconText: "󰑓"
          onClicked: OpenCodeUsage.refresh()
        }
      }
    }
  }
}
