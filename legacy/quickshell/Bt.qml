pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Bluetooth через нативный BlueZ-бэкенд Quickshell.
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: !!adapter
    readonly property bool powered: adapter ? adapter.enabled : false
    readonly property bool discovering: adapter ? adapter.discovering : false
    readonly property var devices: adapter ? adapter.devices.values : []

    readonly property var sortedDevices: {
        const arr = root.devices.slice();
        arr.sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            if (a.paired !== b.paired) return a.paired ? -1 : 1;
            return String(a.name).localeCompare(String(b.name));
        });
        return arr;
    }

    readonly property int connectedCount: root.devices.filter(d => d.connected).length

    function setPowered(value) {
        if (root.adapter) root.adapter.enabled = value;
    }

    function setDiscovering(value) {
        if (root.adapter) root.adapter.discovering = value;
    }

    function toggleDevice(device) {
        if (!device) return;
        if (device.connected) device.disconnect();
        else if (device.paired) device.connect();
        else device.pair();
    }
}
