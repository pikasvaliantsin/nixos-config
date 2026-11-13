import QtQuick
import Quickshell

ShellRoot {
    Variants {
        model: Quickshell.screens
        delegate: Bar {
            modelData: modelData
        }
    }

    NotificationPanel {}
}
