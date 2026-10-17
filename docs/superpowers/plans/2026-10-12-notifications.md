# Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `swaync` with a Quickshell-native notification server: island toast popups, a bell in a new toolbar capsule, and a history/DND dropdown, matching `prototypes/notifications/index.html`.

**Architecture:** One singleton (`services/Notifications.qml`) owns the D-Bus `NotificationServer`, the history, DND and the toast state. Pure rules (arrival policy, text cleaning, icon safety, time labels) live in `notifications/logic.js`, which is unit-tested with Qt Quick Test. The UI (island toast, bell, dropdown) only reads the singleton.

**Tech Stack:** Quickshell 0.3.2 (`Quickshell.Services.Notifications`, `Quickshell.Hyprland` `HyprlandFocusGrab`, `ScriptModel`), QML/Qt 6, `qmltestrunner` (Qt 6), Hyprland Lua config.

**Status 2026-10-17:** Tasks 1-5 are implemented (the dropdown became a translucent drawer and the copy became Imperial: see the spec's amendment, which wins over the code samples below). Task 6 (cutover) and Task 7 (docs, partly done in CLAUDE.md) remain.

**Spec:** `docs/superpowers/specs/2026-10-12-notifications-design.md` (read it first). Approved visual reference: `prototypes/notifications/index.html`.

## Global Constraints

- Quickshell **0.3.2**, Qt 6. Qt 6 test runner is **`/usr/lib/qt6/bin/qmltestrunner`**. `/usr/bin/qmltestrunner` is Qt 5 and does not work.
- **The running shell is the user's real desktop and hot-reloads on every save.** Write each QML file **once**, in a working state. Create leaf files before anything references them. Content-identical saves do not reload.
- **Do not commit.** CLAUDE.md: the repo has no commits and nothing is committed unless the user asks. Each task ends with a *checkpoint* instead of a commit. (If the user later asks, commit style is `feat:` / `fix:`.)
- **Never call `lock lock`.** Never grab the full screen: only `grim -g` on the exact island card, capsule or dropdown rectangle.
- Strings from outside (summary, body, app name, action text) always render with `textFormat: Text.PlainText`. Small text uses `renderType: Text.CurveRendering`.
- Palette: `Theme.imperial.*` only (`surface`, `surfaceAlt`, `text`, `muted`, `accent`, `accentDim`, `danger`, `dangerText`, `border`, `bg`). Fonts: `Theme.displayFont` (Orbitron) for labels and digits, `Theme.fontFamily` (Geist) for UI, `Theme.iconFont` for glyphs. UI copy is English.
- Motion: easing `[0.22, 1, 0.36, 1, 1, 1]` (BezierSpline), **520 ms** growing/opening, **340 ms** shrinking/closing, content fades in after **140 ms**.
- Geometry: capsules are **28 px** high, **4 px** from the top; toolbar capsule `right: 30`. Toast card **400×82**, radius **22**. Dropdown **380 px** wide, `margins.top: 40`, `margins.right: 30`, radius 24, max list height 392.
- Limits (spec): summary 120, body 600, action text 24, at most 3 actions, history 50, popup 5000 ms. (App name 40 is an addition, see below.)
- Island state priority: **open > notify (toast) > hud > media > idle**.
- New singletons must be added to `services/qmldir` or they will not resolve.
- Inside a window component, an `id` equal to a child's property name resolves to `undefined`; use distinct ids.
- `transient` (and other JS reserved words) cannot be declared as a QML property name; reading `notification.transient` is fine. Run `qmllint` and treat any `[syntax]` warning as a blocker.
- Every shell check after a save: the text after the last `Reloading configuration` line in `qs log -p /home/tk421/Development/quickshell/shell.qml` must contain no `WARN|ERROR`. **Exception:** while `swaync` still owns `org.freedesktop.Notifications`, one warning about the notification server failing to register is expected (Tasks 2–5) and is not a defect.
- Commands below are bash. `QS="qs ipc -p /home/tk421/Development/quickshell/shell.qml call"`.

## Additions beyond the spec (flag any you do not want)

1. `components/ActionButton.qml`: the outline/filled button is used by toast, dropdown items and header, so it is one shared component.
2. `status()` IPC also prints `center=<bool>` (needed to test the bell and Esc). The spec's IPC table is updated in Task 7.
3. Actions whose identifier is `default`, or whose text is blank, are not shown as buttons (apps like Firefox/Discord send a `default` action; a "Default" button is noise).
4. If a summary is empty the title falls back to the app name, then to `Notification`. Newlines in titles collapse to spaces.
5. Control characters and bidirectional override/isolate characters (U+202A–202E, U+2066–2069) are stripped from all external text, so a notification cannot reorder what the user reads. App name is also limited to 40 characters.
6. The swap animation between two toasts is opacity + vertical slide only, no blur: the existing QML island already drops the prototype's blur.
7. After a hot reload, carried-over notifications are restored as **read** and their time resets to "now" (the D-Bus object carries no arrival time).
8. The tile falls back to the desktop entry's icon also when `appIcon` was discarded (URL scheme), not only when it was empty.

## Review Focus

Input classes the spec implies but its tasks do not obviously exercise, most likely first:

1. **Emoji / non-BMP text near a truncation point** must never end in half a surrogate pair (broken glyph). Pinned by Task 1 (`test_clip_never_splits_surrogate_pair`).
2. **Bidi override and control characters in titles or app names** must be removed, not displayed or used to reorder text. Pinned by Task 1 (`test_clean_*`).
3. **Empty summary** (apps do send it) must show the app name, not a blank row. Pinned by Task 1 (`test_titleOf_*`).
4. **Apps that send only a `default` action, or actions with blank text** must not produce empty or "Default" buttons. Pinned by Task 1 (`test_pickActions_*`).
5. **An app withdraws a notification while its toast is on screen** (`CloseNotification`) must make the toast vanish and drop the history entry, without errors. Pinned by Task 6 (live `gdbus CloseNotification` step).

---

## File Structure

| File | Responsibility |
|---|---|
| `notifications/logic.js` (create) | Pure functions: `clean`, `clip`, `titleOf`, `iconSource`, `pickActions`, `relativeTime`, `dayLabel`, `badgeText`, `arrivalPolicy`, `LIMITS`, `TOAST_MS`. No QML, no state. |
| `tests/qml/tst_logic.qml` (create) | Qt Quick Test for `logic.js`. |
| `notifications/NotificationEntry.qml` (create) | One notification as the UI sees it: copied display fields, live reference, debounced app updates. |
| `services/Notifications.qml` (create) | Singleton: server, history, unread, DND, toast + countdown, centre state, IPC, mock injection. |
| `services/qmldir` (modify) | Register `Notifications`. |
| `shell.qml` (modify) | Start the service with the shell; instantiate `NotificationCenter`. |
| `bar/NotificationBell.qml`, `bar/Toolbar.qml` (create) | Bell (glyph, count, ping) and the right-hand capsule that hosts it. |
| `bar/Bar.qml` (modify) | Replace the commented tray block with `Toolbar`. |
| `components/AppTile.qml`, `components/ActionButton.qml` (create) | Shared icon tile and button. |
| `island/NotificationToast.qml` (create) | Toast content, laid out at its final 400 px width. |
| `island/Island.qml` (modify) | Notify state, hover rule, countdown line, priority. |
| `notifications/NotificationItem.qml`, `notifications/NotificationCenter.qml` (create) | Dropdown row and the dropdown window. |
| `hypr/hyprland.lua` (modify, last) | Drop `swaync` autostart, rebind `SUPER+N`. |
| `CLAUDE.md`, `tk421/TK421.md`, spec (modify) | Documentation that must follow the decision. |

---

### Task 1: Pure logic and its tests

**Files:**
- Create: `notifications/logic.js`
- Create: `tests/qml/tst_logic.qml`

**Interfaces:**
- Produces (used by every later task, imported as `import "../notifications/logic.js" as Logic` or `import "logic.js" as Logic`):
  - `Logic.LIMITS = { summary: 120, body: 600, appName: 40, actionText: 24, actions: 3, history: 50 }`, `Logic.TOAST_MS = 5000`
  - `Logic.clean(text) -> string`, `Logic.clip(text, max) -> string`
  - `Logic.titleOf(summary, appName) -> string`
  - `Logic.iconSource(appIcon) -> { kind: "none"|"name"|"path", value: string }`
  - `Logic.pickActions(raw) -> [{ index, identifier, text }]` (`raw` is any array-like of `{identifier, text}`)
  - `Logic.relativeTime(ts, now) -> string`, `Logic.dayLabel(ts, now) -> string` (`ts`, `now` are ms since epoch)
  - `Logic.badgeText(n) -> string`
  - `Logic.arrivalPolicy({ centerOpen, islandOpen, dnd, urgency: "low"|"normal"|"critical", transient }) -> { toast, ping, history }` (booleans)

- [ ] **Step 1: Write the failing test**

Create `tests/qml/tst_logic.qml`:

```qml
import QtQuick
import QtTest

import "../../notifications/logic.js" as Logic

TestCase {
    name: "NotificationLogic"

    // Monday 12 Oct 2026, 14:00 local time.
    readonly property double now: new Date(2026, 9, 12, 14, 0, 0).getTime()

    function at(day, hour, minute) {
        return new Date(2026, 9, day, hour, minute, 0).getTime()
    }

    function policy(over) {
        const base = { centerOpen: false, islandOpen: false, dnd: false, urgency: "normal", transient: false }
        for (const k in over)
            base[k] = over[k]
        return Logic.arrivalPolicy(base)
    }

    // ---- clean / clip ----
    function test_clean_handles_null_and_undefined() {
        compare(Logic.clean(null), "")
        compare(Logic.clean(undefined), "")
    }

    function test_clean_strips_control_and_bidi_characters() {
        compare(Logic.clean("a‮b\u0000c⁦d⁩e"), "abcde")
    }

    function test_clean_keeps_newline_and_tab() {
        compare(Logic.clean("a\nb\tc"), "a\nb\tc")
    }

    function test_clip_short_text_unchanged() {
        compare(Logic.clip("hello", 10), "hello")
    }

    function test_clip_truncates_with_ellipsis() {
        compare(Logic.clip("abcdefghij", 5), "abcd…")
    }

    function test_clip_never_splits_surrogate_pair() {
        const e = "😀"                      // one emoji, two UTF-16 units
        compare(Logic.clip(e + e + e, 4), e + "…")
        compare(Logic.clip(e + e + e, 5), e + e + "…")
    }

    function test_clip_tiny_limit() {
        compare(Logic.clip("abc", 1), "…")
    }

    // ---- titleOf ----
    function test_titleOf_uses_summary() {
        compare(Logic.titleOf("Build finished", "Ghostty"), "Build finished")
    }

    function test_titleOf_falls_back_to_app_name() {
        compare(Logic.titleOf("", "Ghostty"), "Ghostty")
        compare(Logic.titleOf("  \n ", "Ghostty"), "Ghostty")
    }

    function test_titleOf_falls_back_to_generic() {
        compare(Logic.titleOf("", ""), "Notification")
        compare(Logic.titleOf(undefined, null), "Notification")
    }

    function test_titleOf_collapses_newlines() {
        compare(Logic.titleOf("one\n\ntwo", "x"), "one two")
    }

    function test_titleOf_clips_to_limit() {
        compare(Logic.titleOf("x".repeat(500), "a").length, Logic.LIMITS.summary)
    }

    // ---- iconSource ----
    function test_iconSource_none() {
        compare(Logic.iconSource("").kind, "none")
        compare(Logic.iconSource(undefined).kind, "none")
        compare(Logic.iconSource(null).kind, "none")
    }

    function test_iconSource_name() {
        compare(Logic.iconSource("firefox").kind, "name")
        compare(Logic.iconSource("org.mozilla.firefox").value, "org.mozilla.firefox")
        compare(Logic.iconSource("  firefox  ").value, "firefox")
    }

    function test_iconSource_absolute_path() {
        const s = Logic.iconSource("/usr/share/icons/x.png")
        compare(s.kind, "path")
        compare(s.value, "/usr/share/icons/x.png")
    }

    function test_iconSource_rejects_any_url_scheme() {
        const bad = ["http://evil/x.png", "https://evil/x.png", "file:///etc/passwd",
                     "data:image/png;base64,AAAA", "image://icon/x", "ftp://h/x"]
        for (let i = 0; i < bad.length; i++)
            compare(Logic.iconSource(bad[i]).kind, "none", bad[i])
    }

    // ---- pickActions ----
    function test_pickActions_null_is_empty() {
        compare(Logic.pickActions(null).length, 0)
        compare(Logic.pickActions(undefined).length, 0)
    }

    function test_pickActions_skips_default_and_blank() {
        const out = Logic.pickActions([
            { identifier: "default", text: "Open" },
            { identifier: "a", text: "   " },
            { identifier: "join", text: "Join" }
        ])
        compare(out.length, 1)
        compare(out[0].identifier, "join")
        compare(out[0].index, 2)                     // index into the original list, used to invoke it
    }

    function test_pickActions_limits_to_three() {
        const raw = []
        for (let i = 0; i < 6; i++)
            raw.push({ identifier: "a" + i, text: "A" + i })
        const out = Logic.pickActions(raw)
        compare(out.length, 3)
        compare(out[2].index, 2)
    }

    function test_pickActions_clips_text() {
        const out = Logic.pickActions([{ identifier: "a", text: "x".repeat(100) }])
        compare(out[0].text.length, Logic.LIMITS.actionText)
    }

    // ---- relativeTime ----
    function test_relativeTime_now() {
        compare(Logic.relativeTime(now - 10000, now), "now")
        compare(Logic.relativeTime(now - 44000, now), "now")
    }

    function test_relativeTime_future_timestamp_is_now() {
        compare(Logic.relativeTime(now + 600000, now), "now")
    }

    function test_relativeTime_minutes() {
        compare(Logic.relativeTime(now - 45000, now), "1m")
        compare(Logic.relativeTime(now - 38 * 60000, now), "38m")
        compare(Logic.relativeTime(now - 3599000, now), "59m")
    }

    function test_relativeTime_hours_today() {
        compare(Logic.relativeTime(now - 2 * 3600000, now), "2h")
        compare(Logic.relativeTime(at(12, 0, 0), now), "14h")
    }

    function test_relativeTime_before_today_is_clock_time() {
        compare(Logic.relativeTime(at(11, 21, 30), now), "21:30")
        compare(Logic.relativeTime(at(12, 0, 0) - 60000, now), "23:59")
    }

    // ---- dayLabel ----
    function test_dayLabel() {
        compare(Logic.dayLabel(at(12, 9, 0), now), "Today")
        compare(Logic.dayLabel(at(11, 21, 30), now), "Yesterday")
        compare(Logic.dayLabel(at(9, 12, 0), now), "Fri 9 Oct")
    }

    // ---- badgeText ----
    function test_badgeText() {
        compare(Logic.badgeText(0), "")
        compare(Logic.badgeText(-3), "")
        compare(Logic.badgeText(1), "1")
        compare(Logic.badgeText(9), "9")
        compare(Logic.badgeText(10), "9+")
        compare(Logic.badgeText(99), "9+")
    }

    // ---- arrivalPolicy (the table in the spec) ----
    function test_policy_normal() {
        const p = policy({})
        verify(p.toast); verify(p.ping); verify(p.history)
    }

    function test_policy_center_open_is_silent_but_kept() {
        const p = policy({ centerOpen: true })
        verify(!p.toast); verify(!p.ping); verify(p.history)
    }

    function test_policy_island_open_pings_without_popup() {
        const p = policy({ islandOpen: true })
        verify(!p.toast); verify(p.ping); verify(p.history)
    }

    function test_policy_low_is_history_only() {
        const p = policy({ urgency: "low" })
        verify(!p.toast); verify(!p.ping); verify(p.history)
    }

    function test_policy_low_never_pings_even_when_island_open() {
        verify(!policy({ urgency: "low", islandOpen: true }).ping)
    }

    function test_policy_dnd_mutes_normal_but_pings() {
        const p = policy({ dnd: true })
        verify(!p.toast); verify(p.ping); verify(p.history)
    }

    function test_policy_dnd_does_not_mute_critical() {
        const p = policy({ dnd: true, urgency: "critical" })
        verify(p.toast); verify(p.ping)
    }

    function test_policy_critical_still_yields_to_open_centre() {
        verify(!policy({ urgency: "critical", centerOpen: true }).toast)
    }

    function test_policy_transient_pops_but_is_not_kept() {
        const p = policy({ transient: true })
        verify(p.toast); verify(!p.history)
    }

    function test_policy_transient_under_dnd_vanishes() {
        const p = policy({ transient: true, dnd: true })
        verify(!p.toast); verify(!p.history)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:
```bash
cd /home/tk421/Development/quickshell && QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml 2>&1 | tail -15
```
Expected: errors about not being able to load `logic.js` / `Logic` being undefined, and no `PASS` lines for the test functions.

- [ ] **Step 3: Write the implementation**

Create `notifications/logic.js`:

```js
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
        return "now"
    if (s < 3600)
        return Math.max(1, Math.floor(s / 60)) + "m"
    if (ts >= startOfDay(now))
        return Math.floor(s / 3600) + "h"
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
```

- [ ] **Step 4: Run the tests and make sure they pass**

Run:
```bash
cd /home/tk421/Development/quickshell && QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml 2>&1 | tail -8
```
Expected: last lines show `Totals: N passed, 0 failed, 0 skipped` and no `FAIL!`. If a test fails, fix `logic.js`, not the test, unless the test contradicts the spec.

- [ ] **Step 5: Checkpoint**

No shell reload happens in this task (nothing imports these files yet). Confirm `git status --short notifications tests` lists only the two new files. Do not commit.

---

### Task 2: Entry, service singleton, qmldir, activation

**Files:**
- Create: `notifications/NotificationEntry.qml`
- Create: `services/Notifications.qml`
- Modify: `services/qmldir`
- Modify: `shell.qml`

**Interfaces:**
- Consumes: `Logic.*` from Task 1.
- Produces (used by Tasks 3–6), all on the singleton `Notifications`:
  - Properties: `mock: bool`, `active: bool`, `history: var` (array of entries, newest first), `unreadCount: int`, `dnd: bool`, `centerOpen: bool`, `settling: bool`, `islandOpen: bool` (written by Island), `clearing: bool`, `toast: var` (entry or `null`), `toastHovered: bool`, `toastProgress: real`
  - Signal: `pinged()`
  - Functions: `setCenterOpen(bool)`, `toggleCenter()`, `closeByGrab()`, `setDnd(bool)`, `hideToast(bool markRead)`, `markRead(entry)`, `dismiss(entry)`, `clear()`, `invoke(entry, int actionIndex)`, `inject(string kind) -> string`
  - IPC target `notifications`: `toggleCenter()`, `toggleDnd()`, `clear()`, `status() -> string`, `inject(kind) -> string`
  - Entry fields (`NotificationEntry`): `uid`, `live`, `nid`, `appName`, `appIcon`, `desktopEntry`, `summary` (already a display title), `body`, `critical`, `low`, `isTransient`, `resident`, `actions` (`[{index, identifier, text}]`), `timestamp` (ms), `unread`, `dropped`

- [ ] **Step 1: Create `notifications/NotificationEntry.qml`** (nothing references it yet, so saving is safe)

```qml
import QtQuick
import Quickshell.Services.Notifications

import "logic.js" as Logic

// One notification as the UI sees it. Display fields are cleaned, length-limited copies of the live
// Notification, which its app may replace or withdraw at any moment; `live` is null once it is gone.
QtObject {
    id: entry

    required property int uid
    property var live: null

    property int nid: -1
    property string appName: ""
    property string appIcon: ""
    property string desktopEntry: ""
    property string summary: ""         // already a display title (falls back to the app name)
    property string body: ""
    property bool critical: false
    property bool low: false
    property bool isTransient: false    // not named `transient`: that is a reserved word in QML
    property bool resident: false
    property var actions: []            // [{ index, identifier, text }]; index points into live.actions
    property double timestamp: Date.now()
    property bool unread: true
    property bool dropped: false        // removed by the service: ignore anything else that happens to it

    signal updated()                    // the app replaced or edited it
    signal withdrawn()                  // the app closed it

    function refresh() {
        const n = live
        if (!n)
            return

        nid = n.id
        appName = Logic.clip(n.appName, Logic.LIMITS.appName)
        appIcon = n.appIcon
        desktopEntry = n.desktopEntry
        summary = Logic.titleOf(n.summary, n.appName)
        body = Logic.clip(n.body, Logic.LIMITS.body)
        critical = n.urgency === NotificationUrgency.Critical
        low = n.urgency === NotificationUrgency.Low
        isTransient = n.transient === true || n.mockTransient === true      // reading n.transient is fine; declaring it is not
        resident = n.resident
        actions = Logic.pickActions(n.actions)
    }

    // Property changes arrive one at a time; one timer turns a replacement into a single update.
    property Timer debounce: Timer {
        interval: 40
        onTriggered: {
            entry.refresh()
            entry.updated()
        }
    }

    property Connections watcher: Connections {
        target: entry.live
        ignoreUnknownSignals: true

        function onSummaryChanged() { entry.debounce.restart() }
        function onBodyChanged() { entry.debounce.restart() }
        function onAppIconChanged() { entry.debounce.restart() }
        function onUrgencyChanged() { entry.debounce.restart() }
        function onActionsChanged() { entry.debounce.restart() }
        function onClosed(reason) { entry.withdrawn() }
    }
}
```

- [ ] **Step 2: Lint the entry**

Run: `cd /home/tk421/Development/quickshell && /usr/lib/qt6/bin/qmllint -I /usr/lib/qt6/qml notifications/NotificationEntry.qml 2>&1 | grep -E "Error|syntax|incompatible-type|unresolved|import\]" || echo "lint clean"`
Expected: `lint clean`.

- [ ] **Step 3: Create `services/Notifications.qml`**

```qml
pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick

import "../notifications"
import "../notifications/logic.js" as Logic

// Notification daemon of the shell. Owns the D-Bus server, the history, Do Not Disturb and the popup (toast).
// The UI never touches Notification objects, it reads this singleton.
// Spec: docs/superpowers/specs/2026-10-12-notifications-design.md
Singleton {
    id: root

    // true: the D-Bus server is not expected to own the name yet (swaync still runs) and `inject` fills the UI
    // with fake notifications. Switched to false at cutover (plan, Task 6).
    property bool mock: true

    // Referenced from shell.qml so the D-Bus server starts with the shell instead of on first use.
    readonly property bool active: true

    property var history: []            // NotificationEntry, newest first
    property int unreadCount: 0
    property bool dnd: false
    property bool centerOpen: false
    property bool settling: false       // centre just closed: unread flags clear after its close animation
    property bool islandOpen: false     // written by Island: an open island suppresses popups
    property bool clearing: false       // clear() just ran, lets the list stagger its exit

    property var toast: null            // the entry shown as a popup, or null
    property bool toastHovered: false
    property real toastProgress: 1      // 1 -> 0 over the popup's life

    property int lastUid: 0
    property int mockId: 100000
    property double grabClosedAt: 0
    property double settleCutoff: 0

    signal pinged()

    // ---- bookkeeping ----

    function recount() {
        unreadCount = history.reduce((n, e) => n + (e.unread ? 1 : 0), 0)
    }

    function setHistory(list) {
        history = list
        recount()
    }

    function urgencyOf(entry) {
        return entry.critical ? "critical" : entry.low ? "low" : "normal"
    }

    function newEntry(n) {
        const e = entryComponent.createObject(root, { uid: ++lastUid, live: n })
        e.refresh()
        e.updated.connect(() => root.arrive(e))
        e.withdrawn.connect(() => root.forget(e))
        return e
    }

    // ---- arrivals ----

    function accept(n) {
        n.tracked = true

        const known = history.find(e => e.nid === n.id)
        if (known) {                                    // the app replaced its own notification
            known.live = n
            known.debounce.restart()
            return
        }

        const entry = newEntry(n)
        if (n.lastGeneration) {                         // carried over a hot reload: restore it, never announce it
            entry.unread = false
            setHistory([entry].concat(history))
            return
        }
        arrive(entry)
    }

    // Popup / ping / history are decided here, once. A suppressed popup is never shown later.
    function arrive(entry) {
        if (entry.dropped)
            return

        entry.unread = true
        entry.timestamp = Date.now()

        const p = Logic.arrivalPolicy({
            centerOpen: centerOpen,
            islandOpen: islandOpen,
            dnd: dnd,
            urgency: urgencyOf(entry),
            transient: entry.isTransient
        })

        const list = history.filter(e => e !== entry)
        if (p.history) {
            list.unshift(entry)
            while (list.length > Logic.LIMITS.history)
                retire(list.pop())
        }
        setHistory(list)

        if (p.toast)
            showToast(entry)
        else if (!p.history)
            retire(entry)                               // transient and not shown: nothing keeps it

        if (p.ping)
            pinged()
    }

    // ---- removal ----

    // Release an entry for good: hide its popup, tell the app (unless the app already closed it), free it later.
    // destroy() is delayed because list rows may still be animating out.
    function retire(entry) {
        if (!entry || entry.dropped)
            return
        entry.dropped = true

        if (toast === entry)
            clearToast()

        const n = entry.live
        entry.live = null
        if (n) {
            // Read before dismiss(): a real Notification is destroyed as soon as its `closed` handlers return.
            const isMock = n.isMock === true
            n.dismiss()
            if (isMock)
                n.destroy(1000)
        }
        entry.destroy(1000)
    }

    function remove(entry) {
        if (!entry || entry.dropped)
            return
        setHistory(history.filter(e => e !== entry))
        retire(entry)
    }

    function dismiss(entry) {
        remove(entry)
    }

    // The app closed it (CloseNotification): it is gone from history and from the popup.
    function forget(entry) {
        entry.live = null
        remove(entry)
    }

    function clear() {
        const old = history
        clearing = true
        clearTimer.restart()
        setHistory([])
        old.forEach(e => retire(e))
    }

    function markRead(entry) {
        if (!entry || entry.dropped)
            return
        entry.unread = false
        recount()
    }

    function invoke(entry, index) {
        if (!entry || entry.dropped || !entry.live)
            return

        const a = entry.actions[index]
        if (!a)
            return

        const resident = entry.resident
        entry.live.actions[a.index].invoke()
        if (resident) {
            hideToast(true)
            markRead(entry)
        } else {
            remove(entry)
        }
    }

    // ---- popup ----

    function showToast(entry) {
        const prev = toast
        toast = entry
        toastHovered = false
        toastProgress = 1

        if (entry.critical)
            countdown.stop()                            // critical alerts stay until dismissed
        else
            countdown.restart()

        if (prev && prev !== entry && prev.isTransient)
            retire(prev)
    }

    function clearToast() {
        countdown.stop()
        const e = toast
        toast = null
        toastHovered = false
        toastProgress = 1
        return e
    }

    // markRead: the user dismissed it (click or x). Timing out leaves it unread.
    function hideToast(markRead) {
        const e = clearToast()
        if (!e)
            return
        if (e.isTransient)
            retire(e)
        else if (markRead)
            root.markRead(e)
    }

    // ---- DND and centre ----

    function setDnd(on) {
        dnd = on
        if (on && toast && !toast.critical)
            hideToast(false)
    }

    function setCenterOpen(open) {
        if (open === centerOpen)
            return
        centerOpen = open

        if (open) {
            settleTimer.stop()
            settling = false
            hideToast(true)
        } else {
            settleCutoff = Date.now()
            settling = true
            settleTimer.restart()
        }
    }

    function toggleCenter() {
        if (!centerOpen && Date.now() - grabClosedAt < 400)
            return                                      // the outside click that just closed it must not reopen it
        setCenterOpen(!centerOpen)
    }

    function closeByGrab() {
        if (!centerOpen)
            return
        grabClosedAt = Date.now()
        setCenterOpen(false)
    }

    onIslandOpenChanged: {
        if (islandOpen)
            hideToast(false)
    }

    // ---- mock ----

    function mockSpec(kind) {
        const act = (id, text) => ({ identifier: id, text: text, invoke: () => console.log("mock action:", id) })

        switch (kind) {
        case "normal":
            return { appName: "Ghostty", appIcon: "com.mitchellh.ghostty", summary: "Build finished",
                     body: "quickshell · release build completed in 42 s with 0 warnings.",
                     urgency: NotificationUrgency.Normal, actions: [] }
        case "actions":
            return { appName: "Calendar", appIcon: "x-office-calendar", summary: "Daily starts in 10 minutes",
                     body: "Google Meet · 10:00 · 30 min · 6 attendees",
                     urgency: NotificationUrgency.Normal, actions: [act("join", "Join"), act("snooze", "Snooze")] }
        case "critical":
            return { appName: "System", appIcon: "dialog-warning", summary: "Disk space low",
                     body: "/ is 94% full on nvme0n1p2. Free some space before the next system update.",
                     urgency: NotificationUrgency.Critical, actions: [act("open", "Open")] }
        case "low":
            return { appName: "Updates", appIcon: "system-software-update", summary: "14 updates available",
                     body: "linux, mesa, hyprland and 11 more packages",
                     urgency: NotificationUrgency.Low, actions: [] }
        case "long":
            return { appName: "Chat", appIcon: "", summary: "A very long summary ".repeat(12),
                     body: "Lorem ipsum dolor sit amet. ".repeat(60),
                     urgency: NotificationUrgency.Normal, actions: [act("a", "One"), act("b", "Two"), act("c", "Three"), act("d", "Four")] }
        default:
            return null
        }
    }

    function inject(kind) {
        if (!mock)
            return "mock is off"

        const spec = mockSpec(kind)
        if (!spec)
            return "unknown kind, use: normal actions critical low long"

        const n = mockComponent.createObject(root, Object.assign({ id: ++mockId }, spec))
        accept(n)
        return "ok"
    }

    // ---- parts ----

    Component {
        id: entryComponent

        NotificationEntry {}
    }

    // Stand-in for a Notification, so the UI can be exercised without D-Bus.
    Component {
        id: mockComponent

        QtObject {
            property bool isMock: true
            property int id: 0
            property string appName: ""
            property string appIcon: ""
            property string desktopEntry: ""
            property string summary: ""
            property string body: ""
            property int urgency: NotificationUrgency.Normal
            property var actions: []
            property bool mockTransient: false      // a real Notification has `transient`; a QML property cannot be named that
            property bool resident: false
            property bool lastGeneration: false
            property bool tracked: false

            signal closed(int reason)

            function dismiss() {
                closed(1)
            }
        }
    }

    NotificationServer {
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: false
        inlineReplySupported: false

        onNotification: n => root.accept(n)
    }

    // One animation is both the popup timeout and the line that drains along the island's bottom edge.
    NumberAnimation {
        id: countdown

        target: root
        property: "toastProgress"
        from: 1
        to: 0
        duration: Logic.TOAST_MS
        paused: root.toastHovered
        onFinished: root.hideToast(false)
    }

    Timer {
        id: settleTimer
        interval: 360

        onTriggered: {
            root.history.forEach(e => {
                if (e.timestamp <= root.settleCutoff)
                    e.unread = false
            })
            root.settling = false
            root.recount()
        }
    }

    Timer {
        id: clearTimer
        interval: 700
        onTriggered: root.clearing = false
    }

    IpcHandler {
        target: "notifications"

        function toggleCenter(): void {
            root.toggleCenter()
        }

        function toggleDnd(): void {
            root.setDnd(!root.dnd)
        }

        function clear(): void {
            root.clear()
        }

        function status(): string {
            return root.unreadCount + "/" + root.history.length + " dnd=" + root.dnd
                + " toast=" + (root.toast !== null) + " center=" + root.centerOpen
        }

        function inject(kind: string): string {
            return root.inject(kind)
        }
    }
}
```

- [ ] **Step 4: Lint the service**

Run: `cd /home/tk421/Development/quickshell && /usr/lib/qt6/bin/qmllint -I /usr/lib/qt6/qml services/Notifications.qml 2>&1 | grep -E "Error|syntax|incompatible-type|unresolved|import\]" | grep -v "not declared as singleton" || echo "lint clean"`
Expected: `lint clean`. Fix any reported syntax or type error before continuing (the next step reloads the real shell).

- [ ] **Step 5: Register the singleton**

Append to `services/qmldir` (the file currently ends with `SystemStats SystemStats.qml`; keep all existing lines):

```
singleton Notifications Notifications.qml
```

Verify: `cat /home/tk421/Development/quickshell/services/qmldir` shows five lines, the last one the new singleton.

- [ ] **Step 6: Start the service with the shell**

Replace `shell.qml` entirely (single save):

```qml
import Quickshell
import QtQuick
import "bar"
import "island"
import "lock"
import "services"

ShellRoot {
    // Referencing the service starts its D-Bus notification server with the shell instead of on first use.
    property bool notificationsActive: Notifications.active

    SystemStats {
        id: systemStats
    }

    Bar {}
    Island {}
    Lock {}
}
```

- [ ] **Step 7: Verify the service through IPC**

Run (wait ~2 s after the save for the reload):
```bash
cd /home/tk421/Development/quickshell
QS="qs ipc -p /home/tk421/Development/quickshell/shell.qml call"
qs log -p /home/tk421/Development/quickshell/shell.qml | awk '/Reloading configuration/{n=0; next} {n++; l[n]=$0} END{for(i=1;i<=n;i++) print l[i]}' | grep -E "WARN|ERROR"
$QS notifications status
$QS notifications inject normal
$QS notifications inject actions
$QS notifications inject critical
$QS notifications inject low
$QS notifications inject bogus
$QS notifications status
$QS notifications toggleDnd; $QS notifications status
$QS notifications toggleDnd
$QS notifications clear; $QS notifications status
```
Expected:
- The log check prints at most one line about the notification server failing to register (swaync owns the name). Any other `WARN|ERROR` (QML type or import errors) is a defect to fix.
- First `status`: `0/0 dnd=false toast=false center=false`.
- The four valid injects print `ok`; `bogus` prints `unknown kind, use: normal actions critical low long`.
- Second `status`: `4/4 dnd=false toast=true center=false`. Four entries, all unread (`low` is history-only but still counts as unread); `toast=true` because the last arrival, the critical one, is sticky and never times out.
- After `toggleDnd`: `dnd=true`; toggled back `dnd=false`.
- After `clear`: `0/0 dnd=false toast=false center=false` (clearing retires the critical toast too).

- [ ] **Step 8: Checkpoint**

`git status --short` shows the new and modified files. No commit.

---

### Task 3: Toolbar capsule and bell

**Files:**
- Create: `bar/NotificationBell.qml`
- Create: `bar/Toolbar.qml`
- Modify: `bar/Bar.qml` (replace the commented tray block lines 112–179)

**Interfaces:**
- Consumes: `Notifications.unreadCount`, `.centerOpen`, `.settling`, `.dnd`, `.toggleCenter()`, signal `.pinged()` (Task 2); `Logic.badgeText` (Task 1).
- Produces: `Toolbar` (a `Rectangle` capsule, 28 px high) that later items join by adding children to its `Row`.

- [ ] **Step 1: Create `bar/NotificationBell.qml`**

```qml
import QtQuick

import "../notifications/logic.js" as Logic
import "../services"
import "../theme"

// Bell of the toolbar: glyph, unread count, and a ring that pulses when something arrives.
Item {
    id: bell

    readonly property var c: Theme.imperial
    readonly property string badge: Notifications.centerOpen || Notifications.settling
        ? "" : Logic.badgeText(Notifications.unreadCount)
    readonly property bool lit: area.containsMouse || Notifications.centerOpen

    implicitWidth: 10 + glyph.implicitWidth + (badge !== "" ? 5 + count.implicitWidth : 0)
    implicitHeight: 22

    Behavior on implicitWidth {
        NumberAnimation { duration: 200 }
    }

    onBadgeChanged: {
        if (badge !== "")
            roll.restart()
    }

    Connections {
        target: Notifications

        function onPinged() {
            ping.restart()
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: bell.c.surfaceAlt
        opacity: bell.lit ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 140 }
        }
    }

    // One accent ring when a notification arrives.
    Rectangle {
        id: ring

        anchors.fill: parent
        anchors.margins: -1
        radius: 9
        color: "transparent"
        border.width: 1
        border.color: bell.c.accent
        opacity: 0
    }

    ParallelAnimation {
        id: ping

        NumberAnimation { target: ring; property: "opacity"; from: 0.9; to: 0; duration: 900 }
        NumberAnimation {
            target: ring
            property: "scale"
            from: 1
            to: 1.6
            duration: 900
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
        }
    }

    Text {
        id: glyph

        x: 5
        anchors.verticalCenter: parent.verticalCenter
        // Font Awesome bell / bell-slash from the Symbols Nerd Font.
        text: Notifications.dnd ? "" : ""
        color: bell.lit ? bell.c.text : "#B5BAC3"
        renderType: Text.CurveRendering
        font.family: Theme.iconFont
        font.pixelSize: 14

        Behavior on color {
            ColorAnimation { duration: 140 }
        }
    }

    Text {
        id: count

        property real rise: 0
        property real pop: 1

        x: 5 + glyph.implicitWidth + 5
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 1 + rise      // Orbitron's digits sit ~1px high at this size
        opacity: (bell.badge !== "" ? 1 : 0) * pop
        text: bell.badge
        textFormat: Text.PlainText
        color: Notifications.dnd ? bell.c.muted : bell.c.text
        renderType: Text.CurveRendering
        font.family: Theme.displayFont
        font.pixelSize: 10
        font.weight: Font.Medium
        font.letterSpacing: 0.4
    }

    // The new digit rises in.
    ParallelAnimation {
        id: roll

        NumberAnimation {
            target: count
            property: "rise"
            from: 6
            to: 0
            duration: 280
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
        }
        NumberAnimation { target: count; property: "pop"; from: 0; to: 1; duration: 280 }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Notifications.toggleCenter()
    }
}
```

- [ ] **Step 2: Create `bar/Toolbar.qml`**

```qml
import QtQuick

