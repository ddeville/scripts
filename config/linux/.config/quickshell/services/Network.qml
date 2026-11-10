pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking as Net

Scope {
    id: root

    readonly property Net.WifiDevice wifiDevice: {
        // Quickshell 0.3.2 exposes incomplete ObjectModel metadata to qmllint.
        const wifiDevices = Net.Networking.devices.values.filter(device => device.type === Net.DeviceType.Wifi); // qmllint disable missing-property
        return wifiDevices.find(device => device.connected || device.state === Net.ConnectionState.Connecting) ?? wifiDevices[0] ?? null;
    }
    readonly property var wiredDevices: Net.Networking.devices.values.filter(device => device.type === Net.DeviceType.Wired) // qmllint disable missing-property
    readonly property Net.NetworkDevice wiredConnection: wiredDevices.find(device => device.connected) ?? null
    readonly property Net.WifiNetwork current: wifiDevice ? wifiDevice.networks.values.find(network => network.connected) ?? null : null // qmllint disable missing-property
    readonly property bool busy: wifiDevice !== null && (wifiDevice.state === Net.ConnectionState.Connecting || wifiDevice.state === Net.ConnectionState.Disconnecting)
    readonly property string message: error || (busy ? Net.ConnectionState.toString(wifiDevice.state) + "…" : "")
    property string error: ""
    property Net.WifiNetwork pendingNetwork: null
    property var addresses: ({})

    onCurrentChanged: {
        if (current) {
            error = "";
            pendingNetwork = null;
        }
        refreshAddresses();
    }
    onWiredConnectionChanged: refreshAddresses()

    function refreshAddresses() {
        if (!addressQuery.running)
            addressQuery.running = true;
    }

    function connectNetwork(network: Net.WifiNetwork) {
        if (!network || busy || network.connected)
            return;
        error = "";
        pendingNetwork = network;
        network.connect();
    }

    function disconnectNetwork() {
        error = "";
        pendingNetwork = null;
        if (wifiDevice)
            wifiDevice.disconnect();
    }

    function setEnabled(enabled: bool) {
        error = "";
        pendingNetwork = null;
        Net.Networking.wifiEnabled = enabled;
    }

    Connections {
        target: root.pendingNetwork

        function onConnectionFailed(reason) {
            root.error = reason === Net.ConnectionFailReason.NoSecrets
                ? "Credentials required. Open Network settings to connect."
                : Net.ConnectionFailReason.toString(reason);
        }
    }

    Process {
        id: addressQuery

        // Quickshell exposes hardware addresses, but not assigned IP addresses.
        command: ["ip", "-j", "-4", "address", "show", "scope", "global"]
        onExited: (code, status) => {
            const addresses = {};
            if (code === 0 && status === 0) {
                for (const device of JSON.parse(addressOutput.text))
                    addresses[device.ifname] = device.addr_info.map(address => address.local + "/" + address.prefixlen).join(" · ");
            }
            root.addresses = addresses;
        }

        stdout: StdioCollector {
            id: addressOutput
        }
    }
}
