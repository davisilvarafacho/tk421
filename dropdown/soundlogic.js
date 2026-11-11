.pragma library

// Pure rules for the sound items of the bar (volume, microphone, device lists). Tested by tests/qml/tst_soundlogic.qml.

// The microphone has three states: on, muted, or not recognised (no input device at all, so there is nothing to mute).
function micState(hasSource, muted) {
    if (!hasSource)
        return "missing"
    return muted ? "muted" : "on"
}

function clamp01(v) {
    var n = Number(v)
    return isNaN(n) ? 0 : Math.max(0, Math.min(1, n))
}

// Move a 0..1 volume by `deltaPercent` whole percent points.
function stepVolume(current, deltaPercent) {
    return clamp01((Math.round(clamp01(current) * 100) + deltaPercent) / 100)
}

function percentText(v, muted) {
    return muted ? "mute" : Math.round(clamp01(v) * 100) + "%"
}

// Material Design volume glyphs from the Symbols Nerd Font: off, low, medium, high.
function speakerGlyph(vol, muted) {
    if (muted || !(vol > 0))
        return "󰖁"
    if (vol < 0.34)
        return "󰕿"
    if (vol < 0.67)
        return "󰖀"
    return "󰕾"
}

// Font Awesome microphone / microphone-slash. "Not recognised" uses the plain glyph, dimmed by the item.
function micGlyph(state) {
    return state === "muted" ? "" : ""
}

function clean(text, max) {
    var s = (text === undefined || text === null) ? "" : String(text)
    s = s.replace(/[\u0000-\u0008\u000B-\u001F\u007F‪-‮⁦-⁩]/g, "").replace(/\s*\n\s*/g, " ").trim()
    if (s.length <= max)
        return s
    var end = max - 1
    var code = s.charCodeAt(end - 1)
    if (code >= 0xD800 && code <= 0xDBFF)
        end -= 1
    return s.slice(0, end) + "…"
}

// A device name from a PipeWire node: description, then nickname, then the node name. Cleaned and limited.
function deviceName(node) {
    var n = clean(node && (node.description || node.nickname || node.name), 40)
    return n !== "" ? n : "Unknown device"
}

function deviceGlyph(name, props, isOutput) {
    var ff = String((props && props["device.form-factor"]) || "").toLowerCase()
    if (ff.indexOf("head") >= 0 || ff.indexOf("hands-free") >= 0 || ff.indexOf("handset") >= 0)
        return "headphones"
    if (ff.indexOf("webcam") >= 0)
        return "videocam"
    if (isOutput && (/hdmi|displayport/i.test(name) || /\bDP\b/.test(name)))
        return "tv"
    return isOutput ? "speaker" : "mic"
}

// The ports each sink offers, from `pactl -f json list sinks`: { sinkName: { active, ports: [{ name, label, type }] } }.
// A port the driver reports as "not available" (nothing plugged in) is left out. Bad input gives {}.
function parsePorts(text) {
    var sinks
    try {
        sinks = JSON.parse(text)
    } catch (e) {
        return {}
    }
    var out = {}
    if (!Array.isArray(sinks))
        return out
    sinks.forEach(function (s) {
        if (!s || typeof s.name !== "string")
            return
        var ports = (Array.isArray(s.ports) ? s.ports : [])
            .filter(function (p) { return p && typeof p.name === "string" && p.availability !== "not available" })
            .map(function (p) { return { name: p.name, label: clean(p.description || p.name, 40), type: String(p.type || "") } })
        out[s.name] = { active: String(s.active_port || ""), ports: ports }
    })
    return out
}

// Device properties for a port, so deviceGlyph / deviceSub treat a Headphones port like headphones.
function portProps(port, nodeProps) {
    var props = {}
    for (var k in nodeProps)
        props[k] = nodeProps[k]
    if (/headphone|headset/i.test(port.type || ""))
        props["device.form-factor"] = "headphone"
    return props
}

function deviceSub(name, props) {
    var bus = String((props && props["device.bus"]) || "").toLowerCase()
    if (bus === "bluetooth")
        return "Bluetooth"
    if (/hdmi|displayport/i.test(name) || /\bDP\b/.test(name))
        return "HDMI / DisplayPort"
    if (/analog/i.test(name))
        return "Analog"
    if (bus === "usb")
        return "USB"
    return ""
}