import "../theme"

// Right-hand capsule of the bar, the mirror of the CPU/RAM/GPU capsule. Items are added to the Row:
// notifications now; network, Bluetooth and power get their own specs.
Rectangle {
    id: toolbar

    implicitWidth: row.implicitWidth + 10
    implicitHeight: 28
    radius: 14

    color: Theme.imperial.surface
    border.width: 1
    border.color: Theme.imperial.border

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 2

        NotificationBell {}
    }
}
```

- [ ] **Step 3: Lint both files**

Run:
```bash
cd /home/tk421/Development/quickshell && for f in bar/NotificationBell.qml bar/Toolbar.qml; do /usr/lib/qt6/bin/qmllint -I /usr/lib/qt6/qml $f 2>&1 | grep -E "Error|syntax|incompatible-type|unresolved|import\]"; done; echo "lint done"
```
Expected: only `lint done`.

- [ ] **Step 4: Replace the commented tray block in `bar/Bar.qml` with the toolbar (single save)**

Run:
```bash
cd /home/tk421/Development/quickshell && python3 - <<'PY'
path = "bar/Bar.qml"
s = open(path).read()

start = s.index("    // Grupo de status à direita")
end = s.index("    */", start) + len("    */\n")

new = """    // Toolbar capsule (right). Notifications first; network, Bluetooth and power join it later.
    Toolbar {
        anchors {
            right: parent.right
            top: parent.top
            rightMargin: 30
            topMargin: 4     // same top edge and height as the left capsules
        }
    }
"""
s = s[:start] + new + s[end:]
open(path, "w").write(s)
PY
sed -n 105,135p bar/Bar.qml
```
Expected: the old commented `systemTray` block is gone, the `Toolbar { ... }` block sits where it was, and `ControlPanel { id: controlPanel ... }` is still present after it.

- [ ] **Step 5: Verify the bell**

Run (after the reload):
```bash
cd /home/tk421/Development/quickshell
QS="qs ipc -p /home/tk421/Development/quickshell/shell.qml call"
qs log -p /home/tk421/Development/quickshell/shell.qml | awk '/Reloading configuration/{n=0; next} {n++; l[n]=$0} END{for(i=1;i<=n;i++) print l[i]}' | grep -E "WARN|ERROR"
SHOTS=$(mktemp -d); echo $SHOTS
grim -g "2470,4 62x28" $SHOTS/bell-0.png
$QS notifications inject low; $QS notifications inject low; $QS notifications inject low
sleep 0.4; grim -g "2470,4 62x28" $SHOTS/bell-3.png
$QS notifications toggleDnd; sleep 0.4; grim -g "2470,4 62x28" $SHOTS/bell-dnd.png
$QS notifications toggleDnd; $QS notifications clear
```
Then Read the three PNGs. Expected: `bell-0.png` shows a capsule with a bell and no digit; `bell-3.png` shows the bell followed by `3` in Orbitron and a wider capsule; `bell-dnd.png` shows the slashed bell with the `3` muted. (Region x is 2560 − 30 − capsule width; if the capsule is cut off, widen the region by 20 px to the left. Capture only that strip.) Log check: only the expected server-registration warning, nothing else.

- [ ] **Step 6: Checkpoint**

`status` after the last command prints `0/0 dnd=false ...`. No commit.

---

### Task 4: Shared tile and button, toast, island changes

**Files:**
- Create: `components/AppTile.qml`
- Create: `components/ActionButton.qml`
- Create: `island/NotificationToast.qml`
- Modify: `island/Island.qml`

**Interfaces:**
- Consumes: everything `Notifications.*` listed in Task 2 (`toast`, `toastHovered`, `toastProgress`, `hideToast`, `invoke`, `islandOpen`); `Logic.iconSource` (Task 1).
- Produces:
  - `AppTile { appIcon: string, desktopEntry: string, critical: bool }` (size set by the user via `width`/`height`)
  - `ActionButton { text: string, primary: bool, danger: bool; signal clicked() }` (28 px high, `implicitWidth` from the label)
  - `NotificationToast { entry: var, active: bool, expanded: bool; readonly targetHeight: real }` (fixed `width: 400`)

- [ ] **Step 1: Create `components/AppTile.qml`**

```qml
import QtQuick
import Quickshell

