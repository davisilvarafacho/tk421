pragma Singleton

import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import QtQuick

import "../bar/trayLogic.js" as Labels
import "../dropdown/netlogic.js" as Logic

// Bluetooth for the bar: the adapter switch, scanning, and the devices as plain entries
// { id, name, glyph, sub, connected, paired, busy, battery }. Real data from Quickshell.Bluetooth (BlueZ); `mock` feeds
// the UI fake devices. While dryRun is true connecting, disconnecting, pairing and the adapter switch change nothing.
// Scanning is read-only discovery and is not guarded.
// Spec: docs/superpowers/specs/2026-10-13-network-and-bluetooth-design.md
Singleton {
    id: root

    readonly property bool active: true

    property bool mock: false
    property bool dryRun: false     // released by the user on 2026-10-13; tests use `mock`, never the real devices
    property string last: ""

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: mock || adapter !== null

    property bool mockPowered: true
    property bool mockScanning: false
    readonly property bool powered: mock ? mockPowered : (adapter?.enabled ?? false)
    readonly property bool scanning: mock ? mockScanning : (adapter?.discovering ?? false)

    // [{ id, name, icon, state: "connected" | "paired" | "nearby" | "connecting" | "pairing", battery }]
    property var mockList: [
        { id: "wh", name: "WH-1000XM5", icon: "audio-headphones", state: "connected", battery: 82 },
        { id: "kb", name: "Keychron K2", icon: "input-keyboard", state: "paired", battery: -1 },
        { id: "mx", name: "MX Master 3", icon: "input-mouse", state: "paired", battery: 64 },
        { id: "px", name: "Pixel 8", icon: "phone", state: "paired", battery: -1 }
    ]
    property var mockNearby: []

    function stateName(d) {
        return d.state === BluetoothDeviceState.Connecting ? "connecting"
            : d.state === BluetoothDeviceState.Disconnecting ? "disconnecting" : "other"
    }

    function entry(id, name, icon, state, connected, paired, pairing, battery, ref) {
        const clean = Labels.cleanLabel(name, 40)
        const pct = Logic.batteryPercent(battery)
        return {
            id: id,
            name: clean !== "" ? clean : "Unknown device",
            glyph: Logic.btGlyph(icon),
            sub: Logic.btSub({ state: state, pairing: pairing, paired: paired, connected: connected, battery: pct }),
            connected: connected,
            paired: paired,
            busy: state === "connecting" || state === "disconnecting" || pairing,
            battery: pct,
            ref: ref
        }
    }

    // Every device BlueZ knows, as entries.
    readonly property var entries: {
        if (mock) {
            return mockList.concat(mockNearby).map(m => entry(m.id, m.name, m.icon, m.state === "connecting" ? "connecting" : "other",
                m.state === "connected", m.state === "connected" || m.state === "paired" || m.state === "connecting", m.state === "pairing", m.battery, null))
        }
        const vals = Bluetooth.devices.values
        return vals.map(d => entry(d.address, d.name || d.deviceName, d.icon, stateName(d), d.connected, d.paired || d.bonded, d.pairing,
            d.batteryAvailable ? d.battery : undefined, d))
    }

    readonly property var devices: Logic.sortBtDevices(entries.filter(e => e.paired))
    // Discovered, not paired. Capped: BlueZ remembers every neighbour it has seen.
    readonly property var nearby: Logic.sortBtDevices(entries.filter(e => !e.paired)).slice(0, 8)
    readonly property int connectedCount: powered ? Logic.countConnected(devices) : 0

    // ---- actions ----

    function guarded(label, fn) {
        last = label
        if (!mock && !dryRun)
            fn()
    }

    function setPowered(on) {
        guarded("power " + on, () => { if (adapter) adapter.enabled = on })
        if (mock) {
            mockPowered = on
            mockScanning = false
            if (!on)
                mockList = mockList.map(m => Object.assign({}, m, { state: m.state === "connected" ? "paired" : m.state }))
        }
    }

    // Discovery is read-only, so it is allowed even in dry run. It stops by itself.
    function scan() {
        if (!powered)
            return
        last = "scan"
        if (mock) {
            mockScanning = true
            mockNearby = []
            mockScanTimer.restart()
        } else if (adapter) {
            adapter.discovering = true
            scanTimer.restart()
        }
    }

    function entryById(id) {
        return entries.find(e => e.id === id) ?? null
    }

    function setMockState(id, state) {
        mockList = mockList.map(m => m.id === id ? Object.assign({}, m, { state: state, battery: state === "connected" ? 40 + Math.floor(Math.random() * 55) : -1 }) : m)
    }

    // Click on a paired device: connected -> disconnect, otherwise connect.
    function toggle(id) {
        const e = entryById(id)
        if (!e || e.busy || !e.paired)
            return
        guarded((e.connected ? "disconnect " : "connect ") + e.name, () => e.connected ? e.ref.disconnect() : e.ref.connect())
        if (mock) {
            setMockState(id, e.connected ? "paired" : "connecting")
            if (!e.connected)
                mockTimer.start()
        }
    }

    function pair(id) {
        const e = entryById(id)
        if (!e || e.busy || e.paired)
            return
        guarded("pair " + e.name, () => e.ref.pair())
        if (mock) {
            mockNearby = mockNearby.map(m => m.id === id ? Object.assign({}, m, { state: "pairing" }) : m)
            mockPairId = id
            mockTimer.start()
        }
    }

    property string mockPairId: ""

    Timer {
        id: mockTimer

        interval: 1200
        onTriggered: {
            root.mockList = root.mockList.map(m => m.state === "connecting" ? Object.assign({}, m, { state: "connected", battery: 40 + Math.floor(Math.random() * 55) }) : m)
            const p = root.mockNearby.find(m => m.id === root.mockPairId)
            if (p) {
                root.mockNearby = root.mockNearby.filter(m => m !== p)
                root.mockList = root.mockList.concat([Object.assign({}, p, { state: "connected", battery: 70 })])
                root.mockPairId = ""
            }
        }
    }

    Timer {
        id: mockScanTimer

        interval: 3200
        onTriggered: {
            root.mockScanning = false
            root.mockNearby = [
                { id: "jb", name: "JBL Flip 6", icon: "audio-speaker", state: "nearby", battery: -1 },
                { id: "un", name: "", icon: "", state: "nearby", battery: -1 }
            ]
        }
    }

    Timer {
        id: scanTimer

        interval: 12000
        onTriggered: {
            if (root.adapter)
                root.adapter.discovering = false
        }
    }

    IpcHandler {
        target: "bt"

        function status(): string {
            return "available=" + root.available + " powered=" + root.powered + " scanning=" + root.scanning
                + " connected=" + root.connectedCount + " devices=" + root.devices.length + " nearby=" + root.nearby.length
                + " dry=" + root.dryRun + " mock=" + root.mock + " last=" + root.last
        }

        function list(): string {
            return root.devices.map(d => d.name + "[" + d.sub + "]").join(" | ") + " || " + root.nearby.map(d => d.name + "[" + d.sub + "]").join(" | ")
        }

        function setDryRun(on: bool): void {
            root.dryRun = on
        }

        function setMock(on: bool): void {
            root.mock = on
        }

        function power(on: bool): void {
            root.setPowered(on)
        }

        function scan(): void {
            root.scan()
        }
    }
}
