.pragma library

// Pure helpers of the launcher (launcher/Launcher.qml). Tested by tests/qml/tst_launcherlogic.qml.

// The first character picks the mode: = calculate, > shell commands, @ open windows; anything else searches apps.
function parse(text) {
    const t = text || ""
    const p = t.charAt(0)
    const mode = p === "=" ? "calc" : p === ">" ? "shell" : p === "@" ? "windows" : "apps"
    return { mode: mode, body: (mode === "apps" ? t : t.slice(1)).trim() }
}

// What a click on a mode chip does to the query: adds the prefix, swaps another one, or removes its own.
function togglePrefix(text, prefix) {
    const t = text || ""
    const has = "=>@".indexOf(t.charAt(0)) >= 0 && t.length > 0
    const rest = has ? t.slice(1) : t
    return t.charAt(0) === prefix ? rest : prefix + rest
}

// Arithmetic without eval: + - * / ^ % and parentheses, decimal commas, × and ÷. null unless the whole text is a
// finished expression with a finite result.
function calc(src) {
    const t = String(src || "").replace(/\s+/g, "").replace(/×/g, "*").replace(/÷/g, "/").replace(/,/g, ".")
    if (t === "" || /[^0-9.+\-*/()%^]/.test(t))
        return null

    let i = 0
    function eat(c) {
        if (t[i] !== c)
            return false
        i++
        return true
    }
    function num() {
        const m = /^\d*\.?\d+/.exec(t.slice(i))
        if (!m)
            throw new Error("number")
        i += m[0].length
        return parseFloat(m[0])
    }
    function atom() {
        if (eat("-"))
            return -atom()
        if (eat("(")) {
            const v = sum()
            if (!eat(")"))
                throw new Error("paren")
            return v
        }
        let v = num()
        if (eat("%"))
            v /= 100
        return v
    }
    function pow() {
        const b = atom()
        return eat("^") ? Math.pow(b, pow()) : b
    }
    function prod() {
        let v = pow()
        for (;;) {
            if (eat("*"))
                v *= pow()
            else if (eat("/"))
                v /= pow()
            else
                return v
        }
    }
    function sum() {
        let v = prod()
        for (;;) {
            if (eat("+"))
                v += prod()
            else if (eat("-"))
                v -= prod()
            else
                return v
        }
    }

    try {
        const v = sum()
        return i === t.length && isFinite(v) ? parseFloat(v.toFixed(10)) : null
    } catch (e) {
        return null
    }
}

// 1234567.5 -> "1,234,567.5" (the UI is English).
function formatNumber(v) {
    const neg = v < 0
    const parts = String(Math.abs(v)).split(".")
    const whole = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",")
    return (neg ? "-" : "") + whole + (parts.length > 1 ? "." + parts[1] : "")
}

const MIN = 60e3
const HOUR = 3600e3
const DAY = 86400e3

// Short relative time for list rows: now, 12m, 5h, yesterday, 9d. "" for no time.
function ago(t, now) {
    if (!t)
        return ""
    const d = now - t
    if (d < 2 * MIN)
        return "now"
    if (d < HOUR)
        return Math.round(d / MIN) + "m"
    if (d < DAY)
        return Math.round(d / HOUR) + "h"
    if (d < 2 * DAY)
        return "yesterday"
    return Math.round(d / DAY) + "d"
}

// Long form for the detail pane: "3 min ago", "2 h ago", "yesterday", "4 days ago".
function agoLong(t, now) {
    const a = ago(t, now)
    if (a === "now")
        return "just now"
    if (a === "" || a === "yesterday")
        return a
    const n = parseInt(a)
    const unit = a.charAt(a.length - 1)
    return n + (unit === "m" ? " min ago" : unit === "h" ? " h ago" : " days ago")
}

