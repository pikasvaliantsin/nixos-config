//@ pragma UseQApplication
import QtQuick
import Quickshell

ShellRoot {
    Variants {
        model: Quickshell.screens
        delegate: Bar { modelData: modelData }
    }

    Variants {
        model: Quickshell.screens
        delegate: DismissLayer {}
    }
    Variants {
        model: Quickshell.screens
        delegate: NotificationPanel {}
    }
    Variants {
        model: Quickshell.screens
        delegate: ClipboardPanel {}
    }
    Variants {
        model: Quickshell.screens
        delegate: NetworkPanel {}
    }
    Variants {
        model: Quickshell.screens
        delegate: BluetoothPanel {}
    }
}
