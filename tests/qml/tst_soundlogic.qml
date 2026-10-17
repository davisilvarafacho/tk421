import QtQuick
import QtTest

import "../../dropdown/soundlogic.js" as Sound

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
        compare(Sound.speakerGlyph(0.8, false), "󰕾")
        compare(Sound.speakerGlyph(0.5, false), "󰖀")
        compare(Sound.speakerGlyph(0.2, false), "󰕿")
        compare(Sound.speakerGlyph(0, false), "󰖁")
        compare(Sound.speakerGlyph(0.8, true), "󰖁")
    }

    function test_micGlyph() {
        compare(Sound.micGlyph("on"), "")
        compare(Sound.micGlyph("muted"), "")
        compare(Sound.micGlyph("missing"), "")
    }

    // ---- device kind, glyph, sub line ----
    function test_deviceGlyph() {
        compare(Sound.deviceGlyph("Navi 31 HDMI/DP Audio Digital Stereo (HDMI 4)", {}, true), "")
        compare(Sound.deviceGlyph("WH-1000XM5", { "device.form-factor": "headphone" }, true), "")
        compare(Sound.deviceGlyph("Headset", { "device.form-factor": "headset" }, false), "")
        compare(Sound.deviceGlyph("Webcam C920", { "device.form-factor": "webcam" }, false), "")
        compare(Sound.deviceGlyph("Built-in Audio Analog Stereo", {}, true), "")
        compare(Sound.deviceGlyph("Built-in Audio Analog Stereo", {}, false), "")
        compare(Sound.deviceGlyph("Anything", undefined, false), "")
    }

    function test_deviceSub() {
        compare(Sound.deviceSub("Navi 31 HDMI/DP Audio Digital Stereo (HDMI 4)", { "device.bus": "pci" }), "HDMI / DisplayPort")
        compare(Sound.deviceSub("Built-in Audio Analog Stereo", { "device.bus": "pci" }), "Analog")
        compare(Sound.deviceSub("WH-1000XM5", { "device.bus": "bluetooth" }), "Bluetooth")
        compare(Sound.deviceSub("Webcam C920", { "device.bus": "usb" }), "USB")
        compare(Sound.deviceSub("Whatever", {}), "")
        compare(Sound.deviceSub("Whatever", undefined), "")
    }

    function test_deviceName_is_cleaned_and_falls_back() {
        compare(Sound.deviceName({ description: "Built-in Audio Analog Stereo", nickname: "x", name: "alsa_output.pci" }), "Built-in Audio Analog Stereo")
        compare(Sound.deviceName({ description: "", nickname: "Nick", name: "alsa_output.pci" }), "Nick")
        compare(Sound.deviceName({ description: "", nickname: "", name: "alsa_output.pci" }), "alsa_output.pci")
        compare(Sound.deviceName({ description: "Evil ‮name\n\u0007", nickname: "", name: "" }), "Evil name")
        compare(Sound.deviceName({ description: "x".repeat(100), nickname: "", name: "" }).length, 40)
        compare(Sound.deviceName({}), "Unknown device")
    }
}
