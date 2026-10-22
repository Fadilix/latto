pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// NetworkManager state via nmcli: the Wi-Fi radio, active connections, and
// (while a view watches) nearby Wi-Fi networks to connect to.
QtObject {
    id: root

    property bool wifiEnabled: false
    // [{ name, type }], e.g. { name: "Home", type: "802-11-wireless" }
    property var connections: []

    // Nearby networks, strongest first, one row per name:
    // [{ ssid, signal, security, secure, enterprise, active, known }]
    property var networks: []
    property bool scanning: false
    // The network being connected to, and the last failure for it.
    property string connecting: ""
    property string failedSsid: ""
    property string error: ""

    property int watchers: 0

    function watch() {
        watchers++;
        scan(true);
    }

    function unwatch() {
        watchers = Math.max(0, watchers - 1);
    }

    function setWifi(on) {
        wifiEnabled = on;
        Quickshell.execDetached(["nmcli", "radio", "wifi", on ? "on" : "off"]);
        Activities.show("wifi", 70, { label: on ? "Wi-Fi on" : "Wi-Fi off", value: -1, off: !on }, 1800);
        recheck.restart();
        if (on && watchers > 0)
            rescanLater.restart();
    }

    function toggleWifi() {
        setWifi(!wifiEnabled);
    }

    // --- scanning ----------------------------------------------------------

    // Lists what NetworkManager already knows at once; with `fresh`, also
    // asks for a new scan and lists again when it has had time to finish.
    function scan(fresh) {
        if (!lister.running)
            lister.running = true;
        if (fresh && wifiEnabled && !rescanner.running) {
            scanning = true;
            rescanner.running = true;
        }
    }

    // Splits an nmcli terse line on unescaped colons ("\:" is a literal one).
    function splitTerse(line) {
        const fields = [];
        let current = "";
        for (let i = 0; i < line.length; i++) {
            const c = line[i];
            if (c === "\\" && i + 1 < line.length) {
                current += line[++i];
            } else if (c === ":") {
                fields.push(current);
                current = "";
            } else {
                current += c;
            }
        }
        fields.push(current);
        return fields;
    }

    // Output: "K:<saved profile name>" lines, then "N:<in-use>:<ssid>:<signal>:<security>".
    function ingestNetworks(text) {
        const known = {};
        const bySsid = {};
        for (const line of text.split("\n")) {
            if (line.startsWith("K:")) {
                known[line.slice(2)] = true;
                continue;
            }
            if (!line.startsWith("N:"))
                continue;
            const f = splitTerse(line.slice(2));
            const ssid = f[1] || "";
            if (ssid === "")
                continue;    // hidden networks
            const security = (f[3] || "").trim();
            const entry = {
                ssid: ssid,
                signal: parseInt(f[2]) || 0,
                security: security,
                secure: security !== "" && security !== "--",
                enterprise: security.includes("802.1X"),
                active: f[0] === "*",
                known: false
            };
            const existing = bySsid[ssid];
            if (!existing || entry.active || (!existing.active && entry.signal > existing.signal))
                bySsid[ssid] = entry;
        }
        networks = Object.values(bySsid)
            .map(network => Object.assign(network, { known: !!known[network.ssid] }))
            .sort((a, b) => (b.active - a.active) || (b.signal - a.signal));
    }

    property Process lister: Process {
        command: ["sh", "-c", "nmcli -t -f NAME,TYPE connection show 2>/dev/null | sed -n 's/^\\(.*\\):802-11-wireless$/K:\\1/p'; nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan no 2>/dev/null | sed 's/^/N:/'"]
        stdout: StdioCollector {
            onStreamFinished: root.ingestNetworks(this.text)
        }
    }

    property Process rescanner: Process {
        command: ["nmcli", "device", "wifi", "rescan"]
        onExited: rescanLater.restart()
    }

    // A rescan returns before results are in; list again shortly after.
    property Timer rescanLater: Timer {
        interval: 2500
        onTriggered: {
            root.scanning = false;
            root.scan(false);
        }
    }

    // Keeps the list fresh while it is open.
    property Timer listTimer: Timer {
        interval: 10000
        repeat: true
        running: root.watchers > 0 && root.wifiEnabled
        onTriggered: root.scan(true)
    }

    // --- connecting --------------------------------------------------------

    // Saved and open networks connect straight away. A new secured network
    // needs `password`, which goes to NetworkManager on stdin (never on a
    // command line, where other programs could read it) for a new profile;
    // a failed attempt removes that profile again.
    function connect(network, password) {
        if (connecting !== "")
            return;
        connecting = network.ssid;
        failedSsid = "";
        error = "";

        let script;
        if (network.known)
            script = "nmcli connection up id \"$1\"";
        else if (!network.secure)
            script = "nmcli device wifi connect \"$1\"";
        else
            script = "nmcli connection add type wifi con-name \"$1\" ssid \"$1\" wifi-sec.key-mgmt \"$2\" >/dev/null"
                + " && printf '802-11-wireless-security.psk:%s\\n' \"$LATTO_WIFI_PSK\""
                + " | nmcli connection up id \"$1\" passwd-file /dev/stdin"
                + " || { status=$?; nmcli connection delete id \"$1\" >/dev/null 2>&1; exit $status; }";

        const keyManagement = network.security.includes("WPA3") ? "sae" : "wpa-psk";
        connector.environment = { LATTO_WIFI_PSK: password || "" };
        connector.command = ["sh", "-c", script, "sh", network.ssid, keyManagement];
        connector.running = true;
    }

    function disconnect(network) {
        Quickshell.execDetached(["nmcli", "connection", "down", "id", network.ssid]);
        recheck.restart();
        relistLater.restart();
    }

    property Process connector: Process {
        stderr: StdioCollector {
            id: connectErrors
        }
        onExited: code => {
            const ssid = root.connecting;
            root.connecting = "";
            if (code === 0) {
                Activities.show("wifi", 70, { label: "Connected to " + ssid, value: -1, off: false }, 2500);
            } else {
                root.failedSsid = ssid;
                const message = connectErrors.text.trim().split("\n").pop() || "";
                root.error = /secrets|password|802-1x/i.test(message) ? "Wrong password" : "Couldn't connect";
            }
            // Drop the password from memory.
            root.connector.environment = {};
            root.probe.running = true;
            root.relistLater.restart();
        }
    }

    property Timer relistLater: Timer {
        interval: 1500
        onTriggered: root.scan(false)
    }

    // --- radio and active connections ----------------------------------

    // First line: the Wi-Fi radio ("enabled"/"disabled"); then one line per
    // active connection.
    property Process probe: Process {
        command: ["sh", "-c", "nmcli radio wifi 2>/dev/null; nmcli -t -f NAME,TYPE connection show --active 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n");
                root.wifiEnabled = lines[0] === "enabled";
                root.connections = lines.slice(1)
                    .filter(line => line.length > 0)
                    .map(line => {
                        const parts = line.split(":");
                        return { name: parts[0], type: parts[1] || "" };
                    });
            }
        }
    }

    // Connections take a moment to come and go after the radio switches.
    property Timer recheck: Timer {
        interval: 2500
        onTriggered: root.probe.running = true
    }

    property Timer timer: Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.probe.running = true
    }
}
