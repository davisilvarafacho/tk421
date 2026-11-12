.pragma library

// Pure helpers for the desktop widgets (widgets/DesktopWidgets.qml). No QML types, tested in tests/qml/tst_widgetlogic.qml.

var DAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
var MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October",
              "November", "December"]

function pad(n) {
    return (n < 10 ? "0" : "") + n
}

function dateKey(d) {
    return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate())
}

// ISO 8601 week number.
function isoWeek(d) {
    var t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
    t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7))
    var first = new Date(Date.UTC(t.getUTCFullYear(), 0, 1))
    return Math.ceil(((t - first) / 86400000 + 1) / 7)
}

// "Thursday, 12 November"
function dateLine(d) {
    return DAYS[d.getDay()] + ", " + d.getDate() + " " + MONTHS[d.getMonth()]
}

// "up 3 d 14 h", "up 5 h 12 min", "up 7 min"
function uptime(seconds) {
    var m = Math.floor(Math.max(0, seconds) / 60)
    var d = Math.floor(m / 1440), h = Math.floor((m % 1440) / 60), min = m % 60
    if (d > 0)
        return "up " + d + " d " + h + " h"
    if (h > 0)
        return "up " + h + " h " + min + " min"
    return "up " + min + " min"
}

// "in 28 min", "in 2 h 5 min", "in 3 h", "now"
function inMinutes(minutes) {
    if (minutes < 1)
        return "now"
    var h = Math.floor(minutes / 60), m = Math.floor(minutes % 60)
    if (h === 0)
        return "in " + m + " min"
    return "in " + h + " h" + (m > 0 ? " " + m + " min" : "")
}

function minutesOf(time) {
    var p = String(time).split(":")
    var h = Number(p[0]), m = Number(p[1])
    return isFinite(h) && isFinite(m) ? h * 60 + m : -1
}

function sortDay(list) {
    return list.slice().sort(function (a, b) {
        return (b.allday ? 1 : 0) - (a.allday ? 1 : 0) || String(a.time).localeCompare(String(b.time))
    })
}

// Today and tomorrow, each capped at `perDay` rows. Today's timed events are "done" once they started,
// the first one still ahead is "next" (with an "in N min" note), the rest "later".
function agendaDays(events, now, perDay) {
    var today = new Date(now)
    var tomorrow = new Date(now)
    tomorrow.setDate(tomorrow.getDate() + 1)
    var nowMin = today.getHours() * 60 + today.getMinutes() + today.getSeconds() / 60
    var cap = perDay || 4
    var list = Array.isArray(events) ? events : []
    var out = []

    var todays = sortDay(list.filter(function (e) { return e.date === dateKey(today) }))
    if (todays.length > 0) {
        var seenNext = false
        var rows = todays.map(function (e) {
            var start = e.allday ? -1 : minutesOf(e.time)
            var state = "later", note = e.sub || ""
            if (!e.allday && start >= 0 && start < nowMin) {
                state = "done"
            } else if (!e.allday && !seenNext) {
                seenNext = true
                state = "next"
                var when = inMinutes(start - nowMin)
                note = note !== "" ? when + " · " + note : when
            }
            return { time: e.time, title: e.title, note: note, state: state }
        })
        // Keep what is still ahead when the day is too long: drop finished events first.
        while (rows.length > cap && rows[0].state === "done")
            rows.shift()
        out.push({ label: "Today", rows: rows.slice(0, cap) })
    }

    var tomorrows = sortDay(list.filter(function (e) { return e.date === dateKey(tomorrow) }))
    if (tomorrows.length > 0)
        out.push({
            label: "Tomorrow",
            rows: tomorrows.slice(0, cap).map(function (e) {
                return { time: e.time, title: e.title, note: e.sub || "", state: "later" }
            })
        })
    return out
}

// Events from today through the next 6 days.
function weekCount(events, now) {
    var keys = {}
    for (var i = 0; i < 7; i++) {
        var d = new Date(now)
        d.setDate(d.getDate() + i)
        keys[dateKey(d)] = true
    }
    return (Array.isArray(events) ? events : []).filter(function (e) { return keys[e.date] === true }).length
}

// "Resets at 17:10", "Resets tomorrow 09:00", "Resets Monday 09:00"
function resetLabel(iso, now) {
    var t = new Date(iso)
    if (iso === "" || isNaN(t.getTime()))
        return ""
    var hm = pad(t.getHours()) + ":" + pad(t.getMinutes())
    var n = new Date(now)
    if (dateKey(t) === dateKey(n))
        return "Resets at " + hm
    n.setDate(n.getDate() + 1)
    if (dateKey(t) === dateKey(n))
        return "Resets tomorrow " + hm
    return "Resets " + DAYS[t.getDay()] + " " + hm
}

// Track time: "1:12", "1:02:03"
function clock(seconds) {
    var s = Math.max(0, Math.floor(seconds || 0))
    var h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), sec = s % 60
    return h > 0 ? h + ":" + pad(m) + ":" + pad(sec) : m + ":" + pad(sec)
}

// `df -B1 --output=used,size /` -> { used, size } in bytes, or null.
function parseDf(text) {
    var lines = String(text).trim().split("\n")
    if (lines.length < 2)
        return null
    var p = lines[lines.length - 1].trim().split(/\s+/)
    var used = Number(p[0]), size = Number(p[1])
    return isFinite(used) && isFinite(size) && size > 0 ? { used: used, size: size } : null
}

// "412 / 931 GB" (decimal gigabytes, like df -H and the drive's label)
function gbPair(used, size) {
    return Math.round(used / 1e9) + " / " + Math.round(size / 1e9) + " GB"
}

// Relative age for the comms widget: "now", "4m", "2h", else "HH:MM".
function age(ts, now) {
    var s = (now - ts) / 1000
    if (s < 45)
        return "now"
    if (s < 3600)
        return Math.max(1, Math.floor(s / 60)) + "m"
    if (s < 86400)
        return Math.floor(s / 3600) + "h"
    var d = new Date(ts)
    return pad(d.getHours()) + ":" + pad(d.getMinutes())
}

// One frame of cava's raw ascii output ("12;480;1000;...;") -> `n` levels in 0-1 (missing bands are 0).
function parseFrame(line, n, max) {
    var parts = String(line).split(";")
    var top = max || 1000
    var out = []
    for (var i = 0; i < n; i++) {
        var v = Number(parts[i])
        out.push(isFinite(v) && parts[i] !== "" ? Math.max(0, Math.min(1, v / top)) : 0)
    }
    return out
}