// Desktop-entry category -> isometric object (assets/iso/<name>.svg). First match in this order wins.
const ISO = [
    ["TerminalEmulator", "desktop"], ["WebBrowser", "cloud"], ["IDE", "laptop"], ["TextEditor", "document"],
    ["Debugger", "firewall"], ["InstantMessaging", "speech"], ["Chat", "speech"], ["Email", "mail"],
    ["Recorder", "tower"], ["Audio", "tower"], ["Video", "tower"], ["FileManager", "storage"],
    ["FileTransfer", "package-module"], ["Game", "pyramid"], ["Graphics", "image"], ["Office", "document"],
    ["Settings", "function-module"], ["Development", "function-module"], ["Security", "lock"], ["System", "server"],
    ["Network", "router"]
]

function isoFor(categories) {
    const cats = categories || []
    for (const pair of ISO) {
        if (cats.indexOf(pair[0]) >= 0)
            return pair[1]
    }
    return "cube"
}

// Ranking bonus from launch history: grows slowly, so it reorders near-equal matches only
// (a substring match outranks a subsequence one by about 600).
function boost(hits) {
    return 18 * Math.log(1 + Math.max(0, hits || 0)) / Math.LN2
}

// ids of the `n` most launched entries (only ones launched at least once).
function frequent(ids, hist, n) {
    return ids.filter(id => hist[id] && hist[id].hits > 0)
        .sort((a, b) => hist[b].hits - hist[a].hits || hist[b].last - hist[a].last)
        .slice(0, n)
}

// ids of the `n` most recently launched entries that are not in `exclude`.
function recent(ids, hist, exclude, n) {
    return ids.filter(id => hist[id] && hist[id].last > 0 && exclude.indexOf(id) < 0)
        .sort((a, b) => hist[b].last - hist[a].last)
        .slice(0, n)
}

// A new history object with one more launch of `id` at time `now`.
function record(hist, id, now) {
    const out = Object.assign({}, hist)
    if (!id)
        return out
    const old = out[id] || { hits: 0, last: 0 }
    out[id] = { hits: old.hits + 1, last: now }
    return out
}

// Shell commands of the ">" mode. `run` is interpreted by Launcher.qml: ipc:<target>:<function> or power:<id>.
// `asks` ones open the power menu with the question instead of acting.
const COMMANDS = [
    { id: "lock", name: "Lock screen", hint: "Super+L", text: "Locks the session now. Unlock with your password.", icon: "lock", iso: "lock", run: "power:lock" },
    { id: "wallpaper", name: "Wallpaper picker", hint: "Super+Alt+B", text: "Opens the blast door to change the desktop wallpaper.", icon: "wallpaper", iso: "image", run: "ipc:wallpaper:toggle" },
    { id: "clipboard", name: "Clipboard archive", hint: "Super+H", text: "Copy back or paste anything from the clipboard history.", icon: "content_paste", iso: "queue", run: "ipc:clipboard:toggle" },
    { id: "comms", name: "Comms log", hint: "Super+N", text: "Shows every notification, grouped by conversation.", icon: "notifications", iso: "mailmultiple", run: "ipc:notifications:toggleCenter" },
    { id: "dnd", name: "Silence notifications", hint: "Do not disturb", text: "Popups stop; the comms log still records everything. Run again to turn it off.", icon: "notifications_paused", iso: "speech", run: "ipc:notifications:toggleDnd" },
    { id: "suspend", name: "Suspend", hint: "Sleeps now", text: "Sleeps the machine right away, like Suspend in the power menu.", icon: "bedtime", iso: "cronjob", run: "power:suspend" },
    { id: "logout", name: "Log out", hint: "Asks first", text: "Opens the power menu to confirm ending the session.", icon: "logout", iso: "user", run: "power:logout", asks: true },
    { id: "reboot", name: "Restart", hint: "Asks first", text: "Opens the power menu to confirm restarting the machine.", icon: "restart_alt", iso: "server", run: "power:reboot", asks: true },
    { id: "poweroff", name: "Power off", hint: "Asks first", text: "Opens the power menu to confirm shutting the machine down.", icon: "power_settings_new", iso: "block", run: "power:poweroff", asks: true }
]
