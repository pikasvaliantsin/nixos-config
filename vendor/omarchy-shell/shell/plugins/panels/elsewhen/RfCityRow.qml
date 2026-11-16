import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// A made-up city in the world clock: one real hour is one 24-hour game day.
// It has no timezone or coordinates, so it is a plain row rather than a
// probe-backed CityRow. The bell sets a one-shot notification for the next
// occurrence of an in-game HH:MM.
Rectangle {
  id: row

  property var panel

  readonly property color foreground: panel.foreground
  readonly property color dim: panel.dim
  readonly property color fainter: panel.fainter
  readonly property string fontFamily: panel.fontFamily
  readonly property var parts: Model.rfGameParts(panel.nowMs, panel.rfOffsetMs)
  readonly property string alarm: panel.rfAlarm
  property bool editing: false
  readonly property bool invalidAlarm: row.editing && alarmField.text !== ""
    && Model.rfAlarmMinutes(alarmField.text) < 0

  width: parent.width
  implicitHeight: Style.space(58)
  radius: Style.cornerRadius
  color: Model.mix(Commons.Color.popups.background, foreground, hovered ? 0.12 : 0.08)

  HoverHandler { id: hovered }

  Text {
    id: nameText
    anchors.left: parent.left
    anchors.leftMargin: Style.spacing.rowPaddingX
    anchors.verticalCenter: parent.verticalCenter
    textFormat: Text.PlainText
    text: Commons.I18n.t("elsewhen.rfCity", "RF City")
    color: row.foreground
    font.family: row.fontFamily
    font.pixelSize: Style.font.subtitle
    font.weight: Font.DemiBold
    elide: Text.ElideRight
  }

  Row {
    anchors.right: parent.right
    anchors.rightMargin: Style.spacing.rowPaddingX
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.spacing.sm

    Text {
      id: gameTime
      visible: !row.editing
      textFormat: Text.PlainText
      // Game time is always 24-hour, regardless of the shell's clock setting.
      text: row.parts.time
      color: row.foreground
      font.family: row.fontFamily
      font.pixelSize: Style.font.heading
      font.weight: Font.DemiBold
      anchors.verticalCenter: parent.verticalCenter
    }

    TextField {
      id: alarmField
      visible: row.editing
      width: Style.space(76)
      verticalPadding: Style.space(3)
      foreground: row.invalidAlarm ? Commons.Color.urgent : Commons.Color.menu.text
      font.family: row.fontFamily
      font.pixelSize: Style.font.body
      placeholderText: "HH:MM"
      onAccepted: row.commit()
      onVisibleChanged: if (visible) {
        text = row.alarm
        cursorPosition = text.length
        Qt.callLater(function() { if (alarmField.visible) alarmField.forceActiveFocus() })
      }
      Keys.onEscapePressed: row.editing = false
    }

    PanelActionButton {
      iconText: "󰂚"
      tooltipText: row.alarm === ""
        ? Commons.I18n.t("elsewhen.rfAlarmSet", "Set game-time alarm")
        : Commons.I18n.t("elsewhen.rfAlarmAt", "Alarm at %1").arg(row.alarm)
      foreground: row.alarm === "" ? row.dim : Commons.Color.accent
      hoverColor: row.foreground
      fontFamily: row.fontFamily
      fontSize: Style.font.bodySmall
      onClicked: {
        if (row.editing) row.editing = false
        else row.beginEdit()
      }
    }
  }

  function beginEdit() {
    row.editing = true
  }

  function commit() {
    if (row.panel.setRfAlarm(alarmField.text)) row.editing = false
  }
}
