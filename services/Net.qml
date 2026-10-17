pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick

import "../bar/trayLogic.js" as Labels
import "../dropdown/netlogic.js" as Logic

// The network connection for the bar: one primary connection (Ethernet or Wi-Fi), its rates and address, and the Wi-Fi
// networks in range. Real data comes from Quickshell.Networking (NetworkManager); `mock` feeds the UI fake data for
// visual checks (this machine has no Wi-Fi adapter). While dryRun is true no action changes the system.
// Spec: docs/superpowers/specs/2026-10-13-network-and-bluetooth-design.md
Singleton {
    id: root

    readonly property bool active: true

    property bool mock: false
    property string mockMode: "wifi"        // "eth" | "wifi" | "off"
    property bool dryRun: false     // released by the user on 2026-10-13; tests use `mock`, never the real connection
    property string last: ""                // the last action that was run or would have been

    // ---- devices ----

    // NetworkManager-managed devices only: the Docker bridges and veths of this machine are not managed and never win.
    readonly property var all: Networking.devices.values
    readonly property int primary: Logic.primaryIndex(all.map(d => ({
        wired: d.type === DeviceType.Wired,
        managed: d.nmManaged,
        connected: d.connected
    })))
    readonly property var device: primary >= 0 ? all[primary] : null
    readonly property var wifiDevice: all.find(d => d.type === DeviceType.Wifi && d.nmManaged) ?? null

    readonly property string mode: mock ? mockMode
        : device === null || !device.connected ? "off"
        : device.type === DeviceType.Wired ? "eth" : "wifi"
    readonly property bool connected: mode !== "off"
    readonly property bool hasWifi: mock ? mockMode === "wifi" : wifiDevice !== null
    readonly property bool wifiEnabled: mock ? true : Networking.wifiEnabled
    readonly property string iface: mock ? "enp5s0" : (device?.name ?? "")

    // ---- what the panel shows ----

    readonly property var currentWifi: wifi.find(n => n.connected) ?? null

    readonly property string title: {
        if (mode === "wifi")
            return currentWifi ? currentWifi.name : "Wi-Fi"
        if (mode === "eth" || (mode === "off" && (mock || device?.type === DeviceType.Wired)))
            return "Ethernet"
        return "Network"
    }

    readonly property string subtitle: {
        if (mock && mode === "eth")
            return "enp5s0 · 1 Gbit/s"
        if (mock && mode === "off")
            return "enp5s0 · cable unplugged"
        if (mode === "wifi")
            return currentWifi ? "Connected · " + Math.round(currentWifi.strength * 100) + "% signal" : "Not connected"
        if (device === null)
            return "No network device"
        if (device.type === DeviceType.Wired) {
            const speed = device.linkSpeed
            const rate = speed >= 1000 ? (speed / 1000) + " Gbit/s" : speed > 0 ? speed + " Mbit/s" : ""
            if (mode === "eth")
                return device.name + (rate ? " · " + rate : "")
            return device.name + (device.hasLink ? " · disconnected" : " · cable unplugged")
        }
        return device.name
    }

    // Wi-Fi networks in range: [{ id, name, strength, secure, connected, known, busy }], connected first, then by signal.
    property var mockWifi: [
        { id: "TK-421-5G", name: "TK-421-5G", strength: 1, secure: true, connected: true, known: true, busy: false },
        { id: "Imperial-Guest", name: "Imperial-Guest", strength: 0.75, secure: false, connected: false, known: false, busy: false },
        { id: "DEATH-STAR-IOT", name: "DEATH-STAR-IOT", strength: 0.5, secure: true, connected: false, known: false, busy: false },
        { id: "Vizinho_2G", name: "Vizinho_2G", strength: 0.25, secure: true, connected: false, known: false, busy: false },
        { id: "evil", name: "Evil ‮esrever‬\nname \u0007bell", strength: 0.6, secure: true, connected: false, known: false, busy: false }
    ]

    readonly property var wifi: {
        let raw = []
        if (mock) {
            raw = mockWifi.map(n => Object.assign({}, n))
        } else {
            const nets = wifiDevice?.networks.values ?? []
            raw = nets.map(n => ({
                id: n.name,
                name: n.name,
                strength: n.signalStrength,
                secure: n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe,
                connected: n.connected,
                known: n.known,
                busy: n.state === ConnectionState.Connecting || n.stateChanging,
                ref: n
            }))
        }

        const out = raw
            .map(n => Object.assign(n, { name: Labels.cleanLabel(n.name, 40) }))
            .filter(n => n.name !== "")                                        // hidden networks cannot be joined from a list
        out.sort((a, b) => (b.connected ? 1 : 0) - (a.connected ? 1 : 0) || b.strength - a.strength)
        return out
    }

    // ---- rates and address ----

    property real rxRate: 0                 // bytes per second
    property real txRate: 0
    property string ipv4: ""
    property double lastRx: -1
    property double lastTx: -1
    property double lastAt: 0

    readonly property bool sampling: Dropdown.current === "net" && !mock && device !== null && mode !== "off"

    function sample() {
        netdev.reload()
        const r = Logic.parseNetDev(netdev.text(), iface)
        const now = Date.now()
        if (r && lastRx >= 0 && now > lastAt) {
            const dt = (now - lastAt) / 1000
            rxRate = Math.max(0, (r.rx - lastRx) / dt)
            txRate = Math.max(0, (r.tx - lastTx) / dt)
        }
        lastRx = r ? r.rx : -1
        lastTx = r ? r.tx : -1
        lastAt = now
    }

    onSamplingChanged: {
        rxRate = 0
        txRate = 0
        lastRx = -1
        lastTx = -1
    }

    function refreshAddress() {
        if (mock) {
            ipv4 = mode === "off" ? "" : "192.168.0.14"
            return
        }
        if (iface === "" || mode === "off") {
            ipv4 = ""
            return
        }
        addr.command = ["ip", "-4", "-o", "addr", "show", "dev", iface]
        addr.running = true
    }

    onIfaceChanged: refreshAddress()
    onModeChanged: refreshAddress()
    onMockChanged: refreshAddress()
    Component.onCompleted: refreshAddress()

    FileView {
        id: netdev

        path: "/proc/net/dev"
        blockLoading: true
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.sampling
        triggeredOnStart: true
        onTriggered: root.sample()
    }

    Process {
        id: addr

        stdout: StdioCollector {
            onStreamFinished: root.ipv4 = Logic.ipv4FromAddr(text)
        }
    }

    // Mock traffic so the numbers move.
    Timer {
        interval: 1000
        repeat: true
        running: root.mock && Dropdown.current === "net" && root.mode !== "off"
        onTriggered: {
            root.rxRate = Math.max(50000, root.rxRate + (Math.random() - 0.5) * 800000)
            root.txRate = Math.max(20000, root.txRate + (Math.random() - 0.5) * 100000)
        }
    }

    // ---- actions (nothing changes the system while dryRun) ----

    function run(label, fn) {
        last = label
        if (!mock && !dryRun)
            fn()
    }

    function disconnect() {
        run("disconnect", () => device?.disconnect())
        if (mock)
            mockMode = "off"
    }

    function connect() {
        run("connect", () => device?.network?.connect())
        if (mock)
            mockMode = "eth"
    }

    function entryById(id) {
        return wifi.find(n => n.id === id) ?? null
    }

    // Click on a network: connected -> disconnect, known or open -> connect. Secured unknown ones go through joinWifi.
    function toggleWifiNetwork(id) {
        const n = entryById(id)
        if (!n)
            return
        run((n.connected ? "disconnect " : "connect ") + n.name, () => n.connected ? n.ref.disconnect() : n.ref.connect())
        if (mock)
            mockWifi = mockWifi.map(m => Object.assign({}, m, { connected: m.id === id ? !m.connected : (n.connected ? m.connected : false) }))
    }

    // The password goes straight to NetworkManager: it is never stored, logged or shown.
    function joinWifi(id, psk) {
        const n = entryById(id)
        if (!n || !psk)
            return
        run("join " + n.name, () => n.ref.connectWithPsk(psk))
        if (mock)
            mockWifi = mockWifi.map(m => Object.assign({}, m, { connected: m.id === id, known: m.known || m.id === id }))
    }

    IpcHandler {
        target: "net"

        function status(): string {
            return "mode=" + root.mode + " title=" + root.title + " sub=" + root.subtitle + " ip=" + root.ipv4
                + " rx=" + Logic.formatRate(root.rxRate) + " tx=" + Logic.formatRate(root.txRate)
                + " wifi=" + root.wifi.length + " hasWifi=" + root.hasWifi
                + " dry=" + root.dryRun + " mock=" + root.mock + " last=" + root.last
        }

        function list(): string {
            return root.all.map((d, i) => i + ":" + d.name + ":" + (d.type === DeviceType.Wired ? "wired" : d.type === DeviceType.Wifi ? "wifi" : "other")
                + ":" + (d.nmManaged ? "managed" : "unmanaged") + ":" + (d.connected ? "up" : "down") + (i === root.primary ? ":PRIMARY" : "")).join(" | ")
        }

        function networks(): string {
            return root.wifi.map(n => n.name + "(" + Logic.signalBars(n.strength) + (n.secure ? ",lock" : "") + (n.connected ? ",on" : "") + ")").join(" | ")
        }

        function setDryRun(on: bool): void {
            root.dryRun = on
        }

        function setMock(on: bool): void {
            root.mock = on
        }

        function setMockMode(mode: string): void {
            if (["eth", "wifi", "off"].indexOf(mode) >= 0)
                root.mockMode = mode
        }

        function disconnect(): void {
            root.disconnect()
        }

        function connect(): void {
            root.connect()
        }
    }
}
