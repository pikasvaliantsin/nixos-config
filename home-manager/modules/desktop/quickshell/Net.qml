pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// Сеть через нативный NetworkManager-бэкенд Quickshell + VPN через nmcli.
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

    // --- VPN: NetworkManager-профили типа wireguard/vpn -------------------
    property var vpn: []
    readonly property bool vpnActive: root.vpn.some(v => v.active)
    readonly property var vpnPrimary: root.vpn.length === 1 ? root.vpn[0] : null

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

    function toggleVpn(name, active) {
        if (!name) return;
        vpnAction.command = ["nmcli", "connection", active ? "down" : "up", name];
        vpnAction.running = true;
    }

    function refreshVpn() {
        if (!vpnProc.running) vpnProc.running = true;
    }

    Process {
        id: vpnProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE,ACTIVE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    if (!line) continue;
                    const p = line.split(":");
                    if (p.length < 3) continue;
                    const type = p[p.length - 2];
                    const active = p[p.length - 1] === "yes";
                    const name = p.slice(0, p.length - 2).join(":");
                    if (type !== "wireguard" && type !== "vpn") continue;
                    out.push({ name: name, active: active });
                }
                root.vpn = out;
            }
        }
        onExited: vpnTimer.restart()
    }

    Timer {
        id: vpnTimer
        interval: 5000
        repeat: false
        onTriggered: vpnProc.running = true
    }

    Process {
        id: vpnAction
        onExited: {
            running = false;
            root.refreshVpn();
        }
    }

    Component.onCompleted: vpnProc.running = true
}
