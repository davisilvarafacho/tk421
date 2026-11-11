import QtQuick
import QtTest

import "../../dropdown/soundlogic.js" as Sound
import "../../theme/icons.js" as Icons

TestCase {
    name: "SoundLogic"

    // ---- micState: muted, unmuted, not recognised ----
    function test_micState() {
        compare(Sound.micState(true, false), "on")
        compare(Sound.micState(true, true), "muted")
        compare(Sound.micState(false, false), "missing")
        compare(Sound.micState(false, true), "missing")           // no device: there is nothing to mute
    }

    // ---- clamp / step ----
    function test_clamp01() {
        compare(Sound.clamp01(0.5), 0.5)
        compare(Sound.clamp01(-1), 0)
        compare(Sound.clamp01(3), 1)
        compare(Sound.clamp01(NaN), 0)
        compare(Sound.clamp01(undefined), 0)
    }

    function test_stepVolume_moves_in_percent_and_clamps() {
        compare(Sound.stepVolume(0.5, 5), 0.55)
        compare(Sound.stepVolume(0.5, -5), 0.45)
        compare(Sound.stepVolume(0.98, 5), 1)
        compare(Sound.stepVolume(0.02, -5), 0)
        compare(Sound.stepVolume(0.333, 5), 0.38)                 // rounded to whole percent
    }

    // ---- text ----
    function test_percentText() {
        compare(Sound.percentText(0.59, false), "59%")
        compare(Sound.percentText(0.594, false), "59%")
        compare(Sound.percentText(0.595, false), "60%")
        compare(Sound.percentText(0.59, true), "mute")
        compare(Sound.percentText(0, false), "0%")
        compare(Sound.percentText(1, false), "100%")
        compare(Sound.percentText(undefined, false), "0%")
    }

    // ---- glyphs ----
    function test_speakerGlyph() {
        compare(Sound.speakerGlyph(0.8, false), "volume_up")
        compare(Sound.speakerGlyph(0.5, false), "volume_up")
        compare(Sound.speakerGlyph(0.2, false), "volume_up")
        compare(Sound.speakerGlyph(0, false), "volume_off")
        compare(Sound.speakerGlyph(0.8, true), "volume_off")
    }

    function test_micGlyph() {
        compare(Sound.micGlyph("on"), "mic")
        compare(Sound.micGlyph("muted"), "mic_muted")
        compare(Sound.micGlyph("missing"), "mic")
    }

    // ---- device kind, glyph, sub line ----
    function test_deviceGlyph() {
        compare(Sound.deviceGlyph("Navi 31 HDMI/DP Audio Digital Stereo (HDMI 4)", {}, true), "tv")
        compare(Sound.deviceGlyph("WH-1000XM5", { "device.form-factor": "headphone" }, true), "headphones")
        compare(Sound.deviceGlyph("Headset", { "device.form-factor": "headset" }, false), "headphones")
        compare(Sound.deviceGlyph("Webcam C920", { "device.form-factor": "webcam" }, false), "videocam")
        compare(Sound.deviceGlyph("Built-in Audio Analog Stereo", {}, true), "speaker")
        compare(Sound.deviceGlyph("Built-in Audio Analog Stereo", {}, false), "mic")
        compare(Sound.deviceGlyph("Anything", undefined, false), "mic")
    }

    function test_deviceSub() {
        compare(Sound.deviceSub("Navi 31 HDMI/DP Audio Digital Stereo (HDMI 4)", { "device.bus": "pci" }), "HDMI / DisplayPort")
        compare(Sound.deviceSub("Built-in Audio Analog Stereo", { "device.bus": "pci" }), "Analog")
        compare(Sound.deviceSub("WH-1000XM5", { "device.bus": "bluetooth" }), "Bluetooth")
        compare(Sound.deviceSub("Webcam C920", { "device.bus": "usb" }), "USB")
        compare(Sound.deviceSub("Whatever", {}), "")
        compare(Sound.deviceSub("Whatever", undefined), "")
    }

    function test_parsePorts_keeps_available_ports_only() {
        const text = JSON.stringify([
            { name: "alsa_output.analog", active_port: "analog-output-lineout", ports: [
                { name: "analog-output-lineout", description: "Line Out", type: "Line", availability: "available" },
                { name: "analog-output-headphones", description: "Headphones", type: "Headphones", availability: "available" },
                { name: "analog-output-speaker", description: "Speakers", type: "Speaker", availability: "not available" }
            ] },
            { name: "alsa_output.hdmi", active_port: "hdmi-output-3", ports: [
                { name: "hdmi-output-3", description: "HDMI / DisplayPort 4", type: "HDMI", availability: "availability unknown" }
            ] }
        ])
        const r = Sound.parsePorts(text)
        compare(r["alsa_output.analog"].active, "analog-output-lineout")
        compare(r["alsa_output.analog"].ports.map(p => p.name), ["analog-output-lineout", "analog-output-headphones"])
        compare(r["alsa_output.analog"].ports[1].label, "Headphones")
        compare(r["alsa_output.hdmi"].ports.length, 1)
    }

    function test_parsePorts_survives_bad_input() {
        compare(Sound.parsePorts(""), {})
        compare(Sound.parsePorts("not json"), {})
        compare(Sound.parsePorts("{}"), {})
        compare(Sound.parsePorts("[null, {\"name\": 3}]"), {})
        compare(Sound.parsePorts("[{\"name\": \"x\"}]")["x"].ports, [])
    }

    function test_portProps_marks_headphone_ports() {
        const props = Sound.portProps({ type: "Headphones" }, { "device.bus": "pci" })
        compare(props["device.form-factor"], "headphone")
        compare(props["device.bus"], "pci")
        compare(Sound.portProps({ type: "Line" }, { "device.bus": "pci" })["device.form-factor"], undefined)
        compare(Sound.deviceGlyph("Headphones", props, true), Sound.deviceGlyph("WH-1000XM5", { "device.form-factor": "headphone" }, true))
    }

    function test_deviceName_is_cleaned_and_falls_back() {
        compare(Sound.deviceName({ description: "Built-in Audio Analog Stereo", nickname: "x", name: "alsa_output.pci" }), "Built-in Audio Analog Stereo")
        compare(Sound.deviceName({ description: "", nickname: "Nick", name: "alsa_output.pci" }), "Nick")
        compare(Sound.deviceName({ description: "", nickname: "", name: "alsa_output.pci" }), "alsa_output.pci")
        compare(Sound.deviceName({ description: "Evil ‮name\n\u0007", nickname: "", name: "" }), "Evil name")
        compare(Sound.deviceName({ description: "x".repeat(100), nickname: "", name: "" }).length, 40)
        compare(Sound.deviceName({}), "Unknown device")
    }

    // Every name these functions can return must be in the icon table.
    function test_allNamesKnown() {
        const names = []
        for (const v of [0, 0.2, 0.5, 0.8])
            for (const m of [false, true])
                names.push(Sound.speakerGlyph(v, m))
        for (const st of ["on", "muted", "missing"])
            names.push(Sound.micGlyph(st))
        for (const ff of ["", "headphone", "headset", "hands-free", "handset", "webcam"])
            for (const nm of ["Built-in Audio", "HDMI / DP Audio", "Thing DP 2"])
                for (const out of [true, false])
                    names.push(Sound.deviceGlyph(nm, { "device.form-factor": ff }, out))
        names.push(Sound.deviceGlyph("x", undefined, true), Sound.deviceGlyph("x", undefined, false))
        for (const n of names)
            verify(Icons.resolve(n) !== null, "unknown icon name: " + n)
    }
}
