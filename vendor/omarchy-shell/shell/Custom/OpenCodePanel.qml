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

  function resetLabel(value) {
    if (!value) return ""
    var d = new Date(value)
    if (isNaN(d.getTime())) return ""
    return "resets " + Qt.formatDateTime(d, "dd MMM HH:mm")
  }

  function number(value) {
    return Commons.I18n.formatNumber(Number(value) || 0)
  }

  function launch() {
    Quickshell.execDetached(["ghostty", "-e", "opencode"])
    if (root.owner && typeof root.owner.close === "function") root.owner.close()
  }

  contentWidth: root.fittedContentWidth(Style.space(330))
  contentHeight: root.fittedContentHeight(column.implicitHeight)

  onOpenChanged: if (open) OpenCodeUsage.refresh()

  Column {
    id: column
    width: parent.width
    spacing: Style.space(10)

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
      text: "Today: " + root.number(OpenCodeUsage.todayTokens) + " tokens · "
        + root.number(OpenCodeUsage.todayPrompts) + " prompts · "
        + root.number(OpenCodeUsage.todaySessions) + " sessions"
      color: Commons.Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.WordWrap
    }
    Text {
      width: parent.width
      text: "All time: " + root.number(OpenCodeUsage.totalPrompts) + " prompts · "
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
