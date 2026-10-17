import QtQuick
import QtTest

import "../../dropdown/netlogic.js" as Net

TestCase {
    name: "NetLogic"

    // ---- formatRate ----
    function test_formatRate_units() {
        compare(Net.formatRate(0), "0 B/s")
        compare(Net.formatRate(999), "999 B/s")
        compare(Net.formatRate(1000), "1 KB/s")
        compare(Net.formatRate(202400), "202 KB/s")
        compare(Net.formatRate(999999), "1000 KB/s")
        compare(Net.formatRate(1000000), "1.0 MB/s")
        compare(Net.formatRate(2340000), "2.3 MB/s")
        compare(Net.formatRate(1.2e9), "1.2 GB/s")
    }

    function test_formatRate_garbage_is_zero() {
        compare(Net.formatRate(-5), "0 B/s")
        compare(Net.formatRate(NaN), "0 B/s")
        compare(Net.formatRate(undefined), "0 B/s")
    }

    // ---- signalBars ----
    function test_signalBars() {
        compare(Net.signalBars(0), 0)
        compare(Net.signalBars(-1), 0)
        compare(Net.signalBars(0.01), 1)
        compare(Net.signalBars(0.25), 1)
        compare(Net.signalBars(0.26), 2)
        compare(Net.signalBars(0.5), 2)
        compare(Net.signalBars(0.75), 3)
        compare(Net.signalBars(0.76), 4)
        compare(Net.signalBars(1), 4)
        compare(Net.signalBars(7), 4)
        compare(Net.signalBars(NaN), 0)
    }

    // ---- parseNetDev ----
    readonly property string netdev: "Inter-|   Receive                                                |  Transmit\n"
        + " face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed\n"
        + "    lo: 1000 10 0 0 0 0 0 0 1000 10 0 0 0 0 0 0\n"
        + "  eno1: 123456789 5000 0 0 0 0 0 12 987654 4000 0 0 0 0 0 0\n"
        + "docker0: 5 1 0 0 0 0 0 0 6 1 0 0 0 0 0 0\n"

    function test_parseNetDev_reads_rx_and_tx() {
        const r = Net.parseNetDev(netdev, "eno1")
        compare(r.rx, 123456789)
        compare(r.tx, 987654)
    }

    function test_parseNetDev_does_not_confuse_prefixes() {
        compare(Net.parseNetDev(netdev, "eno"), null)          // a prefix is not the interface
        compare(Net.parseNetDev(netdev, "eno12"), null)
    }

    function test_parseNetDev_missing_interface() {
        compare(Net.parseNetDev(netdev, "wlan0"), null)
        compare(Net.parseNetDev("", "eno1"), null)
        compare(Net.parseNetDev(undefined, "eno1"), null)
        compare(Net.parseNetDev(netdev, ""), null)
    }

    // ---- ipv4FromAddr ----
    function test_ipv4FromAddr() {
        compare(Net.ipv4FromAddr("2: eno1    inet 192.168.0.14/24 brd 192.168.0.255 scope global dynamic eno1\n"), "192.168.0.14")
        compare(Net.ipv4FromAddr("2: eno1    inet 10.0.0.2/8 scope global eno1\n2: eno1 inet 10.0.0.3/8 scope global secondary eno1\n"), "10.0.0.2")
        compare(Net.ipv4FromAddr(""), "")
        compare(Net.ipv4FromAddr(undefined), "")
        compare(Net.ipv4FromAddr("2: eno1 inet6 fe80::1/64 scope link"), "")
    }

    // ---- primaryIndex ----
    function dev(wired, managed, connected) { return { wired: wired, managed: managed, connected: connected } }

    function test_primaryIndex_prefers_connected_ethernet() {
        compare(Net.primaryIndex([dev(false, true, true), dev(true, true, true)]), 1)
    }

    function test_primaryIndex_then_connected_wifi() {
        compare(Net.primaryIndex([dev(true, true, false), dev(false, true, true)]), 1)
    }

    function test_primaryIndex_then_any_managed_wired_then_wifi() {
        compare(Net.primaryIndex([dev(false, true, false), dev(true, true, false)]), 1)
        compare(Net.primaryIndex([dev(false, true, false)]), 0)
    }

    function test_primaryIndex_ignores_unmanaged_docker_style_devices() {
        compare(Net.primaryIndex([dev(true, false, true), dev(true, false, true)]), -1)
        compare(Net.primaryIndex([dev(true, false, true), dev(true, true, false)]), 1)
    }

    function test_primaryIndex_empty() {
        compare(Net.primaryIndex([]), -1)
        compare(Net.primaryIndex(undefined), -1)
    }

    // ---- btGlyph ----
    function test_btGlyph() {
        compare(Net.btGlyph("audio-headphones"), "")
        compare(Net.btGlyph("audio-headset"), "")
        compare(Net.btGlyph("input-keyboard"), "")
        compare(Net.btGlyph("input-mouse"), "󰍽")
        compare(Net.btGlyph("phone"), "")
        compare(Net.btGlyph("audio-card"), "")
        compare(Net.btGlyph("input-gaming"), "")
        compare(Net.btGlyph("something-else"), "")
        compare(Net.btGlyph(""), "")
        compare(Net.btGlyph(undefined), "")
    }

    // ---- btSub ----
    function test_btSub() {
        compare(Net.btSub({ state: "connecting" }), "Connecting…")
        compare(Net.btSub({ state: "disconnecting" }), "Disconnecting…")
        compare(Net.btSub({ pairing: true }), "Pairing…")
        compare(Net.btSub({ connected: true, battery: 82 }), "Connected · 82%")
        compare(Net.btSub({ connected: true, battery: -1 }), "Connected")
        compare(Net.btSub({ connected: true }), "Connected")
        compare(Net.btSub({ paired: true }), "Paired")
        compare(Net.btSub({}), "Not paired")
    }

    // ---- sortBtDevices ----
    function names(l) { return l.map(d => d.name).join(",") }

    function test_sortBtDevices_connected_first_then_name() {
        const l = [{ name: "zeta" }, { name: "Alpha", connected: true }, { name: "beta" }, { name: "Gamma", connected: true }]
        compare(names(Net.sortBtDevices(l)), "Alpha,Gamma,beta,zeta")
    }

    function test_sortBtDevices_does_not_mutate_and_handles_empty() {
        const l = [{ name: "b" }, { name: "a" }]
        Net.sortBtDevices(l)
        compare(names(l), "b,a")
        compare(Net.sortBtDevices([]).length, 0)
    }

    // ---- batteryPercent ----
    function test_batteryPercent() {
        compare(Net.batteryPercent(0.82), 82)
        compare(Net.batteryPercent(82), 82)
        compare(Net.batteryPercent(1), 100)
        compare(Net.batteryPercent(100), 100)
        compare(Net.batteryPercent(150), 100)
        compare(Net.batteryPercent(0), 0)
        compare(Net.batteryPercent(-1), -1)
        compare(Net.batteryPercent(NaN), -1)
        compare(Net.batteryPercent(undefined), -1)
    }

    // ---- countConnected ----
    function test_countConnected() {
        compare(Net.countConnected([{ connected: true }, {}, { connected: true }]), 2)
        compare(Net.countConnected([]), 0)
        compare(Net.countConnected(undefined), 0)
    }
}
