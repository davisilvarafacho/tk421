.pragma library

// Pure rules for the notification system. No QML, no state, so everything here is unit-tested
// (tests/qml/tst_logic.qml). Everything that comes from other programs passes through clean()/clip().

var LIMITS = { summary: 120, body: 600, appName: 40, actionText: 24, actions: 3, history: 50 }
var TOAST_MS = 5000

var DAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
var MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

function pad(n) {
    return (n < 10 ? "0" : "") + n
}

// Text from other programs: drop control characters (keeping \n and \t) and the bidirectional
// override/isolate characters that can reorder what the user reads.
function clean(text) {
    var s = (text === undefined || text === null) ? "" : String(text)
    return s.replace(/[\u0000-\u0008\u000B-\u001F\u007F‪-‮⁦-⁩]/g, "")
}

function clip(text, max) {
    var s = clean(text)
    if (s.length <= max)
        return s

    var end = max - 1
    var code = s.charCodeAt(end - 1)
    if (code >= 0xD800 && code <= 0xDBFF)          // do not cut a surrogate pair in half
        end -= 1
    return s.slice(0, end) + "…"
}

function oneLine(s) {
    return s.replace(/\s*\n\s*/g, " ").trim()
}

function titleOf(summary, appName) {
    var s = oneLine(clip(summary, LIMITS.summary))
    if (s !== "")
        return s

    var a = oneLine(clip(appName, LIMITS.appName))
    return a !== "" ? a : "Notification"
}

// Icon names and absolute paths only. Anything with a URL scheme is dropped, so a notification cannot
// make the shell fetch a remote image.
function iconSource(appIcon) {
    var s = (appIcon === undefined || appIcon === null) ? "" : String(appIcon).trim()
    if (s === "")
        return { kind: "none", value: "" }
    if (/^[a-zA-Z][a-zA-Z0-9+.\-]*:/.test(s))
        return { kind: "none", value: "" }
    if (s.charAt(0) === "/")
        return { kind: "path", value: s }
    return { kind: "name", value: s }
}

// Apps whose notifications get a themed icon from assets/<asset>.svg instead of the icon the app sent (or none).
// Matched on the app name, or on the title for apps that send no name (Claude Code, through the terminal).
var APP_RULES = [
    { app: /claude/i, title: /^claude code\b/i, name: "Claude Code", asset: "claude" }
]

// What the header of a notification shows: the app's name and the themed icon, if any.
// An empty app name falls back to the desktop entry's last segment, then to "System".
function appLabel(appName, desktopEntry, summary) {
    var name = oneLine(clip(appName, LIMITS.appName))
    var title = oneLine(clip(summary, LIMITS.summary))

    for (var i = 0; i < APP_RULES.length; i++) {
        if (APP_RULES[i].app.test(name) || APP_RULES[i].title.test(title))
            return { name: APP_RULES[i].name, asset: APP_RULES[i].asset }
    }

    if (name === "")
        name = String(desktopEntry === undefined || desktopEntry === null ? "" : desktopEntry).split(".").pop()
    return { name: name === "" ? "System" : name, asset: "" }
}

// raw: any array-like of { identifier, text } (a QML list works). `index` points into the original list.
function pickActions(raw) {
    var out = []
    if (!raw)
        return out

    for (var i = 0; i < raw.length && out.length < LIMITS.actions; i++) {
        var a = raw[i]
        var text = oneLine(clip(a.text, LIMITS.actionText))
        if (a.identifier === "default" || text === "")
            continue
        out.push({ index: i, identifier: a.identifier, text: text })
    }
    return out
}

function startOfDay(ms) {
    var d = new Date(ms)
    d.setHours(0, 0, 0, 0)
    return d.getTime()
}

function relativeTime(ts, now) {
    var s = (now - ts) / 1000
    if (s < 45)
        return "NOW"
    if (s < 3600)
        return Math.max(1, Math.floor(s / 60)) + "M"
    if (ts >= startOfDay(now))
        return Math.floor(s / 3600) + "H"
    var d = new Date(ts)
    return pad(d.getHours()) + ":" + pad(d.getMinutes())
}

function dayLabel(ts, now) {
    var today = startOfDay(now)
    if (ts >= today)
        return "Today"

    var y = new Date(today)
    y.setDate(y.getDate() - 1)
    if (ts >= y.getTime())
        return "Yesterday"

    var d = new Date(ts)
    return DAYS[d.getDay()] + " " + d.getDate() + " " + MONTHS[d.getMonth()]
}

// The comms log shows one entry per conversation: notifications with the same app and title (a Telegram chat, a
// channel) fold together. history is newest first; so is each group's `entries`. Critical groups come first, then the
// group with the newest activity. `section` is "Priority alpha" or the day label; `newSection` marks the first group
// of each section.
function conversations(history, now) {
    var byKey = {}
    var out = []
    for (var i = 0; i < history.length; i++) {
        var e = history[i]
        var key = (e.label || e.appName || "") + "\u0000" + (e.summary || "")
        var g = byKey[key]
        if (!g) {
            g = byKey[key] = { key: key, entries: [], critical: false, timestamp: e.timestamp }
            out.push(g)
        }
        g.entries.push(e)
        if (e.critical)
            g.critical = true
        if (e.timestamp > g.timestamp)
            g.timestamp = e.timestamp
    }
    out.sort(function (a, b) {
        return ((b.critical ? 1 : 0) - (a.critical ? 1 : 0)) || (b.timestamp - a.timestamp)
    })
    for (var j = 0; j < out.length; j++) {
        out[j].section = out[j].critical ? "Priority alpha" : dayLabel(out[j].timestamp, now)
        out[j].newSection = j === 0 || out[j].section !== out[j - 1].section
    }
    return out
}

function badgeText(n) {
    if (n <= 0)
        return ""
    return n > 9 ? "9+" : String(n)
}

// Decided once, at arrival time. A popup that is suppressed now is never shown later.
// c: { centerOpen, islandOpen, dnd, urgency: "low"|"normal"|"critical", transient }
function arrivalPolicy(c) {
    var critical = c.urgency === "critical"
    var history = !c.transient

    if (c.urgency === "low")
        return { toast: false, ping: false, history: history }
    if (c.centerOpen)
        return { toast: false, ping: false, history: history }
    if (c.islandOpen)
        return { toast: false, ping: true, history: history }
    if (c.dnd && !critical)
        return { toast: false, ping: true, history: history }
    return { toast: true, ping: true, history: history }
}
