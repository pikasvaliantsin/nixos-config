pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking

// Сеть через нативный NetworkManager-бэкенд Quickshell.
Singleton {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wifiDevice: {
        for (const d of devices) if (d.type === DeviceType.Wifi) return d;
        return null;
    }
    readonly property var wiredDevice: {
        for (const d of devices) if (d.type === DeviceType.Wired) return d;
        return null;
    }

    readonly property bool available: wifiDevice !== null || wiredDevice !== null
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifi: (wifiDevice !== null) && wifiDevice.connected
    readonly property bool wired: (wiredDevice !== null) && wiredDevice.connected
    readonly property bool connected: root.wifi || root.wired

    readonly property var activeNetwork: {
        if (!root.connected) return null;
        const dev = root.wifi ? root.wifiDevice : root.wiredDevice;
        if (!dev) return null;
        for (const n of dev.networks.values) if (n.connected) return n;
        return null;
    }

    readonly property string name: root.activeNetwork ? root.activeNetwork.name : ""
    readonly property int strength: {
        if (!root.wifi || !root.activeNetwork) return 0;
        const s = root.activeNetwork.signalStrength;
        return s === undefined ? 0 : Math.round(s * 100);
    }

    readonly property var wifiNetworks: {
        if (!root.wifiDevice) return [];
        const arr = root.wifiDevice.networks.values.slice();
        arr.sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            if (a.known !== b.known) return a.known ? -1 : 1;
            const sa = a.signalStrength === undefined ? 0 : a.signalStrength;
            const sb = b.signalStrength === undefined ? 0 : b.signalStrength;
            return sb - sa;
        });
        return arr;
    }

    function setWifiEnabled(value) {
        Networking.wifiEnabled = value;
    }

    function scan(value) {
        if (root.wifiDevice) root.wifiDevice.scannerEnabled = value;
    }

    function connectNetwork(network, psk) {
        if (!network) return;
        if (psk && psk.length > 0) network.connectWithPsk(psk);
        else network.connect();
    }

    function disconnectNetwork(network) {
        if (network) network.disconnect();
    }

    function isSecure(network) {
        return network && network.security !== WifiSecurityType.Open;
    }

    function securityLabel(network) {
        if (!network) return "";
        return WifiSecurityType.toString(network.security);
    }
}
