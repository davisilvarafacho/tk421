pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

import "../dropdown/soundlogic.js" as Logic

// Sound for the bar: the default output and input (volume, mute), the microphone state (on / muted / not recognised) and
// the device lists for the quick switch. Real data from PipeWire; `mock` feeds the UI fake devices for visual checks.
// The volume HUD of the island still follows services/Audio.qml, which tracks the same default sink.
// Rules: dropdown/soundlogic.js. Prototype: prototypes/toolbar/index.html.
Singleton {
    id: root

    readonly property bool active: true

    property bool mock: false
    property string mockMic: "on"           // "on" | "muted" | "missing"
    property real mockOutVol: 0.59
    property bool mockOutMuted: false
    property real mockInVol: 0.72
    property bool mockInMuted: false
    property string mockOutCur: "hdmi"
    property string mockInCur: "mic"

    // ---- real devices ----

    readonly property var audioNodes: Pipewire.nodes.values.filter(n => !n.isStream && (n.type & PwNodeType.Audio) !== 0)
    readonly property var sinkNodes: audioNodes.filter(n => n.isSink)
    readonly property var sourceNodes: audioNodes.filter(n => !n.isSink)
    readonly property var defSink: Pipewire.defaultAudioSink
    readonly property var defSource: Pipewire.defaultAudioSource

    // A node's volume and mute are only readable while it is tracked.
    PwObjectTracker {
        objects: root.sinkNodes.concat(root.sourceNodes)
    }

    // ---- state the UI reads ----

    readonly property real outVolume: mock ? mockOutVol : (defSink?.audio?.volume ?? 0)
    readonly property bool outMuted: mock ? mockOutMuted : (defSink?.audio?.muted ?? false)
    readonly property real inVolume: mock ? mockInVol : (defSource?.audio?.volume ?? 0)
    readonly property bool inMuted: mock ? (mockMic === "muted" || mockInMuted) : (defSource?.audio?.muted ?? false)
    readonly property bool hasSource: mock ? mockMic !== "missing" : defSource !== null
    readonly property string micState: Logic.micState(hasSource, inMuted)
    readonly property string outText: Logic.percentText(outVolume, outMuted)
    readonly property string outGlyph: Logic.speakerGlyph(outVolume, outMuted)

    function entry(id, name, props, isOutput, current, ref) {
        return {
            id: id,
            name: name,
            sub: Logic.deviceSub(name, props),
            glyph: Logic.deviceGlyph(name, props, isOutput),
            current: current,
            ref: ref
        }
    }

    readonly property var mockOutputs: [
        entry("hdmi", "HDMI / DisplayPort", {}, true, mockOutCur === "hdmi", null),
        entry("analog", "Speakers", {}, true, mockOutCur === "analog", null),
        entry("bt", "WH-1000XM5", { "device.form-factor": "headphone", "device.bus": "bluetooth" }, true, mockOutCur === "bt", null)
    ]
    readonly property var mockInputs: mockMic === "missing" ? [] : [
        entry("mic", "Microphone", {}, false, mockInCur === "mic", null),
        entry("webcam", "Webcam C920", { "device.form-factor": "webcam", "device.bus": "usb" }, false, mockInCur === "webcam", null)
    ]

    // A sink with several plugged-in ports (the motherboard's front headphones and rear line out) is one PipeWire node,
    // so each port becomes its own entry; PipeWire does not expose ports to Quickshell, `pactl` reads and sets them.
    property var portInfo: ({})

    function outputEntries(n) {
        const info = portInfo[n.name]
        if (!info || info.ports.length < 2)
            return [entry(n.id, Logic.deviceName(n), n.properties, true, n.id === defSink?.id, n)]
        return info.ports.map(p => {
            const e = entry(n.id + ":" + p.name, p.label, Logic.portProps(p, n.properties), true,
                n.id === defSink?.id && p.name === info.active, n)
            e.port = p.name
            return e
        })
    }

    function refreshPorts() {
        if (!mock && !portReader.running)
            portReader.running = true
    }

    onSinkNodesChanged: refreshPorts()
    onDefSinkChanged: refreshPorts()
    Component.onCompleted: refreshPorts()

    Process {
        id: portReader

        command: ["pactl", "-f", "json", "list", "sinks"]
        stdout: StdioCollector {
            onStreamFinished: root.portInfo = Logic.parsePorts(text)
        }
    }

    Process {
        id: portSetter

        property string sink: ""
        property string port: ""

        command: ["pactl", "set-sink-port", sink, port]
        onExited: root.refreshPorts()
    }

    readonly property var outputs: mock ? mockOutputs : sinkNodes.reduce((all, n) => all.concat(outputEntries(n)), [])
    readonly property var inputs: mock ? mockInputs : sourceNodes.map(n => entry(n.id, Logic.deviceName(n), n.properties, false, n.id === defSource?.id, n))

    // ---- actions ----

    function setVolume(kind, v) {
        const value = Logic.clamp01(v)
        if (mock) {
            if (kind === "out") {
                mockOutVol = value
                if (value > 0)
                    mockOutMuted = false
            } else {
                mockInVol = value
                if (value > 0)
                    mockInMuted = false
            }
            return
        }
        const node = kind === "out" ? defSink : defSource
        if (!node?.audio)
            return
        node.audio.volume = value
        if (value > 0)
            node.audio.muted = false
    }

    function step(kind, deltaPercent) {
        setVolume(kind, Logic.stepVolume(kind === "out" ? outVolume : inVolume, deltaPercent))
    }

    function toggleMute(kind) {
        if (mock) {
            if (kind === "out")
                mockOutMuted = !mockOutMuted
            else if (mockMic === "muted")
                mockMic = "on"
            else if (mockMic === "on")
                mockMic = "muted"
            return
        }
        const node = kind === "out" ? defSink : defSource
        if (node?.audio)
            node.audio.muted = !node.audio.muted
    }

    // Make a device the default. The island confirms it.
    function use(kind, id) {
        const list = kind === "out" ? outputs : inputs
        const e = list.find(x => x.id === id)
        if (!e || e.current)
            return
        if (mock) {
            if (kind === "out")
                mockOutCur = id
            else
                mockInCur = id
        } else if (kind === "out") {
            Pipewire.preferredDefaultAudioSink = e.ref
            if (e.port) {
                portSetter.sink = e.ref.name
                portSetter.port = e.port
                portSetter.running = true
            }
        } else {
            Pipewire.preferredDefaultAudioSource = e.ref
        }
        Hud.show(kind === "out" ? "Output" : "Input", e.name, e.glyph, "")
    }

    IpcHandler {
        target: "sound"

        function status(): string {
            return "out=" + root.outText + " in=" + Logic.percentText(root.inVolume, root.inMuted) + " mic=" + root.micState
                + " outputs=" + root.outputs.length + " inputs=" + root.inputs.length + " mock=" + root.mock
        }

        function list(): string {
            const fmt = l => l.map((d, i) => i + ":" + d.name + (d.sub !== "" ? " (" + d.sub + ")" : "") + (d.current ? " *" : "")).join(" | ")
            return "out: " + fmt(root.outputs) + " || in: " + fmt(root.inputs)
        }

        function setMock(on: bool): void {
            root.mock = on
        }

        function setMockMic(state: string): void {
            if (["on", "muted", "missing"].indexOf(state) >= 0)
                root.mockMic = state
        }

        function volume(kind: string, percent: int): void {
            root.setVolume(kind, percent / 100)
        }

        function mute(kind: string): void {
            root.toggleMute(kind)
        }

        function use(kind: string, index: int): void {
            const e = (kind === "out" ? root.outputs : root.inputs)[index]
            if (e)
                root.use(kind, e.id)
        }
    }
}
