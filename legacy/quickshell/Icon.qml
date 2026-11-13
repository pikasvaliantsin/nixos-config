import QtQuick
import Quickshell

// Иконка из Font Awesome 6 Free (solid), красится цветом темы.
Item {
    id: root

    property string glyph: ""
    property int size: 15
    property color color: Theme.fg

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    Text {
        id: label
        anchors.centerIn: parent
        text: root.glyph
        color: root.color
        font.family: "Font Awesome 6 Free"
        font.weight: Font.Bold
        font.pixelSize: root.size
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
    }
}
