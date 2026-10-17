.pragma library

// Pure rules for the network and Bluetooth panels. Tested by tests/qml/tst_netlogic.qml.

function formatRate(bytesPerSec) {
    var v = Number(bytesPerSec)
    if (!(v > 0))
        return "0 B/s"
    if (v < 1000)
        return Math.round(v) + " B/s"
    if (v < 1e6)
        return Math.round(v / 1000) + " KB/s"
    if (v < 1e9)
        return (v / 1e6).toFixed(1) + " MB/s"
    return (v / 1e9).toFixed(1) + " GB/s"
}

// Signal strength 0..1 -> 0..4 bars (any signal shows at least one).
function signalBars(strength) {
    var s = Number(strength)
    if (!(s > 0))
        return 0
    return Math.min(4, Math.max(1, Math.ceil(s * 4)))
}

// The line of /proc/net/dev for `iface`: receive bytes are field 0 after the colon, transmit bytes field 8.
function parseNetDev(text, iface) {
    if (!text || !iface)
        return null
    var lines = String(text).split("\n")
    for (var i = 0; i < lines.length; i++) {
        var colon = lines[i].indexOf(":")
        if (colon < 0 || lines[i].slice(0, colon).trim() !== iface)
            continue
        var f = lines[i].slice(colon + 1).trim().split(/\s+/)
        var rx = Number(f[0]), tx = Number(f[8])
        return (isNaN(rx) || isNaN(tx)) ? null : { rx: rx, tx: tx }
    }
    return null
}

// First IPv4 address in the output of `ip -4 -o addr show`.
function ipv4FromAddr(text) {
    var m = /\binet (\d{1,3}(?:\.\d{1,3}){3})/.exec(text || "")
    return m ? m[1] : ""
}

// devices: [{ wired, managed, connected }]. Docker bridges and veths are not managed by NetworkManager and never win.
function primaryIndex(devices) {
    if (!devices)
        return -1
    var rules = [
        function (d) { return d.managed && d.connected && d.wired },
        function (d) { return d.managed && d.connected && !d.wired },
        function (d) { return d.managed && d.wired },
        function (d) { return d.managed && !d.wired }
    ]
    for (var r = 0; r < rules.length; r++) {
        for (var i = 0; i < devices.length; i++) {
            if (rules[r](devices[i]))
                return i
        }
    }
    return -1
}

// Font Awesome / Material Design glyphs from the Symbols Nerd Font for a BlueZ device class (the "icon" property).
function btGlyph(iconName) {
    var n = String(iconName || "").toLowerCase()
    if (n.indexOf("headphone") >= 0 || n.indexOf("headset") >= 0)
        return ""
    if (n.indexOf("keyboard") >= 0)
        return ""
    if (n.indexOf("mouse") >= 0)
        return "󰍽"
    if (n.indexOf("phone") >= 0)
        return ""
    if (n.indexOf("speaker") >= 0 || n.indexOf("audio") >= 0)
        return ""
    if (n.indexOf("gaming") >= 0 || n.indexOf("joystick") >= 0)
        return ""
    return ""
}

// d: { state: "connecting"|"disconnecting"|..., pairing, paired, connected, battery (percent or -1) }
function btSub(d) {
    if (d.state === "connecting")
        return "Connecting…"
    if (d.state === "disconnecting")
        return "Disconnecting…"
    if (d.pairing)
        return "Pairing…"
    if (d.connected)
        return d.battery >= 0 ? "Connected · " + d.battery + "%" : "Connected"
    return d.paired ? "Paired" : "Not paired"
}

// Connected first, then by name (case-insensitive). Does not modify the input.
function sortBtDevices(list) {
    var a = []
    for (var i = 0; i < (list ? list.length : 0); i++)
        a.push({ d: list[i], i: i })
    a.sort(function (x, y) {
        var cx = x.d.connected ? 0 : 1, cy = y.d.connected ? 0 : 1
        if (cx !== cy)
            return cx - cy
        var nx = String(x.d.name || "").toLowerCase(), ny = String(y.d.name || "").toLowerCase()
        return nx < ny ? -1 : nx > ny ? 1 : x.i - y.i
    })
    return a.map(function (e) { return e.d })
}

// BlueZ reports the battery as 0..1 or 0..100 depending on the source: -1 when unknown.
function batteryPercent(value) {
    var v = Number(value)
    if (value === undefined || value === null || isNaN(v) || v < 0)
        return -1
    return Math.min(100, Math.round(v <= 1 ? v * 100 : v))
}

function countConnected(list) {
    var n = 0
    for (var i = 0; i < (list ? list.length : 0); i++) {
        if (list[i].connected)
            n++
    }
    return n
}
