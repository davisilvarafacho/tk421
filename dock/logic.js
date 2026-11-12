.pragma library

// Pure helpers of the dock (dock/Dock.qml). Tested by tests/qml/tst_docklogic.qml.

// Desktop entry ids pinned on first start (chosen in prototypes/dock/index.html). The owner's list lives in
// dock/state.json once they pin or unpin anything.
var DEFAULT_PINNED = [
    "com.mitchellh.ghostty",
    "vivaldi-stable",
    "io.github.soyeb_jim285.HyprFM",
    "com.microsoft.VSCode",
    "com.anthropic.Claude",
    "spotify",
    "org.telegram.desktop",
    "discord",
    "org.mozilla.Thunderbird",
    "steam"
]

var MODES = ["auto", "always"]

// state.json -> { pinned: [ids], mode }. Anything malformed falls back to the defaults.
function parseState(text) {
    var s = null
    try {
        s = JSON.parse(text)
    } catch (e) {
        s = null
    }
    if (!s || typeof s !== "object")
        s = {}
    var pinned = Array.isArray(s.pinned)
        ? s.pinned.filter(function (id, i, a) { return typeof id === "string" && id !== "" && a.indexOf(id) === i })
        : DEFAULT_PINNED.slice()
    var mode = MODES.indexOf(s.mode) >= 0 ? s.mode : "auto"
    return { pinned: pinned, mode: mode }
}

function serializeState(pinned, mode) {
    return JSON.stringify({ pinned: pinned, mode: mode }, null, 2) + "\n"
}

// Windows the dock never lists: the shell's own Ghostty widgets (com.tk421.widget.*, workspace 6) and the palette
// tester, plus anything without an app id.
function ignored(appId) {
    return !appId || appId.indexOf("com.tk421.") === 0
}

// pinned: [ids]; windows: [{ key, ref }] in compositor order, key = resolved desktop entry id (or the app id when no
// entry matches). Returns the dock's slots: every pinned id in pinned order, then each other running key in order of
// its first window, each with its windows.
function group(pinned, windows) {
    var out = []
    var byKey = {}
    pinned.forEach(function (id) {
        var g = { key: id, pinned: true, wins: [] }
        byKey[id] = g
        out.push(g)
    })
    windows.forEach(function (w) {
        var g = byKey[w.key]
        if (!g) {
            g = { key: w.key, pinned: false, wins: [] }
            byKey[w.key] = g
            out.push(g)
        }
        g.wins.push(w.ref)
    })
    return out
}

function togglePin(pinned, key) {
    var i = pinned.indexOf(key)
    if (i >= 0)
        return pinned.slice(0, i).concat(pinned.slice(i + 1))
    return pinned.concat([key])
}

// Magnification of one icon: 1 far away, 1 + mag right under the pointer, a raised-cosine falloff over `reach`
// cells. dx = pointer x minus the icon's resting centre.
function magnify(dx, cell, reach, mag) {
    var d = Math.abs(dx) / (cell * reach)
    if (d >= 1)
        return 1
    return 1 + mag * (Math.cos(d * Math.PI) + 1) / 2
}

// The window to raise when an app's icon is clicked: the first window if none of them is focused, otherwise the one
// after the focused window (a click on the focused app cycles through its windows). Returns an index or -1.
function nextWindow(activeFlags) {
    if (activeFlags.length === 0)
        return -1
    var i = activeFlags.indexOf(true)
    return i < 0 ? 0 : (i + 1) % activeFlags.length
}

// "Close window" / "Close 3 windows" / "1 window" / "Not running" for the context menu.
function windowCount(n) {
    if (n === 0)
        return "Not running"
    return n === 1 ? "1 window" : n + " windows"
}

function closeLabel(n) {
    return n === 1 ? "Close window" : "Close " + n + " windows"
}