import "../notifications/logic.js" as Logic
import "../theme"

// Rounded-square tile holding an app's icon (toast: 40 px, dropdown rows: 32 px).
Rectangle {
    id: tile

    readonly property var c: Theme.imperial

    property string appIcon: ""
    property string desktopEntry: ""
    property bool critical: false

    // The icon name or path from the notification; if it is missing or was rejected, the desktop entry's icon.
    readonly property var icon: {
        const own = Logic.iconSource(appIcon)
        if (own.kind !== "none")
            return own
        if (desktopEntry !== "") {
            const de = DesktopEntries.heuristicLookup(desktopEntry)
            if (de && de.icon)
                return Logic.iconSource(de.icon)
        }
        return own
    }

    readonly property string source: icon.kind === "path" ? icon.value
        : icon.kind === "name" ? Quickshell.iconPath(icon.value, true) : ""

    color: c.surfaceAlt
    radius: 8
    border.width: 1
    border.color: critical ? c.danger : c.border

    Image {
        id: image

        anchors.centerIn: parent
        width: Math.round(parent.width * 0.55)
        height: width
        source: tile.source
        sourceSize: Qt.size(width * 2, height * 2)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        visible: status === Image.Ready
    }

    // Font Awesome bell, shown when there is no usable icon.
    Text {
        anchors.centerIn: parent
        visible: !image.visible
        text: ""
        color: tile.critical ? tile.c.dangerText : tile.c.text
        renderType: Text.CurveRendering
        font.family: Theme.iconFont
        font.pixelSize: Math.round(tile.width * 0.42)
    }
}
```

- [ ] **Step 2: Create `components/ActionButton.qml`**

```qml
import QtQuick

