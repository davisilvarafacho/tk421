.pragma library

// Pure rules for the wallpaper picker (folder, plates, effects, names, awww, state file, easings).
// Tested by tests/qml/tst_wallpaperlogic.qml.

var EFFECTS = ["laser", "hyperspace", "doors", "scan"]
var LABELS = { laser: "SUPERLASER", hyperspace: "HYPERSPACE", doors: "BLAST DOORS", scan: "TACTICAL SCAN" }
var DURATIONS = { laser: 1000, hyperspace: 1200, doors: 1000, scan: 900 }
var REDUCED_MS = 260
var IMAGE_EXT = /\.(png|jpe?g|webp|gif)$/i

// ---- folder ----

function isImage(name) {
    return typeof name === "string" && name.charAt(0) !== "." && IMAGE_EXT.test(name)
}

function listImages(names) {
    return (names || []).filter(isImage).sort(function (a, b) {
        var x = a.toLowerCase(), y = b.toLowerCase()
        return x < y ? -1 : x > y ? 1 : a < b ? -1 : a > b ? 1 : 0
    })
}

// The wallpaper that is on screen always appears in the bay, even when it lives outside the folder.
function withApplied(files, applied) {
    if (!applied || files.indexOf(applied) >= 0)
        return files.slice()
    return [applied].concat(files)
}

// ---- plates ----

function mod(a, n) {
    return ((a % n) + n) % n
}

// Offset of plate i from the selected one, wrapped so the nearest side wins.
function offset(i, sel, n) {
    if (n <= 0)
        return 0
    var h = Math.floor(n / 2)
    return mod(i - sel + h, n) - h
}

// Placement by distance from the selection: x in design px, scale, opacity. Farther plates are parked invisible.
var SLOTS = [[0, 1, 1], [310, 0.6, 0.95], [505, 0.4, 0.5]]

function slot(off) {
    var s = SLOTS[Math.abs(off)] || [700, 0.3, 0]
    var dir = off < 0 ? -1 : 1
    return { x: dir * s[0], scale: s[1], opacity: s[2] }
}

// Only plates this close keep their image decoded.
function isNear(off) {
    return Math.abs(off) <= 3
}

function stepIndex(i, step, n) {
    return n > 0 ? mod(i + step, n) : 0
}

// Lintel lamps: one per wallpaper, at most `max`; the lit one tracks the selection.
function lampIndex(sel, n, max) {
    return n <= max ? sel : Math.floor(sel * max / n)
}

// ---- effects ----

function isEffect(id) {
    return EFFECTS.indexOf(id) >= 0
}

function stepEffect(cur, step) {
    var i = EFFECTS.indexOf(cur)
    if (i < 0)
        i = 0
    return EFFECTS[mod(i + step, EFFECTS.length)]
}

// Which way the effect button's label slides: 1 when `to` is the next effect after `from` (wrapping), -1 otherwise.
function effectDirection(from, to) {
    var a = EFFECTS.indexOf(from)
    var b = EFFECTS.indexOf(to)
    if (a < 0 || b < 0)
        return 1
    return mod(b - a, EFFECTS.length) === 1 ? 1 : -1
}

// Mouse wheel and touchpad: accumulate the angle deltas and turn every full notch (120) into one step.
// Scrolling down (negative delta) moves forward. Returns the steps to take and the delta left over.
function wheelStep(acc, delta, notch) {
    var n = notch || 120
    var total = acc + delta
    var steps = 0
    while (total <= -n) {
        steps += 1
        total += n
    }
    while (total >= n) {
        steps -= 1
        total -= n
    }
    return { steps: steps, acc: total + 0 }
}

function duration(id, reduced) {
    return reduced ? REDUCED_MS : (DURATIONS[id] || DURATIONS.laser)
}

// ---- names and URLs: file names come from outside ----

// No extension, no control or bidi characters, at most 40 characters.
function displayName(path) {
    var base = String(path).split("/").pop()
    base = base.replace(/\.[^.]*$/, "")
    base = base.replace(/[\u0000-\u001f\u007f-\u009f‎‏‪-‮⁦-⁩]/g, "")
    base = base.replace(/[_-]+/g, " ").replace(/\s+/g, " ").trim()
    if (base === "")
        return "UNTITLED"
    return base.length > 40 ? base.slice(0, 39) + "…" : base
}

function fileUrl(path) {
    return "file://" + String(path).split("/").map(encodeURIComponent).join("/")
}

// ---- awww and the state file ----

function awwwArgs(path) {
    return ["awww", "img", "--transition-type", "none", path]
}

// `awww query` prints ": DP-1: 2560x1080, scale: 1, currently displaying: image: /path/to/file".
function parseAwwwQuery(text) {
    var m = /currently displaying: image: (.+)$/m.exec(String(text || ""))
    return m ? m[1].trim() : ""
}

function parseState(text) {
    var out = { path: "", effect: "laser" }
    try {
        var d = JSON.parse(text)
        if (d && typeof d.path === "string")
            out.path = d.path
        if (d && isEffect(d.effect))
            out.effect = d.effect
    } catch (e) {
        // missing or corrupt: the defaults stand
    }
    return out
}

function serializeState(path, effect) {
    return JSON.stringify({ path: path, effect: isEffect(effect) ? effect : "laser" }, null, 2) + "\n"
}

function needsApply(applied, selected) {
    return !!selected && selected !== applied
}

// The wallpaper that is on screen at start: awww's own answer wins, the stored path is the fallback. Nothing is decided until
// awww has answered (or given up), so a stale stored path never drives the stage.
function chooseApplied(queryPath, statePath, queryDone) {
    if (!queryDone)
        return ""
    return queryPath !== "" ? queryPath : statePath
}

// ---- easings (the same curves as the prototype) ----

function clamp(x, a, b) {
    var lo = a === undefined ? 0 : a
    var hi = b === undefined ? 1 : b
    return Math.min(hi, Math.max(lo, x))
}

function easeInCubic(t) { return t * t * t }
function easeOutCubic(t) { return 1 - Math.pow(1 - t, 3) }
function easeOutQuart(t) { return 1 - Math.pow(1 - t, 4) }
function easeOutExpo(t) { return t >= 1 ? 1 : 1 - Math.pow(2, -10 * t) }
function easeInOutCubic(t) { return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2 }
function easeInOutQuart(t) { return t < 0.5 ? 8 * t * t * t * t : 1 - Math.pow(-2 * t + 2, 4) / 2 }