import "../theme"

// Outline button with an Orbitron label. `primary` fills it; `danger` makes the filled one red.
// Same look as the island's "Today" button.
Rectangle {
    id: button

    readonly property var c: Theme.imperial

    property string text: ""
    property bool primary: false
    property bool danger: false

    signal clicked()

    implicitWidth: label.implicitWidth + 24
    implicitHeight: 28
    radius: 8

    color: primary ? (danger ? c.danger : c.text) : "transparent"
    border.width: 1
    border.color: area.containsMouse ? c.accent : (primary ? (danger ? c.danger : c.text) : c.border)

    Behavior on border.color {
        ColorAnimation { duration: 140 }
    }

    Text {
        id: label

        anchors.centerIn: parent
        anchors.verticalCenterOffset: 1      // Orbitron's digits sit ~1px high at this size
        text: button.text
        textFormat: Text.PlainText
        color: button.primary ? (button.danger ? button.c.text : button.c.bg)
            : (area.containsMouse ? button.c.text : button.c.muted)
        renderType: Text.CurveRendering
        font.family: Theme.displayFont
        font.pixelSize: 10
        font.weight: Font.Medium
        font.letterSpacing: 1.6
        font.capitalization: Font.AllUppercase

        Behavior on color {
            ColorAnimation { duration: 140 }
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
```

- [ ] **Step 3: Create `island/NotificationToast.qml`**

```qml
import QtQuick

import "../components"
import "../services"
import "../theme"

// Toast content for the island card. It is laid out at its final 400 px width and clipped by the growing card:
// laid out at the animated width the text would wrap and the expanded height would be wrong.
Item {
    id: toast

    readonly property var c: Theme.imperial

    property var entry: null            // Notifications.toast
    property bool active: false         // the island is in its notify state
    property bool expanded: false       // hovered: three-line body and action buttons

    // What is on screen. Follows `entry`; while a toast is up and another arrives it swaps with an animation.
    property var shown: null
    readonly property bool critical: shown?.critical ?? false
    readonly property bool hasActions: (shown?.actions.length ?? 0) > 0

    readonly property real targetHeight: expanded
        ? 14 + 14 + 3 + 20 + 1 + bodyText.implicitHeight + (hasActions ? 10 + 28 : 0) + 14
        : 82

    width: 400
    height: targetHeight

    onEntryChanged: {
        if (!entry)
            return
        if (active && shown && shown !== entry)
            swap.restart()
        else
            shown = entry
    }

    SequentialAnimation {
        id: swap

        ParallelAnimation {
            NumberAnimation { target: content; property: "opacity"; to: 0; duration: 200 }
            NumberAnimation { target: content; property: "y"; to: -8; duration: 200; easing.type: Easing.InQuad }
        }
        ScriptAction {
            script: {
                toast.shown = toast.entry
                content.y = 10
            }
        }
        ParallelAnimation {
            NumberAnimation { target: content; property: "opacity"; to: 1; duration: 460 }
            NumberAnimation {
                target: content
                property: "y"
                to: 0
                duration: 460
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
            }
        }
    }

    Item {
        id: content

        width: parent.width
        height: parent.height

        // Click anywhere on the toast: hide the popup, keep it in history, mark it read.
        MouseArea {
            anchors.fill: parent
            onClicked: Notifications.hideToast(true)
        }

        AppTile {
            x: 16
            y: 14
            width: 40
            height: 40
            appIcon: toast.shown?.appIcon ?? ""
            desktopEntry: toast.shown?.desktopEntry ?? ""
            critical: toast.critical
        }

        Text {
            x: 68
            y: 14
            width: 284 - timeText.implicitWidth - 8
            height: 14
            verticalAlignment: Text.AlignVCenter
            text: toast.shown?.appName ?? ""
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: toast.critical ? toast.c.dangerText : toast.c.muted
            renderType: Text.CurveRendering
            font.family: Theme.displayFont
            font.pixelSize: 10
            font.weight: Font.Medium
            font.letterSpacing: 1.6
            font.capitalization: Font.AllUppercase
        }

        Text {
            id: timeText

            x: 68 + 284 - implicitWidth
            y: 14
            height: 14
            verticalAlignment: Text.AlignVCenter
            text: toast.critical ? "Critical" : "now"
            color: toast.critical ? toast.c.dangerText : toast.c.muted
            renderType: Text.CurveRendering
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }

        Text {
            x: 68
            y: 31
            width: 284
            height: 20
            verticalAlignment: Text.AlignVCenter
            text: toast.shown?.summary ?? ""
            textFormat: Text.PlainText
            elide: Text.ElideRight
            maximumLineCount: 1
            color: toast.c.text
            renderType: Text.CurveRendering
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.weight: Font.Medium
        }

        Text {
            id: bodyText

            x: 68
            y: 52
            width: 284
            text: toast.shown?.body ?? ""
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            maximumLineCount: toast.expanded ? 3 : 1
            elide: Text.ElideRight
            lineHeightMode: Text.FixedHeight
            lineHeight: 16
            color: toast.c.muted
            renderType: Text.CurveRendering
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }

        Row {
            x: 68
            y: bodyText.y + bodyText.implicitHeight + 10
            spacing: 6
            visible: toast.expanded && toast.hasActions

            Repeater {
                model: toast.shown?.actions ?? []

                delegate: ActionButton {
                    required property var modelData
                    required property int index

                    text: modelData.text
                    primary: index === 0
                    danger: toast.critical
                    onClicked: Notifications.invoke(toast.shown, index)
                }
            }
        }

        // Dismiss: hides the popup only, the entry stays in history.
        Item {
            x: 364
            y: 14
            width: 24
            height: 24
            opacity: toast.expanded ? 1 : 0

            Behavior on opacity {
                NumberAnimation { duration: 160 }
            }

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: toast.c.surfaceAlt
                border.width: 1
                border.color: toast.c.border
                opacity: closeArea.containsMouse ? 1 : 0
            }

            Text {
                anchors.centerIn: parent
                text: "×"
                color: closeArea.containsMouse ? toast.c.text : toast.c.muted
                renderType: Text.CurveRendering
                font.family: Theme.fontFamily
                font.pixelSize: 16
            }

            MouseArea {
                id: closeArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Notifications.hideToast(true)
            }
        }
    }
}
```

- [ ] **Step 4: Lint the three new files**

Run:
```bash
cd /home/tk421/Development/quickshell && for f in components/AppTile.qml components/ActionButton.qml island/NotificationToast.qml; do echo "== $f"; /usr/lib/qt6/bin/qmllint -I /usr/lib/qt6/qml $f 2>&1 | grep -E "Error|syntax|incompatible-type|unresolved|import\]"; done; echo "lint done"
```
Expected: no lines under the three headings. Fix anything reported before touching `Island.qml`, because `Island.qml` imports these and a failure there takes the island down on the live desktop.

- [ ] **Step 5: Patch `island/Island.qml` (single save)**

Run:
```bash
cd /home/tk421/Development/quickshell && python3 - <<'PY'
path = "island/Island.qml"
s = open(path).read()

patches = [
    # header comment
    ("Priority: open > hud > media > idle.",
     "Priority: open > notify (toast) > hud > media > idle.", 1),

    # state flag
    ("""    readonly property bool open: hoverOpen || pinned
    readonly property bool playing: Media.playing
""",
     """    readonly property bool open: hoverOpen || pinned
    readonly property bool playing: Media.playing
    readonly property bool notify: Notifications.toast !== null && !open
""", 1),

    # timers and the service binding
    ("""    Timer {
        id: closeTimer
        interval: 180
        onTriggered: win.hoverOpen = false
    }
""",
     """    Timer {
        id: closeTimer
        interval: 180
        onTriggered: win.hoverOpen = false
    }

    Timer {
        id: toastLeaveTimer
        interval: 180
        onTriggered: Notifications.toastHovered = false
    }

    // The notification service decides at arrival time whether a popup may show; an open island suppresses it.
    Binding {
        target: Notifications
        property: "islandOpen"
        value: win.open
    }
""", 1),

    # hover: a toast keeps the hover for itself
    ("""        HoverHandler {
            onHoveredChanged: {
                if (hovered) {
                    closeTimer.stop()
                    win.hoverOpen = true
                } else {
                    closeTimer.restart()
                }
            }
        }
""",
     """        HoverHandler {
            onHoveredChanged: {
                if (hovered) {
                    closeTimer.stop()
                    toastLeaveTimer.stop()
                    if (win.notify)
                        Notifications.toastHovered = true       // hovering a toast pauses and expands it
                    else
                        win.hoverOpen = true
                } else {
                    closeTimer.restart()
                    toastLeaveTimer.restart()
                }
            }
        }
""", 1),

    # card geometry
    ("""        width: win.open ? 748 : win.hud ? 300 : win.playing ? 168 : 108
        height: win.open ? 424 : win.hud ? 44 : 28
        radius: win.open ? 24 : height / 2
        color: win.c.surface
        border.width: 1
        border.color: win.c.border
        clip: true

        Behavior on width { Ease { duration: win.open ? 520 : 340 } }
        Behavior on height { Ease { duration: win.open ? 520 : 340 } }
        Behavior on radius { Ease { duration: win.open ? 520 : 340 } }
""",
     """        width: win.open ? 748 : win.notify ? 400 : win.hud ? 300 : win.playing ? 168 : 108
        height: win.open ? 424 : win.notify ? toastView.targetHeight : win.hud ? 44 : 28
        radius: win.open ? 24 : win.notify ? 22 : height / 2
        color: win.c.surface
        border.width: 1
        border.color: win.notify && (Notifications.toast?.critical ?? false) ? win.c.danger : win.c.border
        clip: true

        Behavior on width { Ease { duration: win.open || win.notify ? 520 : 340 } }
        Behavior on height { Ease { duration: win.open || win.notify ? 520 : 340 } }
        Behavior on radius { Ease { duration: win.open || win.notify ? 520 : 340 } }
        Behavior on border.color { ColorAnimation { duration: 200 } }
""", 1),

    # media pill art and equalizer yield to the toast (two identical lines)
    ("opacity: win.playing && !win.open && !win.hud ? 1 : 0",
     "opacity: win.playing && !win.open && !win.hud && !win.notify ? 1 : 0", 2),

    # clock fades out during a toast, like it does for the HUD
    ("opacity: win.hud && !win.open ? 0 : 1",
     "opacity: (win.hud || win.notify) && !win.open ? 0 : 1", 1),

    # HUD yields to the toast
    ("opacity: win.hud && !win.open ? 1 : 0",
     "opacity: win.hud && !win.open && !win.notify ? 1 : 0", 1),

    # toast content and countdown line, before the expanded body
    ("        // Expanded body: calendar | agenda + media.\n",
     """        // Notification toast. Content is laid out at its final width and clipped by the card.
        NotificationToast {
            id: toastView

            entry: Notifications.toast
            active: win.notify
            expanded: Notifications.toastHovered
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            opacity: win.notify ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: win.notify ? 120 : 0 }
                    NumberAnimation { duration: win.notify ? 280 : 120 }
                }
            }
        }

        // Auto-dismiss countdown: drains along the card's bottom edge while a non-critical toast is up.
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            height: 2
            width: parent.width * Notifications.toastProgress
            color: win.c.accent
            visible: win.notify && !(Notifications.toast?.critical ?? true)
        }

        // Expanded body: calendar | agenda + media.
""", 1),
]

for old, new, count in patches:
    found = s.count(old)
    assert found == count, "expected %d match(es), found %d for: %r" % (count, found, old[:70])
    s = s.replace(old, new)

open(path, "w").write(s)
print("patched", len(patches), "snippets")
PY
```
Expected: `patched 9 snippets`. If an assertion fails nothing is written; re-read `island/Island.qml` and fix the snippet, do not loosen the count.

- [ ] **Step 6: Lint the patched island and check the reload**

Run:
```bash
cd /home/tk421/Development/quickshell && /usr/lib/qt6/bin/qmllint -I /usr/lib/qt6/qml island/Island.qml 2>&1 | grep -E "Error|syntax|incompatible-type|unresolved|import\]"; echo "lint done"
sleep 2; qs log -p /home/tk421/Development/quickshell/shell.qml | awk '/Reloading configuration/{n=0; next} {n++; l[n]=$0} END{for(i=1;i<=n;i++) print l[i]}' | grep -E "WARN|ERROR"
```
Expected: `lint done` only, and at most the expected notification-server warning from Task 2.

- [ ] **Step 7: Verify each toast state visually**

```bash
cd /home/tk421/Development/quickshell
QS="qs ipc -p /home/tk421/Development/quickshell/shell.qml call"
SHOTS=$(mktemp -d); echo $SHOTS
$QS notifications inject normal;  sleep 1.2; grim -g "1080,4 400x82" $SHOTS/normal.png
sleep 5;                                     grim -g "1080,4 400x82" $SHOTS/after-timeout.png
$QS notifications inject critical; sleep 1.2; grim -g "1080,4 400x82" $SHOTS/critical.png
hyprctl dispatch 'hl.dsp.cursor.move({ x = 1280, y = 40 })'; sleep 1
grim -g "1080,4 400x130" $SHOTS/critical-hover.png
hyprctl dispatch 'hl.dsp.cursor.move({ x = 1280, y = 600 })'
$QS notifications clear
$QS notifications inject actions;  sleep 1.2
hyprctl dispatch 'hl.dsp.cursor.move({ x = 1280, y = 40 })'; sleep 1
grim -g "1080,4 400x124" $SHOTS/actions-hover.png
hyprctl dispatch 'hl.dsp.cursor.move({ x = 1280, y = 600 })'; sleep 1
$QS notifications status
```
Read the PNGs. Compare with the prototype states (`prototypes/notifications/index.html#toast`, `#critical`, `#actions`). Expected: `normal.png` is a 400×82 card with the Ghostty tile (icon or bell glyph), title "Build finished", one-line body, accent line partly drained along the bottom; `after-timeout.png` shows the plain idle pill with the clock (toast gone); `critical.png` has a red border, red tile border, red "CRITICAL" label and no countdown line; `critical-hover.png` shows the card grown with an `OPEN` button (filled red) and a × button; `actions-hover.png` shows `JOIN` (filled) and `SNOOZE`. The last `status` ends `toast=true` (the actions toast was paused while hovered, then resumed; if more than 5 s passed after leaving, `toast=false` is also correct). Adjust the capture heights if a card is cut off.

- [ ] **Step 8: Verify the island kept its existing behaviour**

```bash
cd /home/tk421/Development/quickshell
QS="qs ipc -p /home/tk421/Development/quickshell/shell.qml call"
SHOTS=$(mktemp -d); echo $SHOTS
$QS notifications clear
grim -g "1226,4 108x28" $SHOTS/idle.png                       # idle pill
$QS island toggle; sleep 1; grim -g "906,4 748x424" $SHOTS/open.png
$QS notifications inject normal; sleep 0.5; $QS notifications status   # island open: no popup
$QS island toggle; sleep 1
wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle; sleep 0.8; grim -g "1130,4 300x44" $SHOTS/hud.png
wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle                    # restore the user's mute state
$QS notifications clear
```
Expected: `idle.png` shows the clock pill; `open.png` shows the calendar card exactly as before; with the island open the injected notification is **not** shown (`status` prints `1/1 ... toast=false`), and the bell count went up; `hud.png` shows the volume HUD. Hover test: move the cursor onto the idle pill (`hyprctl dispatch 'hl.dsp.cursor.move({ x = 1280, y = 18 })'`) and the calendar opens; move away and it closes. Then `inject normal`, move the cursor onto the toast and confirm the **calendar does not open** (the toast expands instead); wait out the toast with the cursor still on the island and confirm the calendar still does not open; move the cursor away and back and confirm it now opens. Finally move the cursor to `y = 600` and `$QS notifications clear`.

- [ ] **Step 9: Checkpoint**

`$QS notifications status` prints `0/0 dnd=false toast=false center=false`. No commit.

---

### Task 5: Dropdown (centre) and its row

**Files:**
- Create: `notifications/NotificationItem.qml`
- Create: `notifications/NotificationCenter.qml`
- Modify: `shell.qml`

**Interfaces:**
- Consumes: `Notifications.history`, `.unreadCount`, `.dnd`, `.centerOpen`, `.clearing`, `.setCenterOpen()`, `.closeByGrab()`, `.setDnd()`, `.markRead()`, `.dismiss()`, `.invoke()`, `.clear()` (Task 2); `AppTile`, `ActionButton` (Task 4); `Logic.relativeTime`, `Logic.dayLabel` (Task 1).
- Produces: `NotificationCenter` (a `PanelWindow`, instantiated once in `shell.qml`).

- [ ] **Step 1: Create `notifications/NotificationItem.qml`**

```qml
import QtQuick

import "../components"
import "../services"
import "../theme"
import "logic.js" as Logic

// One row of the notification centre. Width comes from the list (378 px); height follows the content.
Item {
    id: item

    required property var modelData
    required property int index

    property double now: Date.now()

    readonly property var c: Theme.imperial
    readonly property var entry: modelData
    readonly property string day: entry ? Logic.dayLabel(entry.timestamp, now) : ""
    readonly property string prevDay: {
        const prev = Notifications.history[index - 1]
        return index > 0 && prev ? Logic.dayLabel(prev.timestamp, now) : ""
    }
    readonly property bool showDay: index === 0 || day !== prevDay
    readonly property real dayHeight: showDay ? 30 : 0
    readonly property bool critical: entry?.critical ?? false
    readonly property bool hasActions: (entry?.actions.length ?? 0) > 0 && !!entry?.live

    width: 378
    height: dayHeight + 12 + 14 + 3 + 20 + 1 + bodyText.implicitHeight + (hasActions ? 10 + 28 : 0) + 12 + 1

    // The row slides in from above when it arrives, and collapses when it is removed.
    ListView.onAdd: ParallelAnimation {
        NumberAnimation { target: inner; property: "opacity"; from: 0; to: 1; duration: 460 }
        NumberAnimation {
            target: inner
            property: "y"
            from: -10
            to: 0
            duration: 460
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
        }
    }

    ListView.onRemove: SequentialAnimation {
        PropertyAction { target: item; property: "ListView.delayRemove"; value: true }
        PauseAnimation { duration: Notifications.clearing ? Math.min(item.index, 8) * 40 : 0 }
        ParallelAnimation {
            NumberAnimation { target: item; property: "opacity"; to: 0; duration: 160 }
            NumberAnimation {
                target: item
                property: "height"
                to: 0
                duration: 300
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
            }
        }
        PropertyAction { target: item; property: "ListView.delayRemove"; value: false }
    }

    clip: true

    Item {
        id: inner

        width: parent.width
        height: item.height

        Text {
            visible: item.showDay
            x: 20
            y: 14
            text: item.day
            textFormat: Text.PlainText
            color: item.c.muted
            renderType: Text.CurveRendering
            font.family: Theme.displayFont
            font.pixelSize: 10
            font.weight: Font.Medium
            font.letterSpacing: 1.6
            font.capitalization: Font.AllUppercase
        }

        // Row body: hover fill, click marks it read.
        Rectangle {
            y: item.dayHeight
            width: parent.width
            height: parent.height - item.dayHeight
            color: item.c.surfaceAlt
            opacity: rowArea.containsMouse ? 1 : 0

            Behavior on opacity {
                NumberAnimation { duration: 120 }
            }
        }

        MouseArea {
            id: rowArea

            y: item.dayHeight
            width: parent.width
            height: parent.height - item.dayHeight
            hoverEnabled: true
            onClicked: Notifications.markRead(item.entry)
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: item.c.border
        }

        AppTile {
            x: 20
            y: item.dayHeight + 12
            width: 32
            height: 32
            appIcon: item.entry?.appIcon ?? ""
            desktopEntry: item.entry?.desktopEntry ?? ""
            critical: item.critical
        }

        Row {
            x: 64
            y: item.dayHeight + 12
            height: 14
            spacing: 7

            Rectangle {
                visible: item.entry?.unread ?? false
                anchors.verticalCenter: parent.verticalCenter
                width: 6
                height: 6
                radius: 3
                color: item.c.accent
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 258 - 60)
                text: item.entry?.appName ?? ""
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: item.critical ? item.c.dangerText : item.c.muted
                renderType: Text.CurveRendering
                font.family: Theme.displayFont
                font.pixelSize: 10
                font.weight: Font.Medium
                font.letterSpacing: 1.6
                font.capitalization: Font.AllUppercase
            }
        }

        Text {
            x: 64 + 258 - implicitWidth
            y: item.dayHeight + 12
            height: 14
            verticalAlignment: Text.AlignVCenter
            text: item.entry ? Logic.relativeTime(item.entry.timestamp, item.now) : ""
            color: item.critical ? item.c.dangerText : item.c.muted
            renderType: Text.CurveRendering
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }

        Text {
            x: 64
            y: item.dayHeight + 12 + 14 + 3
            width: 258
            height: 20
            verticalAlignment: Text.AlignVCenter
            text: item.entry?.summary ?? ""
            textFormat: Text.PlainText
            elide: Text.ElideRight
            maximumLineCount: 1
            color: item.c.text
            renderType: Text.CurveRendering
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.weight: Font.Medium
        }

        Text {
            id: bodyText

            x: 64
            y: item.dayHeight + 12 + 14 + 3 + 20 + 1
            width: 258
            text: item.entry?.body ?? ""
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            lineHeightMode: Text.FixedHeight
            lineHeight: 16
            color: item.c.muted
            renderType: Text.CurveRendering
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }

        Row {
            visible: item.hasActions
            x: 64
            y: bodyText.y + bodyText.implicitHeight + 10
            spacing: 6

            Repeater {
                model: item.entry?.actions ?? []

                delegate: ActionButton {
                    required property var modelData
                    required property int index

                    text: modelData.text
                    primary: index === 0
                    danger: item.critical
                    onClicked: Notifications.invoke(item.entry, index)
                }
            }
        }

        // Remove from history. Visible on hover.
        Item {
            x: 378 - 20 - 24
            y: item.dayHeight + 12
            width: 24
            height: 24
            opacity: rowArea.containsMouse || closeArea.containsMouse ? 1 : 0

            Behavior on opacity {
                NumberAnimation { duration: 160 }
            }

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: item.c.bg
                border.width: 1
                border.color: item.c.border
                opacity: closeArea.containsMouse ? 1 : 0
            }

            Text {
                anchors.centerIn: parent
                text: "×"
                color: closeArea.containsMouse ? item.c.text : item.c.muted
                renderType: Text.CurveRendering
                font.family: Theme.fontFamily
                font.pixelSize: 16
            }

            MouseArea {
                id: closeArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Notifications.dismiss(item.entry)
            }
        }
    }
}
```

Layout note: the text column is `x: 64` to `x: 322` (258 px wide), the time label is right-aligned to 322, and the × button starts at `x: 334` (`378 - 20 - 24`), so they never overlap.

- [ ] **Step 2: Create `notifications/NotificationCenter.qml`**

```qml
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

import "../components"
import "../services"
import "../theme"

// Notification centre: a dropdown under the bell that unrolls from the toolbar capsule.
// Prototype: prototypes/notifications/index.html (#center, #center-dnd, #empty).
PanelWindow {
    id: win

    readonly property var c: Theme.imperial
    readonly property bool open: Notifications.centerOpen

    property double now: Date.now()

    anchors {
        top: true
        right: true
    }
    margins.top: 40
    margins.right: 30
    implicitWidth: 380
    implicitHeight: 520
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    // Stay mapped while the close animation plays.
    visible: open || panel.height > 0.5

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "tk421-notifications"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Only the panel takes input; the rest of the window is click-through.
    mask: Region { item: panel }

    component Ease: NumberAnimation {
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
    }

    onOpenChanged: {
        if (open)
            now = Date.now()
    }

    Timer {
        interval: 30000
        repeat: true
        running: win.open
        onTriggered: win.now = Date.now()
    }

    // A click outside closes it.
    HyprlandFocusGrab {
        windows: [win]
        active: win.open
        onCleared: Notifications.closeByGrab()
    }

    Shortcut {
        sequence: "Escape"
        enabled: win.open
        onActivated: Notifications.setCenterOpen(false)
    }

    Rectangle {
        id: panel

        anchors.right: parent.right
        y: 0

        width: win.open ? 380 : 260
        height: win.open ? content.implicitHeight + 2 : 0
        radius: win.open ? 24 : 14
        color: win.c.surface
        border.width: 1
        border.color: win.c.border
        clip: true
        opacity: win.open ? 1 : 0

        Behavior on width { Ease { duration: win.open ? 520 : 340 } }
        Behavior on height { Ease { duration: win.open ? 520 : 340 } }
        Behavior on radius { Ease { duration: win.open ? 520 : 340 } }
        Behavior on opacity { NumberAnimation { duration: win.open ? 200 : 160 } }

        // Content has a fixed width, right-aligned, so the growing panel never reflows it.
        Item {
            id: content

            anchors.right: parent.right
            anchors.rightMargin: 1
            anchors.top: parent.top
            anchors.topMargin: 1
            width: 378
            implicitHeight: header.height + strip.height + listArea.height + 6

            opacity: win.open ? 1 : 0
            scale: win.open ? 1 : 0.97
            transformOrigin: Item.TopRight

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: win.open ? 140 : 0 }
                    NumberAnimation { duration: win.open ? 320 : 140 }
                }
            }
            Behavior on scale { Ease { duration: win.open ? 520 : 140 } }

            // ---- header ----
            Item {
                id: header

                width: parent.width
                height: 56

                Text {
                    id: title

                    x: 20
                    y: 4 + (52 - height) / 2
                    text: "Notifications"
                    color: win.c.text
                    renderType: Text.CurveRendering
                    font.family: Theme.displayFont
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    font.letterSpacing: 2.16
                    font.capitalization: Font.AllUppercase
                }

                Text {
                    x: title.x + title.implicitWidth + 12
                    y: title.y
                    height: title.height
                    verticalAlignment: Text.AlignVCenter
                    visible: Notifications.unreadCount > 0
                    text: Notifications.unreadCount + " new"
                    color: win.c.muted
                    renderType: Text.CurveRendering
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }

                ActionButton {
                    id: clearButton

                    x: 358 - width
                    y: 18
                    text: "Clear"
                    enabled: Notifications.history.length > 0
                    opacity: enabled ? 1 : 0.35
                    onClicked: Notifications.clear()
                }

                // Do Not Disturb
                Rectangle {
                    x: clearButton.x - 6 - width
                    y: 18
                    width: 28
                    height: 28
                    radius: 8
                    color: Notifications.dnd ? win.c.accentDim : "transparent"
                    border.width: 1
                    border.color: Notifications.dnd || dndArea.containsMouse ? win.c.accent : win.c.border

                    Text {
                        anchors.centerIn: parent
                        text: ""      // Font Awesome moon
                        color: Notifications.dnd || dndArea.containsMouse ? win.c.text : win.c.muted
                        renderType: Text.CurveRendering
                        font.family: Theme.iconFont
                        font.pixelSize: 14
                    }

                    MouseArea {
                        id: dndArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifications.setDnd(!Notifications.dnd)
                    }
                }

                Rectangle {
                    x: 20
                    y: parent.height - 1
                    width: 338
                    height: 1
                    color: win.c.border
                }
            }

            // ---- DND strip ----
            Item {
                id: strip

                y: header.height
                width: parent.width
                height: Notifications.dnd ? 36 : 0
                clip: true

                Behavior on height { Ease { duration: 300 } }

                Rectangle {
                    x: 20
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6
                    height: 6
                    radius: 3
                    color: win.c.accent
                }

                Text {
                    x: 34
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Do not disturb · popups muted, critical alerts still show"
                    color: win.c.muted
                    renderType: Text.CurveRendering
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }

                Rectangle {
                    x: 20
                    anchors.bottom: parent.bottom
                    width: 338
                    height: 1
                    color: win.c.border
                }
            }

            // ---- list / empty state ----
            Item {
                id: listArea

                y: header.height + strip.height
                width: parent.width
                height: Notifications.history.length > 0 ? Math.min(list.contentHeight, 392) : 120

                Behavior on height { Ease { duration: 300 } }

                ListView {
                    id: list

                    anchors.fill: parent
                    clip: true
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds

                    model: ScriptModel {
                        values: Notifications.history
                        objectProp: "uid"
                    }

                    delegate: NotificationItem {
                        now: win.now
                    }

                    displaced: Transition {
                        Ease { property: "y"; duration: 300 }
                    }
                }

                // Scroll indicator.
                Rectangle {
                    visible: list.contentHeight > list.height
                    x: parent.width - 6
                    width: 3
                    radius: 1.5
                    color: win.c.border
                    y: list.visibleArea.yPosition * list.height
                    height: list.visibleArea.heightRatio * list.height
                }

                Column {
                    visible: Notifications.history.length === 0
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: ""      // Font Awesome bell-slash
                        color: win.c.muted
                        renderType: Text.CurveRendering
                        font.family: Theme.iconFont
                        font.pixelSize: 26
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        topPadding: 6
                        text: "No notifications"
                        color: win.c.text
                        renderType: Text.CurveRendering
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.Medium
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "You're all caught up."
                        color: win.c.muted
                        renderType: Text.CurveRendering
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 3: Lint both files**

Run:
```bash
cd /home/tk421/Development/quickshell && for f in notifications/NotificationItem.qml notifications/NotificationCenter.qml; do echo "== $f"; /usr/lib/qt6/bin/qmllint -I /usr/lib/qt6/qml $f 2>&1 | grep -E "Error|syntax|incompatible-type|unresolved|import\]"; done; echo "lint done"
```
Expected: no lines under either heading. Fix before the next step.

- [ ] **Step 4: Instantiate the centre in `shell.qml` (single save)**

Replace `shell.qml` entirely:

```qml
import Quickshell
import QtQuick
import "bar"
import "island"
import "lock"
import "notifications"
import "services"

ShellRoot {
    // Referencing the service starts its D-Bus notification server with the shell instead of on first use.
    property bool notificationsActive: Notifications.active

    SystemStats {
        id: systemStats
    }

    Bar {}
    Island {}
    NotificationCenter {}
    Lock {}
}
```

- [ ] **Step 5: Verify the dropdown visually and by interaction**

```bash
cd /home/tk421/Development/quickshell
QS="qs ipc -p /home/tk421/Development/quickshell/shell.qml call"
qs log -p /home/tk421/Development/quickshell/shell.qml | awk '/Reloading configuration/{n=0; next} {n++; l[n]=$0} END{for(i=1;i<=n;i++) print l[i]}' | grep -E "WARN|ERROR"
SHOTS=$(mktemp -d); echo $SHOTS
$QS notifications toggleCenter; sleep 1; grim -g "2150,40 380x130" $SHOTS/empty.png
$QS notifications toggleCenter; sleep 0.8
$QS notifications inject actions; $QS notifications inject normal; $QS notifications inject low; $QS notifications inject critical; sleep 0.5
$QS notifications status
$QS notifications toggleCenter; sleep 1.2; $QS notifications status
grim -g "2150,40 380x470" $SHOTS/center.png
$QS notifications toggleDnd; sleep 0.6; grim -g "2150,40 380x470" $SHOTS/center-dnd.png
$QS notifications toggleDnd
```
Read the PNGs and compare with prototype `#empty`, `#center`, `#center-dnd`. Expected:
- `empty.png`: header "NOTIFICATIONS", moon and CLEAR (dimmed) buttons, a slashed bell, "No notifications", "You're all caught up."
- First `status` (before opening): `4/4 ... toast=true center=false`; after opening: `4/4 dnd=false toast=false center=true` (opening hides the toast).
- `center.png`: a "TODAY" section, four rows newest first (Disk space low with red label, 14 updates, Build finished, Daily with `JOIN`/`SNOOZE`), blue dots on the unread rows, header `4 new`.
- `center-dnd.png`: the moon button filled blue and the strip "Do not disturb · popups muted, critical alerts still show" under the header.
Region heights may need adjusting to the real panel height (crop to the panel only).

Interaction checks (still with the centre open; use `hyprctl dispatch 'hl.dsp.cursor.move({ x = X, y = Y })'` and `grim` as above):
1. Hover a row → × appears; click it → the row collapses and `status` drops by one.
2. Click the moon button → DND strip appears; click again → it goes.
3. Click `CLEAR` → rows leave in a short cascade, the empty state appears, `status` is `0/0 ...`.
4. `$QS notifications inject normal` while open → a row slides in at the top with a blue dot, **no** toast (`toast=false`).
5. Press `Esc` → the panel closes (`center=false`). If `Esc` does nothing, the window has no keyboard focus: change `WlrLayershell.keyboardFocus` to `open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None`, save, retest, and note it for Task 7's docs.
6. Reopen, then click on the wallpaper/empty desktop area outside the panel → it closes (grab). Reopen and click the bell → it closes once and stays closed (no flicker back open).
7. After the centre closes, wait 1 s, then `$QS notifications status` shows `unread` 0 (e.g. `0/1 ...`) and the bell shows no digit.

- [ ] **Step 6: Checkpoint**

`$QS notifications clear; $QS notifications status` → `0/0 dnd=false toast=false center=false`. No commit.

---

### Task 6: Cutover, real traffic, Hyprland config

This task changes what the user's real desktop uses for notifications. **Do not start it without the user's go-ahead.**

**Files:**
- Modify: `services/Notifications.qml` (one line: `mock: true` → `false`)
- Modify: `hypr/hyprland.lua` (lines 50 and 349)

**Interfaces:**
- Consumes: the whole service and UI from Tasks 2–5.
- Produces: Quickshell owning `org.freedesktop.Notifications`; `SUPER+N` toggling the centre.

- [ ] **Step 1: Get the user's go-ahead**

Ask: "Tasks 1–5 are done and verified with injected notifications. The next step stops `swaync` and makes Quickshell your notification daemon, then edits two lines of `hypr/hyprland.lua`. OK to proceed?" Wait for a yes. If no, stop here; the shell is in a safe, finished state with `mock = true`.

- [ ] **Step 2: Stop swaync, hand the name to Quickshell**

```bash
pkill swaync; sleep 1
busctl --user status org.freedesktop.Notifications 2>&1 | head -3
```
Expected: the name has no owner now (`Failed to get credentials` or similar).

Edit `services/Notifications.qml`: change the line `property bool mock: true` to `property bool mock: false` (single save). Then:
```bash
sleep 3
busctl --user status org.freedesktop.Notifications | grep -E "^(PID|Comm)"
qs log -p /home/tk421/Development/quickshell/shell.qml | awk '/Reloading configuration/{n=0; next} {n++; l[n]=$0} END{for(i=1;i<=n;i++) print l[i]}' | grep -E "WARN|ERROR"
```
Expected: `Comm=quickshell`, and the log check prints **nothing** (the registration warning is gone now that swaync no longer holds the name). If the owner is not Quickshell, restart `swaync` (`swaync &`), set `mock` back to `true`, and investigate before continuing.

- [ ] **Step 3: Real traffic**

```bash
cd /home/tk421/Development/quickshell
QS="qs ipc -p /home/tk421/Development/quickshell/shell.qml call"
SHOTS=$(mktemp -d); echo $SHOTS
$QS notifications status
notify-send "Build finished" "quickshell · release build"; sleep 1.2; grim -g "1080,4 400x82" $SHOTS/real-normal.png; $QS notifications status
notify-send -u critical "Disk space low" "/ is 94% full"; sleep 1.2; grim -g "1080,4 400x82" $SHOTS/real-critical.png
notify-send -u low "Background sync" "done"; sleep 0.5; $QS notifications status
notify-send -e "Transient" "popup only"; sleep 0.5; $QS notifications status
notify-send '<b>bold</b> & <a href="http://x">link</a>' '<i>italic</i> text'; sleep 1.2; grim -g "1080,4 400x82" $SHOTS/real-markup.png
notify-send -i http://127.0.0.1:9/x.png "Remote icon" "must show the bell glyph, no request"; sleep 1.2; grim -g "1080,4 400x82" $SHOTS/real-icon.png
notify-send "$(printf 'bidi \xe2\x80\xae-text-reversed')" "control chars stripped"; sleep 1.2
```
Read the PNGs. Expected:
- Each `notify-send` produces a toast; `status` unread counts rise by 1 for normal, critical, low, markup, icon and bidi, and **not** for the transient one (it is never kept). `low` shows no toast.
- `real-markup.png` shows the literal text `<b>bold</b> & <a href="http://x">link</a>` and `<i>italic</i> text` (tags visible, not rendered).
- `real-icon.png` shows the bell glyph, not an image.
- The bidi test shows the text without reversing and without the invisible characters.

- [ ] **Step 7: Actions, replacement and withdrawal (Review Focus item 5)**

```bash
cd /home/tk421/Development/quickshell
QS="qs ipc -p /home/tk421/Development/quickshell/shell.qml call"
$QS notifications clear
# Actions: the printed identifier is what the app receives when a button is pressed.
( notify-send -A join=Join -A snooze=Snooze -w "Daily" "Google Meet · 10:00" > /tmp/notify-action.out & )
sleep 1.2; hyprctl dispatch 'hl.dsp.cursor.move({ x = 1280, y = 40 })'; sleep 1
echo "now click JOIN with the real mouse, or run: hyprctl dispatch 'hl.dsp.cursor.move({ x = 1112, y = 100 })' then click"
```
Press `JOIN` with the mouse, then `cat /tmp/notify-action.out`; expected `join`, and the entry is gone (`status` back to previous count).

Replacement (record which path Quickshell takes):
```bash
id=$(notify-send -p "First" "one"); sleep 1.5
notify-send -r $id "Second" "two"; sleep 1.2
$QS notifications status
```
Expected: `status` total is one more than before, **not two**; the toast shows "Second"/"two" and the history has a single entry titled "Second". If two entries appear, `accept()`'s `known` lookup is missing replacements: they arrive as new Notification objects with the same `id`; fix by matching on `e.nid === n.id` (already done), then re-check that `n.id` is stable across replacements.

Withdrawal while the toast is on screen:
```bash
id=$(notify-send -p -u critical "Sticky" "withdrawn by its app"); sleep 1.2
$QS notifications status                      # expect toast=true
gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications --method org.freedesktop.Notifications.CloseNotification $id
sleep 0.8; $QS notifications status           # expect toast=false and that entry gone
qs log -p /home/tk421/Development/quickshell/shell.qml | awk '/Reloading configuration/{n=0; next} {n++; l[n]=$0} END{for(i=1;i<=n;i++) print l[i]}' | grep -E "WARN|ERROR"
```
Expected: the toast vanishes, the entry leaves the history, and the log check stays empty.

- [ ] **Step 8: Flood and reload survival**

```bash
cd /home/tk421/Development/quickshell
QS="qs ipc -p /home/tk421/Development/quickshell/shell.qml call"
$QS notifications clear
for i in $(seq 80); do notify-send "n$i" "body $i"; done; sleep 1
$QS notifications status
```
Expected: total is `50` (`<unread>/50 ...`) and the shell stays responsive (open the centre with `toggleCenter` and scroll it).

Reload survival (two saves of `shell.qml`, both in working state; this is a test-only probe):
```bash
$QS notifications clear
notify-send "keep 1" "a"; notify-send "keep 2" "b"; notify-send "keep 3" "c"; sleep 6
$QS notifications status
echo "// reload-probe" >> shell.qml; sleep 3
$QS notifications status
sed -i '/\/\/ reload-probe/d' shell.qml; sleep 3
$QS notifications status
```
Expected: `3/3 ...` before; after each reload still `0/3 dnd=false toast=false ...` (carried over, restored as read, **no popup**). Then `$QS notifications clear`.

- [ ] **Step 9: Screenshot scripts and DND with real traffic**

```bash
/home/tk421/.local/bin/screenshot-full 2>&1 | tail -2; sleep 1.5; $QS notifications status
```
Expected: the screenshot script's `notify-send` shows up as a toast (it announces the saved file). Then:
```bash
$QS notifications toggleDnd
notify-send "muted" "no popup"; sleep 1; $QS notifications status       # toast=false, unread +1
notify-send -u critical "still shows" "critical bypasses DND"; sleep 1.2; $QS notifications status   # toast=true
$QS notifications toggleDnd; $QS notifications clear
```

- [ ] **Step 10: Edit `hypr/hyprland.lua`**

The two edits:
1. Remove the line `	hl.exec_cmd("swaync")` (currently line 50, inside the `hl.on("hyprland.start", ...)` block; the lines for `hypridle` and `quickshell` stay).
2. Replace `hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("swaync-client -t -sw"))` (line 349) with:

```lua
hl.bind(
	mainMod .. " + N",
	hl.dsp.exec_cmd(
		"quickshell ipc -p /home/tk421/Development/quickshell/shell.qml call notifications toggleCenter"
	)
)
```
Read the file around both places first and use `Edit` with the exact existing text. Then `hyprctl reload` and check `hyprctl configerrors` prints nothing. Press `SUPER+N` and confirm the centre opens and closes (`$QS notifications status` shows `center=true` / `false`).

- [ ] **Step 11: Checkpoint**

`pgrep -a swaync` prints nothing, `busctl --user status org.freedesktop.Notifications | grep Comm` prints `Comm=quickshell`, and the latest-reload log check is empty. No commit.

---

### Task 7: Documentation and final regression

**Files:**
- Modify: `CLAUDE.md`
- Modify: `tk421/TK421.md`
- Modify: `docs/superpowers/specs/2026-10-12-notifications-design.md` (IPC table, flagged additions)

**Interfaces:** none (documentation only).

- [ ] **Step 1: Update `CLAUDE.md`**

Read the file, then apply these edits with `Edit` (exact text from the current file):

1. In the Commands IPC list, after the `agenda` line add:
   ```
     - `notifications`: `toggleCenter`, `toggleDnd`, `clear`, `status` (`<unread>/<total> dnd=… toast=… center=…`), `inject <normal|actions|critical|low|long>` (fake notification; only while `Notifications.mock` is true)
   ```
2. In Commands, after the Agenda Python line add:
   ```
   - QML unit tests (logic only): `cd /home/tk421/Development/quickshell && QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml`. Use the Qt 6 runner: `/usr/bin/qmltestrunner` is Qt 5.
   - QML lint before saving into the live shell: `/usr/lib/qt6/bin/qmllint -I /usr/lib/qt6/qml <file>` (ignore `unqualified` and `uncreatable-type` noise).
   ```
3. In Architecture, change the `services/` bullet to also list `Notifications` (the `NotificationServer`, history, DND and toast state), and add a new bullet:
   ```
   - **`notifications/`** is the notification UI and rules: `logic.js` (pure, unit-tested: arrival policy, text cleaning, icon safety, time labels), `NotificationEntry`, `NotificationItem` and `NotificationCenter` (the dropdown under the bell, a `PanelWindow` closed by `HyprlandFocusGrab`, `Esc` or the bell). The toast is an island state (`island/NotificationToast.qml`). `bar/Toolbar.qml` is the right-hand capsule; `bar/NotificationBell.qml` is its only item so far. Quickshell owns `org.freedesktop.Notifications`; `swaync` is no longer started. Spec: `docs/superpowers/specs/2026-10-12-notifications-design.md`.
   ```
4. In the `island/` bullet change `State priority: open > volume HUD > media pill > idle.` to `State priority: open > notification toast > volume HUD > media pill > idle.`
5. In the last architecture bullet, replace `The bar's right-hand tray group is commented out in `bar/Bar.qml`.` with `The bar's right-hand capsule is `bar/Toolbar.qml`; network, Bluetooth and power will join the bell there.`
6. In Conventions and gotchas add: `Only one process can own `org.freedesktop.Notifications`. If `swaync` (or `mako`, `dunst`) is running, the shell's server cannot register and logs a warning. `SUPER+N` toggles the centre through IPC.`

- [ ] **Step 2: Update `tk421/TK421.md`** (project rule: decisions change the document, answering "what changed / what was replaced / validated or planned / which paths")

Read the file, then:
1. §16 "Notificações": replace the stack block and recursos with Quickshell's `NotificationServer` (popup in the island, history and DND in the bell dropdown), mark `✅ Validado` with the date 2026-10-12, and replace the "Pendência: binding definitivo" line with `SUPER + N → centro de notificações (quickshell ipc … notifications toggleCenter)`.
2. §10 autostart bullets and §38 serviços: remove `swaync` (Quickshell now starts the notification server).
3. §39 Shell/UI: remove `integração de notificações`; Desktop: remove `central SwayNC em binding`.
4. §37 atalhos: add `SUPER + N → centro de notificações`.
5. §42 decisões substituídas: add
   ```
   ## Notificações

   SwayNC → antigo (2026-10-12)
   Quickshell NotificationServer → atual
   ```
6. §46 pacotes: `swaync` stays listed but add `(substituído pelo NotificationServer do Quickshell, mantido instalado para rollback)`.

- [ ] **Step 3: Update the spec for the additions made in this plan**

In `docs/superpowers/specs/2026-10-12-notifications-design.md`:
1. IPC table row for `status()`: change the string to `"<unread>/<total> dnd=<bool> toast=<bool> center=<bool>"`.
2. Add a short section "Additions made during planning" listing the eight items under "Additions beyond the spec" in the plan, so the spec and the shipped behaviour agree.

- [ ] **Step 4: Full regression**

```bash
cd /home/tk421/Development/quickshell
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml 2>&1 | tail -4
qs log -p /home/tk421/Development/quickshell/shell.qml | awk '/Reloading configuration/{n=0; next} {n++; l[n]=$0} END{for(i=1;i<=n;i++) print l[i]}' | grep -c -E "WARN|ERROR"
pgrep -a swaync | wc -l
busctl --user status org.freedesktop.Notifications | grep Comm
```
Expected: `0 failed`; log count `0`; `0` swaync processes; `Comm=quickshell`.

Walk the spec's acceptance criteria 1–9 once more against the live shell (real `notify-send` for 2, the island hover and priority rules for 5, a hot-reload for 6, `SUPER+N`, bell, `Esc` and outside click for 7). Do not call `lock lock`. Report each criterion as verified or not, with the evidence.

- [ ] **Step 5: Checkpoint**

`git status --short` lists the expected files. No commit unless the user asks.

---

## Self-Review

**Spec coverage** (spec section → task):
- Decisions table: daemon, popup surface, history surface, timing, DND, low, transient, timeout policy, history cap, plain text, actions, no inline reply/images, `keepOnReload` → Tasks 1, 2, 4, 5 (`arrivalPolicy`, service, toast, centre).
- Service (server flags, `accept`, arrival table, entry fields, public API, toast policy, IPC) → Task 2; arrival table unit-tested in Task 1.
- Island toast (geometry, layout, swap, fixed-width content, critical styling, hover rule, priority) → Task 4 (Steps 3, 5, 7, 8).
- Toolbar and bell (geometry, glyph, count, ping, click) → Task 3.
- Dropdown (window, motion, close methods, header, DND strip, list, item, motion, empty state, unread dots, relative time) → Task 5.
- Icons and `appIcon` sanitisation → Task 1 (`iconSource`) and Task 4 (`AppTile`).
- Security and robustness (PlainText, limits, flood bound, lock, registration failure) → Tasks 1, 2, 4, 5, 6.
- Hyprland changes, Rollout, Testing, Acceptance criteria → Tasks 6 and 7.
- Documentation → Task 7. Non-goals respected: no persistence, no per-app rules, no stacking.
- Gap found and fixed while reviewing: the spec's "Island open hides toast" is implemented by `onIslandOpenChanged` in the service (Task 2) driven by the `Binding` added to the island (Task 4).

**Placeholder scan:** no TBD/TODO; every code step has full code; every verify step has commands and expected output. Region coordinates in `grim` steps are exact for the 2560×1080 monitor; the "adjust if cut off" notes are about capture crops, not missing content.

**Type consistency:** `Notifications.toast`, `toastHovered`, `toastProgress`, `hideToast(bool)`, `invoke(entry, index)`, `setCenterOpen`, `toggleCenter`, `closeByGrab`, `setDnd`, `markRead`, `dismiss`, `clear`, `clearing`, `settling`, `islandOpen`, `pinged()` are defined in Task 2 and used under the same names in Tasks 3–6. Entry fields (`summary`, `body`, `appName`, `appIcon`, `desktopEntry`, `critical`, `actions[{index,identifier,text}]`, `timestamp`, `unread`, `live`, `resident`, `isTransient`, `nid`, `dropped`) match between `NotificationEntry`, the service, toast and row. `Logic` function names and signatures match between Task 1 and later uses (`badgeText`, `relativeTime`, `dayLabel`, `iconSource`, `titleOf`, `pickActions`, `arrivalPolicy`, `LIMITS`, `TOAST_MS`).

**Review Focus coverage:** items 1–4 pinned by Task 1 tests; item 5 pinned by Task 6 Step 7.

**Known risks to watch while executing:** (a) `Esc` needing `Exclusive` keyboard focus (Task 5 Step 5 has the fallback); (b) how Quickshell delivers `replaces_id` is undocumented, Task 6 Step 7 tests it and the service handles both the re-emitted signal and property changes; (c) `Instantiator`-free design means a failed D-Bus registration only logs a warning (expected until Task 6).
