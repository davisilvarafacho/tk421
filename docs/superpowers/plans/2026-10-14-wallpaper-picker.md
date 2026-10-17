# Wallpaper Picker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `Super+Alt+B` opens a blast-door wallpaper picker in the middle of the screen; ←/→ change the wallpaper live with one of four Star Wars transitions (Superlaser by default), Enter keeps it, Esc restores the original.

**Architecture:** `awww` stays the real, persistent wallpaper. A `WallpaperStage` window on the Bottom layer (above the awww background, below every window, click-through) draws what is on screen while the picker is open or a transition runs, and hands over to `awww` on Enter. `services/Wallpaper.qml` is the model (folder, applied/shown wallpaper, effect, IPC); `wallpaper/logic.js` holds the pure rules; `WallpaperPicker` is the door; four effect components share one interface (`fromSource`, `toSource`, `progress`).

**Tech Stack:** Quickshell 0.3.2 (`PanelWindow`, `WlrLayershell`, `Region`, `FileView`, `Process`, `ScriptModel`, `IpcHandler`), Qt 6 (`MultiEffect`, `Shape`, `QtTest`), `awww` 0.12.1, `jq`, `magick`.

**Spec:** `docs/superpowers/specs/2026-10-14-wallpaper-picker-design.md`. Prototype: `prototypes/wallpaper/index.html` (its `render(p)` functions are the reference for every effect).

## Global Constraints

- Quickshell **0.3.2**, Qt 6. Test runner: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml` (`/usr/bin/qmltestrunner` is Qt 5 and does not work). Lint: `/usr/lib/qt6/bin/qmllint`.
- **The running shell is the user's real desktop and hot-reloads on every file save.** Write each QML file once, in a working state. New files stay out of `shell.qml` until their task wires them in; run `qmllint` before wiring.
- Patch shared files (`shell.qml`, `services/qmldir`, `CLAUDE.md`, `.gitignore`, `hypr/hyprland.lua`) with exact-match replacements that assert the match count; never rewrite them whole. Other sessions edit this repo too.
- **No commits.** The repo has no commits and `CLAUDE.md` says not to commit unless asked, so this plan has no commit steps. Each task ends with a checkpoint instead.
- UI copy is English. Strings from outside (file names) use `textFormat: Text.PlainText`, `renderType: Text.CurveRendering` on small text. Fonts: Orbitron for labels, Geist for names.
- Graphite and steel only, no hue; sharp corners (chamfers), no blur or glow as decoration. `Theme.imperial.accent` is blue, so the picker defines its own steel tokens (as in the prototype) and does not edit `Theme.qml`.
- Visual checks: `grim -g "<x>,<y> <w>x<h>"` on a small region only, never the full screen, and only after confirming no window overlaps it (Task 7 has the helper).
- **Never call `lock lock`.** Never touch `Power.dryRun`, `Net`, `Bt`.
- Tests change the real wallpaper: record `awww query` first and restore that exact image at the end.
- Shell variables do not survive between Bash calls. Start every Bash block that uses `$QS`, `$ORIG` or `$S` with these lines (`S` is your session's scratchpad directory; Task 7 Step 1 writes `orig-wallpaper.txt` into it):
  ```bash
  QS="qs ipc -p /home/tk421/Development/quickshell/shell.qml call wallpaper"
  S=/tmp/claude-1000/-home-tk421-Development-quickshell/a50055ea-8ffc-42a7-bde2-0d718834a611/scratchpad
  ORIG=$(cat "$S/orig-wallpaper.txt" 2>/dev/null)
  ```
- Folder: `~/Pictures/Wallpapers`; extensions `png jpg jpeg webp gif`; the `.mp4` is ignored. State file: `wallpaper/state.json` (git-ignored). IPC target `wallpaper`: `toggle`, `isOpen`, `next`, `prev`, `effect <id>`, `apply`, `cancel`, `status`, `list`.
- Effect ids and labels: `laser` SUPERLASER (1000 ms, default), `hyperspace` HYPERSPACE (1200 ms), `doors` BLAST DOORS (1000 ms), `scan` TACTICAL SCAN (900 ms); reduced motion: 260 ms crossfade.

## Review Focus

The spec implies these inputs and conditions but does not list them; each has a test in the task that owns the code.

1. **Awkward file names** (spaces, `#`, `%`, `[ ]`, unicode, bidi/control characters, very long): URLs must resolve, shown names must be clean and at most 40 characters. → Task 1 (`fileUrl`, `displayName`), Task 2 (`magick` with brackets).
2. **Zero, one or two images, and an applied wallpaper that is not in the folder** (it is today: the Destroyer image lives under `~/Projects`): wrap-around, offsets and the bay must not break or duplicate plates; the applied wallpaper always appears in the bay. → Task 1 (`offset`, `stepIndex`, `withApplied`), Task 7 (IPC).
3. **`state.json` missing, corrupt, wrong effect, or pointing at a file that is gone**: fall back to the live `awww` image and Superlaser; the login restore falls back to the default image. → Task 1 (`parseState`), Task 6 (`restore.sh` tests).
4. **Fast key repeat, Esc mid-transition, Enter without a change**: a new request finishes the running transition instead of queueing; Esc returns to the original; Enter on an unchanged selection does not call `awww` or rewrite the state. → Task 1 (`needsApply`), Task 7 (IPC burst, cancel, no-op apply).
5. **`awww` failing, or a file that cannot be decoded**: the stage stays on the last good image, a `Hud` pill names the problem, the stored state is untouched; an undecodable file drops out of the bay. → Task 2 (`drop`), Task 7 (a deliberately broken test file).
6. **More wallpapers than lamps** (the lintel shows at most 24 lamps): the lit lamp still tracks the selection. → Task 1 (`lampIndex`).

## File Structure

| File | Responsibility |
|---|---|
| `wallpaper/logic.js` (create) | Pure rules: file filter/sort, wrap-around, plate slots, effects, names, URLs, `awww` args, state parsing, easings |
| `tests/qml/tst_wallpaperlogic.qml` (create) | Unit tests for `logic.js` |
| `services/Wallpaper.qml` (create) | Singleton model: folder, applied/shown, selection, effect, apply through `awww`, persistence, IPC |
| `wallpaper/effects/Cover.qml` (create) | `Image` that covers its box, decoded at screen width |
| `wallpaper/effects/{Crossfade,Superlaser,Hyperspace,BlastDoors,TacticalScan}.qml` (create) | The five transitions, one interface |
| `wallpaper/WallpaperStage.qml` (create) | Bottom-layer window: resting image, running effect, preloading, hand-over |
| `wallpaper/{Ease,Grooves,DoorLeaf,DoorJamb,Plate,KeyHint}.qml` (create) | Small parts of the door |
| `wallpaper/WallpaperPicker.qml` (create) | The picker window: door, lintel, bay, sill, keys |
| `wallpaper/restore.sh` (create), `tests/wallpaper-restore.sh` (create) | Login restore and its test |
| `services/qmldir`, `shell.qml`, `.gitignore`, `hypr/hyprland.lua`, `CLAUDE.md` (modify) | Registration, wiring, bind, boot restore, docs |

---

### Task 1: Pure logic and its tests

**Files:**
- Create: `wallpaper/logic.js`
- Create: `tests/qml/tst_wallpaperlogic.qml`

**Interfaces:**
- Produces (all in `wallpaper/logic.js`, imported as `import "../wallpaper/logic.js" as Logic`):
  `EFFECTS: string[]`, `LABELS: {id: string}`, `isImage(name) -> bool`, `listImages(names) -> string[]`, `withApplied(files, applied) -> string[]`, `offset(i, sel, n) -> int`, `slot(off) -> {x, scale, opacity}`, `isNear(off) -> bool`, `stepIndex(i, step, n) -> int`, `stepEffect(cur, step) -> string`, `isEffect(id) -> bool`, `duration(id, reduced) -> ms`, `displayName(path) -> string`, `fileUrl(path) -> string`, `awwwArgs(path) -> string[]`, `parseAwwwQuery(text) -> string`, `parseState(text) -> {path, effect}`, `serializeState(path, effect) -> string`, `needsApply(applied, selected) -> bool`, `lampIndex(sel, n, max) -> int`, `clamp(x, a?, b?)`, `easeInCubic`, `easeOutCubic`, `easeOutQuart`, `easeOutExpo`, `easeInOutCubic`, `easeInOutQuart` (all `t -> number`).

- [ ] **Step 1: Write the failing tests**

Create `tests/qml/tst_wallpaperlogic.qml`:

```qml
import QtQuick
import QtTest

import "../../wallpaper/logic.js" as WP

TestCase {
    name: "WallpaperLogic"

    // ---- folder listing ----
    function test_isImage_by_extension_and_hidden() {
        compare(WP.isImage("a.png"), true)
        compare(WP.isImage("A.JPG"), true)
        compare(WP.isImage("a.jpeg"), true)
        compare(WP.isImage("a.webp"), true)
        compare(WP.isImage("a.gif"), true)
        compare(WP.isImage("clip.mp4"), false)
        compare(WP.isImage(".hidden.png"), false)
        compare(WP.isImage("png"), false)
        compare(WP.isImage(""), false)
        compare(WP.isImage(undefined), false)
    }

    function test_listImages_filters_and_sorts_case_insensitively() {
        compare(WP.listImages(["b.png", "A.jpg", "c.mp4", "a.png", ".x.png", ""]), ["A.jpg", "a.png", "b.png"])
        compare(WP.listImages([]), [])
        compare(WP.listImages(null), [])
    }

    function test_withApplied_always_shows_the_applied_wallpaper() {
        compare(WP.withApplied(["/w/a.png", "/w/b.png"], "/w/b.png"), ["/w/a.png", "/w/b.png"])
        compare(WP.withApplied(["/w/a.png"], "/elsewhere/d.png"), ["/elsewhere/d.png", "/w/a.png"])
        compare(WP.withApplied([], "/elsewhere/d.png"), ["/elsewhere/d.png"])
        compare(WP.withApplied(["/w/a.png"], ""), ["/w/a.png"])
        compare(WP.withApplied([], ""), [])
    }

    // ---- wrap-around and plates ----
    function test_offset_wraps_to_the_nearest_side() {
        compare(WP.offset(0, 0, 9), 0)
        compare(WP.offset(1, 0, 9), 1)
        compare(WP.offset(8, 0, 9), -1)
        compare(WP.offset(4, 0, 9), 4)
        compare(WP.offset(5, 0, 9), -4)
        compare(WP.offset(0, 8, 9), 1)
    }

    function test_offset_with_few_images() {
        compare(WP.offset(0, 0, 1), 0)                 // one image: it is the selection, no neighbour
        compare(WP.offset(1, 0, 2), -1)                // two images: the other one appears once
        compare(WP.offset(0, 1, 2), -1)
        compare(WP.offset(1, 0, 3), 1)
        compare(WP.offset(2, 0, 3), -1)
        compare(WP.offset(0, 0, 0), 0)                 // empty folder
    }

    function test_slot_by_distance() {
        compare(WP.slot(0), { x: 0, scale: 1, opacity: 1 })
        compare(WP.slot(1), { x: 310, scale: 0.6, opacity: 0.95 })
        compare(WP.slot(-1), { x: -310, scale: 0.6, opacity: 0.95 })
        compare(WP.slot(2), { x: 505, scale: 0.4, opacity: 0.5 })
        compare(WP.slot(-3), { x: -700, scale: 0.3, opacity: 0 })   // parked, invisible
        compare(WP.slot(7), { x: 700, scale: 0.3, opacity: 0 })
    }

    function test_isNear_keeps_only_close_plates_decoded() {
        compare(WP.isNear(0), true)
        compare(WP.isNear(-3), true)
        compare(WP.isNear(3), true)
        compare(WP.isNear(4), false)
        compare(WP.isNear(-4), false)
    }

    function test_stepIndex_wraps_and_survives_empty() {
        compare(WP.stepIndex(8, 1, 9), 0)
        compare(WP.stepIndex(0, -1, 9), 8)
        compare(WP.stepIndex(3, 0, 9), 3)
        compare(WP.stepIndex(12, 0, 9), 3)
        compare(WP.stepIndex(0, 1, 1), 0)
        compare(WP.stepIndex(0, 1, 0), 0)
    }

    function test_lampIndex_tracks_the_selection_when_there_are_too_many() {
        compare(WP.lampIndex(3, 9, 24), 3)
        compare(WP.lampIndex(0, 48, 24), 0)
        compare(WP.lampIndex(47, 48, 24), 23)
        compare(WP.lampIndex(24, 48, 24), 12)
    }

    // ---- effects ----
    function test_stepEffect_cycles_and_recovers_from_unknown_ids() {
        compare(WP.stepEffect("laser", 1), "hyperspace")
        compare(WP.stepEffect("scan", 1), "laser")
        compare(WP.stepEffect("laser", -1), "scan")
        compare(WP.stepEffect("bogus", 1), "hyperspace")
    }

    function test_isEffect() {
        compare(WP.isEffect("doors"), true)
        compare(WP.isEffect("nope"), false)
        compare(WP.isEffect(undefined), false)
    }

    function test_duration() {
        compare(WP.duration("laser", false), 1000)
        compare(WP.duration("hyperspace", false), 1200)
        compare(WP.duration("doors", false), 1000)
        compare(WP.duration("scan", false), 900)
        compare(WP.duration("scan", true), 260)
        compare(WP.duration("bogus", false), 1000)
    }

    function test_labels() {
        compare(WP.LABELS.laser, "SUPERLASER")
        compare(WP.LABELS.hyperspace, "HYPERSPACE")
        compare(WP.LABELS.doors, "BLAST DOORS")
        compare(WP.LABELS.scan, "TACTICAL SCAN")
    }

    // ---- names and URLs (they come from outside) ----
    function test_displayName_cleans_the_file_name() {
        compare(WP.displayName("/x/stormtrooper-oled_4k.jpg"), "stormtrooper oled 4k")
        compare(WP.displayName("/x/My Wall #1.png"), "My Wall #1")
        compare(WP.displayName("/x/wall [4k].png"), "wall [4k]")
        compare(WP.displayName("/x/a‮b‏c.png"), "abc")          // bidi overrides removed
        compare(WP.displayName("/x/a\u0007b\u001bc.png"), "abc")          // control characters removed
        compare(WP.displayName("/x/.png"), "UNTITLED")
        compare(WP.displayName("/x/é.png"), "é")
    }

    function test_displayName_is_at_most_40_characters() {
        var long = WP.displayName("/x/" + new Array(80).join("a") + ".png")
        compare(long.length, 40)
        compare(long.charAt(39), "…")
        compare(WP.displayName("/x/" + new Array(41).join("b") + ".png").length, 40)   // exactly 40: untouched
    }

    function test_fileUrl_escapes_what_a_url_cannot_carry() {
        compare(WP.fileUrl("/a b/c#d%e.png"), "file:///a%20b/c%23d%25e.png")
        compare(WP.fileUrl("/é.png"), "file:///%C3%A9.png")
        compare(WP.fileUrl("/w/wall [4k].png"), "file:///w/wall%20%5B4k%5D.png")
        compare(WP.fileUrl("/home/u/Pictures/a.jpg"), "file:///home/u/Pictures/a.jpg")
    }

    // ---- awww ----
    function test_awwwArgs() {
        compare(WP.awwwArgs("/w/a b.png"), ["awww", "img", "--transition-type", "none", "/w/a b.png"])
    }

    function test_parseAwwwQuery() {
        compare(WP.parseAwwwQuery(": DP-1: 2560x1080, scale: 1, currently displaying: image: /home/u/Pictures/Wallpapers/a.jpg\n"), "/home/u/Pictures/Wallpapers/a.jpg")
        compare(WP.parseAwwwQuery(": DP-1: 2560x1080, scale: 1, currently displaying: image: /w/my wall.png"), "/w/my wall.png")
        compare(WP.parseAwwwQuery(": DP-1: 2560x1080, scale: 1, currently displaying: color: 000000"), "")
        compare(WP.parseAwwwQuery(""), "")
        compare(WP.parseAwwwQuery(undefined), "")
    }

    // ---- state file ----
    function test_parseState_valid() {
        compare(WP.parseState('{"path":"/w/a.png","effect":"scan"}'), { path: "/w/a.png", effect: "scan" })
    }

    function test_parseState_falls_back_on_anything_wrong() {
        compare(WP.parseState(""), { path: "", effect: "laser" })
        compare(WP.parseState("not json"), { path: "", effect: "laser" })
        compare(WP.parseState("[]"), { path: "", effect: "laser" })
        compare(WP.parseState("null"), { path: "", effect: "laser" })
        compare(WP.parseState('{"path":5,"effect":"warp"}'), { path: "", effect: "laser" })
        compare(WP.parseState('{"path":"/w/a.png"}'), { path: "/w/a.png", effect: "laser" })
    }

    function test_serializeState_round_trips() {
        compare(WP.parseState(WP.serializeState("/w/a b.png", "doors")), { path: "/w/a b.png", effect: "doors" })
        compare(WP.parseState(WP.serializeState("/w/a.png", "bogus")), { path: "/w/a.png", effect: "laser" })
    }

    function test_needsApply_only_when_the_selection_differs() {
        compare(WP.needsApply("/w/a.png", "/w/b.png"), true)
        compare(WP.needsApply("/w/a.png", "/w/a.png"), false)
        compare(WP.needsApply("/w/a.png", ""), false)
        compare(WP.needsApply("", "/w/b.png"), true)
    }

    // ---- easings and clamp ----
    function test_clamp() {
        compare(WP.clamp(2), 1)
        compare(WP.clamp(-1), 0)
        compare(WP.clamp(0.4), 0.4)
        compare(WP.clamp(5, 0, 10), 5)
        compare(WP.clamp(-5, 0, 10), 0)
    }

    function test_easings_start_at_0_and_end_at_1() {
        var fns = [WP.easeInCubic, WP.easeOutCubic, WP.easeOutQuart, WP.easeOutExpo, WP.easeInOutCubic, WP.easeInOutQuart]
        for (var i = 0; i < fns.length; i++) {
            fuzzyCompare(fns[i](0), 0, 0.001)
            fuzzyCompare(fns[i](1), 1, 0.001)
        }
        fuzzyCompare(WP.easeInOutCubic(0.5), 0.5, 0.001)
        fuzzyCompare(WP.easeInOutQuart(0.5), 0.5, 0.001)
        verify(WP.easeOutQuart(0.5) > 0.5)
        verify(WP.easeInCubic(0.5) < 0.5)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd /home/tk421/Development/quickshell && QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_wallpaperlogic.qml 2>&1 | tail -15`
Expected: FAIL: the import of `wallpaper/logic.js` cannot be resolved.

- [ ] **Step 3: Write the implementation**

Create `wallpaper/logic.js`:

```js
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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd /home/tk421/Development/quickshell && QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml 2>&1 | tail -8`
Expected: every test passes, including the existing `tst_logic`, `tst_netlogic`, `tst_power`, `tst_soundlogic`, `tst_traylogic`; `Totals: ... 0 failed`.
If `compare` on objects or arrays fails with the right values, switch that assertion to `compare(JSON.stringify(x), JSON.stringify(y))`.

- [ ] **Step 5: Checkpoint**

No commit (see Global Constraints). Confirm `git status --short wallpaper tests` lists only the two new paths.

---

### Task 2: `Wallpaper` service

**Files:**
- Create: `services/Wallpaper.qml`
- Modify: `services/qmldir` (one line)
- Modify: `shell.qml` (one property, so the singleton starts with the shell)
- Modify: `.gitignore` (one line)

**Interfaces:**
- Consumes: everything in `wallpaper/logic.js` from Task 1; `Hud.show(label, state, glyph, image)` from `services/Hud.qml`.
- Produces (`Wallpaper`, singleton): properties `active: bool` (readonly), `files: var` (absolute paths), `applied: string`, `shown: string`, `selected: int`, `effect: string`, `open: bool`, `reducedMotion: bool`, `dimensions: string`, `applying: bool` (readonly); signal `replay()`; functions `show()`, `cancel()`, `commit()`, `toggle()`, `step(d)`, `select(i)`, `cycleEffect(d)`, `setEffect(id)`, `neighbor(d) -> string`, `drop(path)`, `refresh()`. IPC target `wallpaper`.

- [ ] **Step 1: Write `services/Wallpaper.qml`**

```qml
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

import "../wallpaper/logic.js" as Logic

// Wallpaper picker model. `awww` is the real wallpaper; wallpaper/WallpaperStage.qml draws the transitions above it and
// wallpaper/WallpaperPicker.qml is the door. `shown` is what the desktop should display right now: the selection while the
// picker is open, `applied` otherwise. Spec: docs/superpowers/specs/2026-10-14-wallpaper-picker-design.md
Singleton {
    id: root

    readonly property bool active: true
    readonly property string dir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    readonly property string stateFile: Quickshell.shellPath("wallpaper/state.json")

    property var folderFiles: []          // what is in the folder (absolute paths)
    property var files: []                // folderFiles plus the applied wallpaper when it lives elsewhere
    property string applied: ""           // what awww is painting
    property string shown: ""
    property int selected: 0
    property string effect: "laser"
    property bool open: false
    property bool reducedMotion: false
    property string dimensions: ""        // "1920×804 · PNG" of the selection
    readonly property bool applying: applier.running

    property string statePath: ""         // path stored in state.json
    property string queryPath: ""         // path reported by `awww query` (the truth, when it answers)
    property string pending: ""

    // The picker asks the stage to play the effect again (after the effect changed).
    signal replay()

    function rebuild() {
        const keep = open ? shown : applied
        const next = Logic.withApplied(folderFiles, applied)

        if (next.join("\n") !== files.join("\n"))
            files = next

        const i = files.indexOf(keep)
        if (i >= 0) {
            selected = i
        } else {
            const j = files.indexOf(applied)
            selected = j >= 0 ? j : 0
            shown = applied
        }

        if (!open)
            shown = applied
    }

    // awww's own answer wins; the stored path is the fallback when the daemon does not answer.
    function resolveApplied() {
        const path = queryPath !== "" ? queryPath : statePath
        if (path === "" || path === applied)
            return

        applied = path
        rebuild()
    }

    function loadState(text) {
        const s = Logic.parseState(text)
        effect = s.effect
        statePath = s.path
        resolveApplied()
    }

    function save() {
        stateView.setText(Logic.serializeState(applied, effect))
    }

    function listed(text) {
        folderFiles = Logic.listImages(text.split("\n")).map(n => dir + "/" + n)
        rebuild()
    }

    function refresh() {
        if (!lister.running)
            lister.running = true
    }

    function describe(path) {
        if (!open || path === "")
            return

        identifier.running = false
        identifier.command = ["magick", "identify", "-ping", "-format", "%w×%h · %m", path + "[0]"]
        identifier.running = true
    }

    function show() {
        refresh()
        shown = applied
        const i = files.indexOf(applied)
        selected = i >= 0 ? i : 0
        open = true
        describe(shown)
    }

    function toggle() {
        open ? cancel() : show()
    }

    function select(i) {
        if (files.length === 0)
            return

        selected = Logic.stepIndex(i, 0, files.length)
        shown = files[selected]
    }

    function step(d) {
        if (open && files.length > 0)
            select(selected + d)
    }

    function neighbor(d) {
        return files.length > 0 ? files[Logic.stepIndex(selected, d, files.length)] : ""
    }

    function setEffect(id) {
        if (!Logic.isEffect(id))
            return

        effect = id
        save()

        // Replaying only makes sense with something to travel between.
        if (open && files.length > 1)
            replay()
    }

    function cycleEffect(d) {
        setEffect(Logic.stepEffect(effect, d))
    }

    // Enter: keep the selection. Nothing runs when it is the wallpaper that is already applied.
    function commit() {
        const path = shown
        open = false

        if (Logic.needsApply(applied, path))
            startApply(path)
    }

    // Esc: back to the original; the stage plays the transition in reverse.
    function cancel() {
        open = false

        if (shown !== applied) {
            shown = applied
            const i = files.indexOf(applied)
            if (i >= 0)
                selected = i
        }
    }

    function startApply(path) {
        pending = path
        applier.command = Logic.awwwArgs(path)
        applier.running = true
    }

    // A file that cannot be decoded leaves the bay.
    function drop(path) {
        if (files.indexOf(path) < 0 || path === applied)
            return

        console.log("wallpaper: dropping undecodable file " + path)
        folderFiles = folderFiles.filter(f => f !== path)
        files = files.filter(f => f !== path)

        const i = files.indexOf(shown)
        selected = i >= 0 ? i : Math.max(0, Math.min(selected, files.length - 1))
        if (i < 0 && files.length > 0)
            shown = files[selected]
    }

    onShownChanged: describeTimer.restart()

    Component.onCompleted: {
        lister.running = true
        querier.running = true
        motionProbe.running = true
    }

    Timer {
        id: describeTimer

        interval: 120
        onTriggered: root.describe(root.shown)
    }

    FileView {
        id: stateView

        path: root.stateFile
        printErrors: false      // the file does not exist until the first change
        atomicWrites: true

        onLoaded: root.loadState(text())
        onLoadFailed: root.loadState("")
    }

    Process {
        id: lister

        command: ["find", "-L", root.dir, "-maxdepth", "1", "-type", "f", "-printf", "%f\n"]
        stdout: StdioCollector {
            onStreamFinished: root.listed(text)
        }
    }

    Process {
        id: querier

        command: ["awww", "query"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.queryPath = Logic.parseAwwwQuery(text)
                root.resolveApplied()
            }
        }
    }

    Process {
        id: applier

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && exitStatus === 0) {
                root.applied = root.pending
                root.save()
            } else {
                // Keep the last good wallpaper and say so; the stage returns to it.
                root.shown = root.applied
                Hud.show("WALLPAPER", "awww failed", "")
            }
        }
    }

    Process {
        id: identifier

        stdout: StdioCollector {
            onStreamFinished: root.dimensions = text.trim()
        }
    }

    // gsettings may be missing: then animations stay on.
    Process {
        id: motionProbe

        command: ["gsettings", "get", "org.gnome.desktop.interface", "enable-animations"]
        stdout: StdioCollector {
            onStreamFinished: root.reducedMotion = text.trim() === "false"
        }
    }

    IpcHandler {
        target: "wallpaper"

        function toggle(): void {
            root.toggle()
        }

        function isOpen(): bool {
            return root.open
        }

        function next(): void {
            root.step(1)
        }

        function prev(): void {
            root.step(-1)
        }

        function effect(name: string): string {
            if (!Logic.isEffect(name))
                return "unknown effect: " + name

            root.setEffect(name)
            return root.effect
        }

        function apply(): void {
            root.commit()
        }

        function cancel(): void {
            root.cancel()
        }

        function status(): string {
            return JSON.stringify({
                open: root.open,
                applied: root.applied,
                shown: root.shown,
                selected: root.selected,
                count: root.files.length,
                effect: root.effect,
                applying: root.applying,
                reducedMotion: root.reducedMotion,
                dimensions: root.dimensions
            })
        }

        function list(): string {
            return root.files.join("\n")
        }
    }
}
```

- [ ] **Step 2: Lint the new file**

Run: `cd /home/tk421/Development/quickshell && /usr/lib/qt6/bin/qmllint -I /usr/lib/qt6/qml services/Wallpaper.qml 2>&1 | grep -iE "error|syntax" | head`
Expected: no output (warnings about unresolved imports of the singleton registry are fine; any `Error` or syntax message must be fixed first).

- [ ] **Step 3: Register the singleton, start it with the shell, ignore the state file**

Run (asserts each match count is exactly 1, then writes):

```bash
cd /home/tk421/Development/quickshell && python3 - <<'EOF'
def patch(path, old, new):
    s = open(path).read()
    assert s.count(old) == 1, (path, old, s.count(old))
    open(path, "w").write(s.replace(old, new))

patch("services/qmldir", "singleton Sound Sound.qml\n", "singleton Sound Sound.qml\nsingleton Wallpaper Wallpaper.qml\n")
patch("shell.qml",
      "    property bool dropdownActive: Dropdown.active && Power.active && Net.active && Bt.active && Sound.active\n",
      "    property bool dropdownActive: Dropdown.active && Power.active && Net.active && Bt.active && Sound.active\n\n    // The wallpaper model (folder, state, IPC) starts with the shell.\n    property bool wallpaperActive: Wallpaper.active\n")
patch(".gitignore", "__pycache__/\n", "__pycache__/\nwallpaper/state.json\n")
EOF
sleep 2; qs log -p /home/tk421/Development/quickshell/shell.qml 2>&1 | awk '/Reloading configuration/{buf=""} {buf=buf $0 "\n"} END{printf "%s", buf}' | grep -E "WARN|ERROR" | grep -v "enableSurface\|disableSurface" | head
```
Expected: no output from the log filter (zero new `WARN|ERROR` after the reload this save caused).

- [ ] **Step 4: Check the model through IPC**

```bash
QS="qs ipc -p /home/tk421/Development/quickshell/shell.qml call wallpaper"
awww query
$QS status
$QS list | head -3
$QS list | wc -l
$QS effect scan
$QS effect bogus
$QS effect laser
cat /home/tk421/Development/quickshell/wallpaper/state.json
```
Expected:
- `status` is JSON whose `applied` equals the image in `awww query`, `effect` is `laser` (no state file yet), `open` is `false`, `count` is the number of images in `~/Pictures/Wallpapers` (+1 if the applied image is outside the folder), `reducedMotion` is `false`.
- `list` prints absolute paths, sorted, with no `.mp4`.
- `effect scan` prints `scan`; `effect bogus` prints `unknown effect: bogus`; `effect laser` prints `laser`.
- `state.json` holds `{"path": "<applied>", "effect": "laser"}`.

- [ ] **Step 5: Check `magick` copes with awkward names (Review Focus 1)**

```bash
T=$(mktemp -d) && magick -size 8x4 xc:black "$T/wall [4k] #1%.png" && magick identify -ping -format "%w×%h · %m\n" "$T/wall [4k] #1%.png[0]"; rm -rf "$T"
```
Expected: `8×4 · PNG`. If `magick` misreads the name, change `describe()` to pass the path as `"./"`-qualified or skip the dimensions for names containing `[`, `]`, `%`, `*`, `?`.

- [ ] **Step 6: Remove the test state and checkpoint**

Run: `rm -f /home/tk421/Development/quickshell/wallpaper/state.json`
No commit. The service is live but inert: nothing opens it until Tasks 4 and 5.

---

### Task 3: The transition effects

**Files:**
- Create: `wallpaper/effects/Cover.qml`, `Crossfade.qml`, `Superlaser.qml`, `Hyperspace.qml`, `BlastDoors.qml`, `TacticalScan.qml`

**Interfaces:**
- Consumes: easings and `clamp` from `wallpaper/logic.js` (`import "../logic.js" as L`).
- Produces: every effect is an `Item` with `property url fromSource`, `property url toSource`, `property real progress` (0..1, driven linearly by the stage, each effect applies its own easing) and `property int decodeWidth`. `Cover` is an `Image` that fills its box (crop, centred) and decodes at `decodeWidth`.

The effects are written from the prototype's `render(p)` functions (`prototypes/wallpaper/index.html`, `FX.laser`, `FX.hyperspace`, `FX.doors`, `FX.scan`); keep the numbers.

- [ ] **Step 1: `wallpaper/effects/Cover.qml`**

```qml
import QtQuick

// A wallpaper image that covers its box (crop, centred) like `awww img --resize crop`, decoded at screen width.
// Every Image in the stage uses the same sourceSize, so they all share one decoded texture.
Image {
    property int decodeWidth: 2560

    fillMode: Image.PreserveAspectCrop
    sourceSize.width: decodeWidth
    asynchronous: false
    cache: true
    smooth: true
}
```

- [ ] **Step 2: `wallpaper/effects/Crossfade.qml`** (reduced motion)

```qml
import QtQuick

// Reduced motion: a plain crossfade.
Item {
    id: fx

    property url fromSource
    property url toSource
    property real progress: 0
    property int decodeWidth: 2560

    Cover {
        anchors.fill: parent
        source: fx.fromSource
        decodeWidth: fx.decodeWidth
    }

    Cover {
        anchors.fill: parent
        source: fx.toSource
        decodeWidth: fx.decodeWidth
        opacity: fx.progress
    }
}
```

- [ ] **Step 3: `wallpaper/effects/Superlaser.qml`**

```qml
import QtQuick
import QtQuick.Effects

import "../logic.js" as L

// 1. SUPERLASER (default): eight beams converge on the centre, flash, a ring of light opens the new wallpaper from the centre.
// Reference: FX.laser in prototypes/wallpaper/index.html.
Item {
    id: fx

    property url fromSource
    property url toSource
    property real progress: 0
    property int decodeWidth: 2560

    readonly property real charge: 0.22
    readonly property real cx: width / 2
    readonly property real cy: height / 2
    readonly property real chargeT: L.clamp(progress / charge)
    readonly property real expand: L.clamp((progress - charge) / (1 - charge))
    readonly property real maxR: Math.hypot(cx, cy) * 1.02
    readonly property real radius: maxR * L.easeOutQuart(expand)
    readonly property real fade: Math.pow(1 - expand, 0.7)

    // A ring centred on (cx, cy) with radius `r` and stroke `w`. (Inline components cannot see ids of the enclosing file, so the
    // centre is passed in.)
    component Ring: Rectangle {
        property real cx: 0
        property real cy: 0
        property real r: 0
        property real w: 1

        x: cx - (r + w / 2)
        y: cy - (r + w / 2)
        width: 2 * (r + w / 2)
        height: width
        radius: width / 2
        color: "transparent"
        border.width: w
    }

    Cover {
        anchors.fill: parent
        source: fx.fromSource
        decodeWidth: fx.decodeWidth
    }

    // The old wallpaper dips while the ring passes.
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.4 * Math.sin(Math.PI * Math.min(1, fx.expand * 1.3))
    }

    // The new wallpaper, revealed through a growing circle.
    Item {
        anchors.fill: parent
        visible: fx.progress >= fx.charge
        layer.enabled: visible
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: circle
        }

        Cover {
            anchors.fill: parent
            source: fx.toSource
            decodeWidth: fx.decodeWidth
            scale: 1 + 0.05 * (1 - L.easeOutCubic(fx.expand))
        }
    }

    Item {
        id: circle

        anchors.fill: parent
        visible: false
        layer.enabled: true

        Rectangle {
            x: fx.cx - fx.radius
            y: fx.cy - fx.radius
            width: fx.radius * 2
            height: width
            radius: fx.radius
            color: "white"
        }
    }

    // Light ring on the edge, and a fainter wider one standing in for the glow.
    Ring {
        cx: fx.cx
        cy: fx.cy
        visible: fx.progress >= fx.charge && fx.expand < 1
        r: fx.radius
        w: 1.5 + 3.5 * (1 - fx.expand)
        border.color: Qt.rgba(0.94, 0.96, 0.95, fx.fade)
    }

    Ring {
        cx: fx.cx
        cy: fx.cy
        visible: fx.progress >= fx.charge && fx.expand < 1
        r: fx.radius
        w: 10 + 14 * (1 - fx.expand)
        border.color: Qt.rgba(0.94, 0.96, 0.95, 0.12 * fx.fade)
    }

    // Charge: eight beams converge on the centre.
    Repeater {
        model: 8

        Item {
            id: beam

            required property int index
            readonly property real rs: Math.min(fx.width, fx.height) * 0.55
            readonly property real head: rs * (1 - L.easeInCubic(fx.chargeT))
            readonly property real tail: Math.min(rs, head + rs * 0.3)

            x: fx.cx
            y: fx.cy
            rotation: index * 45 + 22.5
            visible: fx.progress < fx.charge

            Rectangle {
                x: beam.head
                y: -0.75
                width: beam.tail - beam.head
                height: 1.5
                color: Qt.rgba(0.93, 0.94, 0.93, 0.85)
            }
        }
    }

    // The core grows during the charge, then flashes out as the ring leaves.
    Item {
        id: core

        readonly property real size: fx.progress < fx.charge ? 4 + 46 * fx.chargeT * fx.chargeT : 260

        anchors.centerIn: parent
        width: size * 3
        height: width
        opacity: fx.progress < fx.charge ? 0.3 + 0.7 * fx.chargeT : L.clamp(1 - fx.expand * 3.2)
        visible: opacity > 0.01
        layer.enabled: visible
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 64
            blur: 1.0
        }

        Rectangle {
            anchors.centerIn: parent
            width: core.size * 2
            height: width
            radius: core.size
            color: "white"
        }
    }
}
```

- [ ] **Step 4: `wallpaper/effects/Hyperspace.qml`**

```qml
import QtQuick
import QtQuick.Effects

import "../logic.js" as L

// 2. HYPERSPACE: stars streak out of the centre while the old wallpaper stretches, white flash, the new one drops out of lightspeed.
// Reference: FX.hyperspace in prototypes/wallpaper/index.html.
Item {
    id: fx

    property url fromSource
    property url toSource
    property real progress: 0
    property int decodeWidth: 2560

    readonly property real split: 0.46
    readonly property real cx: width / 2
    readonly property real cy: height / 2
    readonly property real maxR: Math.hypot(cx, cy)
    readonly property real v: L.clamp((progress - split) / (1 - split))
    // Speed accelerates to the jump and decelerates out of it; `dist` is the distance travelled so far.
    readonly property real speed: progress < split ? L.easeInCubic(progress / split) : Math.pow(2, -9 * v)
    readonly property real dist: progress < split ? 0.1125 * Math.pow(progress / split, 4) : 0.1125 + 0.0794 * (1 - Math.pow(2, -9 * v))
    readonly property real stretch: L.easeInCubic(L.clamp(progress / split))
    readonly property real settle: L.easeOutExpo(v)

    property var stars: makeStars(400)

    function makeStars(n) {
        const out = []
        for (let i = 0; i < n; i++)
            out.push({ a: Math.random() * Math.PI * 2, d: 0.015 + Math.random() * 0.5, z: 0.25 + Math.random() * 0.75 })
        return out
    }

    // The old wallpaper zooms and blurs toward the jump.
    Cover {
        anchors.fill: parent
        source: fx.fromSource
        decodeWidth: fx.decodeWidth
        visible: fx.progress < fx.split + 0.04
        scale: 1 + 0.14 * fx.stretch
        layer.enabled: visible && fx.stretch > 0.02
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 32
            blur: fx.stretch * 0.075
            brightness: 0.35 * fx.stretch
        }
    }

    // The new wallpaper drops out of lightspeed.
    Cover {
        anchors.fill: parent
        source: fx.toSource
        decodeWidth: fx.decodeWidth
        visible: fx.progress >= fx.split
        scale: 1 + 0.22 * (1 - fx.settle)
        layer.enabled: visible && fx.settle < 0.98
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 32
            blur: 0.19 * (1 - fx.settle)
            brightness: 0.3 * (1 - fx.settle)
        }
    }

    Repeater {
        model: fx.stars

        Rectangle {
            required property var modelData

            readonly property real out: modelData.d * fx.maxR * (1 + fx.dist * 14 * modelData.z)
            readonly property real tail: out / (1 + fx.speed * 4.2 * modelData.z)

            visible: out < fx.maxR * 1.05 && out - tail > 0.5
            x: fx.cx + Math.cos(modelData.a) * tail
            y: fx.cy + Math.sin(modelData.a) * tail - height / 2
            width: out - tail
            height: 0.6 + modelData.z * 1.6
            radius: height / 2
            transformOrigin: Item.Left
            rotation: modelData.a * 180 / Math.PI
            color: Qt.rgba(0.91, 0.93, 0.94, L.clamp(0.25 + fx.speed * 0.75) * (0.4 + modelData.z * 0.6))
        }
    }

    // The jump itself.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.96, 0.965, 0.97, 1)
        opacity: 0.92 * Math.max(0, 1 - Math.abs(fx.progress - fx.split) / 0.09)
        visible: opacity > 0.01
    }
}
```

- [ ] **Step 5: `wallpaper/effects/BlastDoors.qml`**

```qml
import QtQuick

import "../logic.js" as L

// 3. BLAST DOORS: the old wallpaper is cut into nine slats that part from the centre like the picker's own door, middle slats first.
// Reference: FX.doors in prototypes/wallpaper/index.html. All slats share one decoded texture.
Item {
    id: fx

    property url fromSource
    property url toSource
    property real progress: 0
    property int decodeWidth: 2560

    readonly property int rows: 9
    readonly property real rh: height / rows
    readonly property real lag: 0.3
    readonly property real arrive: L.easeOutCubic(progress)

    // The new wallpaper waits behind the slats, dim at first.
    Cover {
        anchors.fill: parent
        source: fx.toSource
        decodeWidth: fx.decodeWidth
        scale: 1 + 0.04 * (1 - fx.arrive)
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.45 * (1 - fx.arrive)
    }

    Repeater {
        model: fx.rows

        Item {
            id: row

            required property int index
            readonly property real d: Math.abs(index - (fx.rows - 1) / 2) / ((fx.rows - 1) / 2)
            readonly property real e: L.easeInOutQuart(L.clamp((fx.progress - d * fx.lag) / (1 - fx.lag)))

            y: index * fx.rh
            width: fx.width
            height: fx.rh + 1

            Repeater {
                model: 2

                Item {
                    id: half

                    required property int index         // 0 = left half, 1 = right half
                    readonly property real dir: index === 0 ? -1 : 1

                    x: index * fx.width / 2 + dir * (fx.width / 2) * 1.005 * row.e
                    width: fx.width / 2
                    height: row.height
                    clip: true
                    visible: row.e < 1

                    // Each slat shows its own slice of the full-screen image.
                    Cover {
                        x: -half.index * fx.width / 2
                        y: -row.y
                        width: fx.width
                        height: fx.height
                        source: fx.fromSource
                        decodeWidth: fx.decodeWidth
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.07)
                    }

                    Rectangle {
                        y: parent.height - 1
                        width: parent.width
                        height: 1
                        color: Qt.rgba(0, 0, 0, 0.6)
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 6: `wallpaper/effects/TacticalScan.qml`**

```qml
import QtQuick

import "../../theme"
import "../logic.js" as L

// 4. TACTICAL SCAN: a scan line sweeps left to right; the new wallpaper is already there behind it.
// Reference: FX.scan in prototypes/wallpaper/index.html.
Item {
    id: fx

    property url fromSource
    property url toSource
    property real progress: 0
    property int decodeWidth: 2560

    readonly property real lineX: width * L.easeInOutCubic(progress)
    readonly property bool sweeping: progress > 0 && progress < 1

    Cover {
        anchors.fill: parent
        source: fx.fromSource
        decodeWidth: fx.decodeWidth
    }

    Item {
        width: Math.max(0, fx.lineX)
        height: parent.height
        clip: true

        Cover {
            width: fx.width
            height: fx.height
            source: fx.toSource
            decodeWidth: fx.decodeWidth
        }
    }

    // Trail behind the line.
    Rectangle {
        visible: fx.sweeping
        width: Math.min(150, fx.lineX)
        x: fx.lineX - width
        height: parent.height
        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop { position: 0; color: Qt.rgba(0.93, 0.94, 0.93, 0) }
            GradientStop { position: 1; color: Qt.rgba(0.93, 0.94, 0.93, 0.16) }
        }
    }

    // The line, its ticks and the readout.
    Rectangle {
        visible: fx.sweeping
        x: Math.round(fx.lineX) - 1
        width: 1.5
        height: parent.height
        color: Qt.rgba(0.96, 0.965, 0.97, 0.95)
    }

    Repeater {
        model: Math.ceil(fx.height / 24)

        Rectangle {
            required property int index

            visible: fx.sweeping
            x: Math.round(fx.lineX) + 1
            y: index * 24
            width: index % 4 === 0 ? 14 : 7
            height: 1
            color: Qt.rgba(0.96, 0.965, 0.97, 0.85)
        }
    }

    Text {
        visible: fx.sweeping
        x: Math.round(fx.lineX) + 22
        y: 44
        text: "X " + String(Math.round(fx.lineX)).padStart(4, "0")
        color: Qt.rgba(0.96, 0.965, 0.97, 0.9)
        font.family: Theme.displayFont
        font.pixelSize: 11
        font.weight: Font.Medium
        font.letterSpacing: 1.6
        renderType: Text.CurveRendering
    }
}
```

- [ ] **Step 7: Lint every effect**

Run: `cd /home/tk421/Development/quickshell && /usr/lib/qt6/bin/qmllint -I /usr/lib/qt6/qml -I . wallpaper/effects/*.qml 2>&1 | grep -iE "error|syntax" | head`
Expected: no output. (`Cover` resolves because the files share a directory.)

- [ ] **Step 8: Checkpoint**

No commit; the effects are not instantiated anywhere yet, so the live shell is unaffected.

---

### Task 4: The stage window

**Files:**
- Create: `wallpaper/WallpaperStage.qml`
- Modify: `shell.qml` (import and instance)

**Interfaces:**
- Consumes: `Wallpaper` (`open`, `applying`, `shown`, `applied`, `effect`, `reducedMotion`, `neighbor(d)`, signal `replay()`), `Logic.duration`, `Logic.fileUrl`, the five effect components from Task 3.
- Produces: a `PanelWindow` (namespace `tk421-wallpaper-stage`, layer Bottom, empty input mask, no keyboard focus) that is visible only while the picker is open, a transition runs, or an apply is in flight (plus 80 ms after, so the hand-over to `awww` never shows a gap).

- [ ] **Step 1: Write `wallpaper/WallpaperStage.qml`**

```qml
import Quickshell
import Quickshell.Wayland
import QtQuick

import "../services"
import "effects"
import "logic.js" as Logic

// Draws what the desktop shows while the picker is open or a transition runs, on the Bottom layer: above the awww background,
// below every window, click-through. awww stays the real wallpaper; on Enter the model calls `awww img` and this window hides
// right after, so both show the same image (both crop to cover, centred). The window is transparent wherever nothing is drawn,
// so a still-decoding image shows the awww wallpaper underneath, never black.
PanelWindow {
    id: win

    readonly property int decodeWidth: Math.max(1280, width)

    property string resting: ""          // the image at rest
    property string fromPath: ""
    property string toPath: ""
    property bool running: false
    property real progress: 0
    property bool lingering: false
    readonly property bool busy: Wallpaper.open || Wallpaper.applying || running

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: (busy || lingering) && resting !== ""

    // An empty region: the whole window is click-through.
    mask: Region {}

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "tk421-wallpaper-stage"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    onBusyChanged: {
        if (busy) {
            lingering = true
            release.stop()
        } else {
            release.restart()
        }
    }

    Timer {
        id: release

        interval: 80
        onTriggered: win.lingering = false
    }

    // Start a transition to `path`. A request that arrives mid-transition finishes the running one first (nothing queues).
    // `from` makes the stage start from another image (used to replay an effect).
    function go(path, from) {
        if (path === "")
            return

        if (running)
            finish()

        if (resting === "") {
            resting = path
            return
        }

        if (from !== undefined && from !== "")
            resting = from

        if (path === resting)
            return

        fromPath = resting
        toPath = path
        progress = 0
        anim.duration = Logic.duration(Wallpaper.effect, Wallpaper.reducedMotion)
        running = true
        anim.restart()
    }

    function finish() {
        anim.stop()

        if (running) {
            resting = toPath
            progress = 1
            running = false
        }
    }

    function effectComponent(id) {
        return id === "hyperspace" ? hyper : id === "doors" ? doors : id === "scan" ? scan : laser
    }

    NumberAnimation {
        id: anim

        target: win
        property: "progress"
        from: 0
        to: 1
        onFinished: win.finish()
    }

    Component { id: laser; Superlaser {} }
    Component { id: hyper; Hyperspace {} }
    Component { id: doors; BlastDoors {} }
    Component { id: scan; TacticalScan {} }
    Component { id: crossfade; Crossfade {} }

    Connections {
        target: Wallpaper

        function onShownChanged() {
            win.go(Wallpaper.shown)
        }

        function onReplay() {
            win.go(Wallpaper.shown, Wallpaper.neighbor(-1))
        }

        function onOpenChanged() {
            if (Wallpaper.open && !win.running)
                win.resting = Wallpaper.applied
        }
    }

    // Keeps the images that are likely next decoded, so an effect never waits on a 4K file. ScriptModel diffs, so the
    // images that stay in the list are not reloaded when the selection moves.
    ScriptModel {
        id: preload

        values: [win.resting, Wallpaper.shown, Wallpaper.neighbor(-1), Wallpaper.neighbor(1)].filter(p => p !== "")
    }

    Item {
        anchors.fill: parent

        Repeater {
            model: preload

            Image {
                required property string modelData

                visible: false
                asynchronous: true
                source: Logic.fileUrl(modelData)
                sourceSize.width: win.decodeWidth
                fillMode: Image.PreserveAspectCrop
            }
        }

        Image {
            id: restImg

            anchors.fill: parent
            source: win.resting !== "" ? Logic.fileUrl(win.resting) : ""
            sourceSize.width: win.decodeWidth
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready && !fx.active
        }

        // The effect stays loaded after it ends until the resting image is ready, so there is no gap between them.
        Loader {
            id: fx

            anchors.fill: parent
            active: win.running || (win.toPath !== "" && win.resting !== "" && restImg.status !== Image.Ready)
            sourceComponent: Wallpaper.reducedMotion ? crossfade : win.effectComponent(Wallpaper.effect)

            onLoaded: {
                item.fromSource = Logic.fileUrl(win.fromPath)
                item.toSource = Logic.fileUrl(win.toPath)
                item.decodeWidth = win.decodeWidth
                item.progress = Qt.binding(() => win.progress)
            }
        }
    }
}
```

- [ ] **Step 2: Lint**

Run: `cd /home/tk421/Development/quickshell && /usr/lib/qt6/bin/qmllint -I /usr/lib/qt6/qml -I . wallpaper/WallpaperStage.qml 2>&1 | grep -iE "error|syntax" | head`
Expected: no output.

- [ ] **Step 3: Wire it into `shell.qml` (one reload)**

```bash
cd /home/tk421/Development/quickshell && python3 - <<'EOF'
def patch(path, old, new):
    s = open(path).read()
    assert s.count(old) == 1, (path, old, s.count(old))
    open(path, "w").write(s.replace(old, new))

patch("shell.qml", 'import "usage"\n', 'import "usage"\nimport "wallpaper"\n')
patch("shell.qml", "    UsageCard {}\n", "    UsageCard {}\n    WallpaperStage {}\n")
EOF
sleep 2; qs log -p /home/tk421/Development/quickshell/shell.qml 2>&1 | awk '/Reloading configuration/{buf=""} {buf=buf $0 "\n"} END{printf "%s", buf}' | grep -E "WARN|ERROR" | grep -v "enableSurface\|disableSurface" | head
```
Expected: no output. If the stage logs errors, fix the file and save it once more.

- [ ] **Step 4: Verify the stage through IPC (the picker does not exist yet, so nothing grabs the keyboard)**

```bash
QS="qs ipc -p /home/tk421/Development/quickshell/shell.qml call wallpaper"
ORIG=$(awww query | sed -n 's/.*image: //p'); echo "original: $ORIG"
$QS toggle; sleep 1
hyprctl layers -j | jq -r '.[].levels | to_entries[] | .key as $l | .value[] | "\($l) \(.namespace)"' | grep wallpaper
$QS next; sleep 1.5; $QS status
$QS cancel; sleep 1.5; $QS status
sleep 0.3
hyprctl layers -j | jq -r '.[].levels | to_entries[] | .key as $l | .value[] | "\($l) \(.namespace)"' | grep -c wallpaper
awww query
```
Expected:
- First `grep` prints `1 tk421-wallpaper-stage` (level 1 is Bottom).
- After `next`, `status` has `open: true` and `shown` different from `applied`; after `cancel`, `open: false` and `shown` equals `applied`.
- The last `grep -c` prints `0` (the stage hides itself once idle) and `awww query` still shows `$ORIG`.
- Ask the user to watch the desktop while you run `$QS toggle`, `$QS effect <id>`, then `$QS next` for each of `laser`, `hyperspace`, `doors`, `scan`, and `$QS cancel` at the end: each transition should look like the prototype, with no black frame at the start or the end. Record what they report. Finish with `$QS effect laser`, and `rm -f wallpaper/state.json` if it was created.

- [ ] **Step 5: Checkpoint**

No commit. The stage is live; the door comes next.

---

### Task 5: The door (picker window)

**Files:**
- Create: `wallpaper/Ease.qml`, `Grooves.qml`, `DoorLeaf.qml`, `DoorJamb.qml`, `Plate.qml`, `KeyHint.qml`, `WallpaperPicker.qml`
- Modify: `shell.qml` (instance)

**Interfaces:**
- Consumes: `Wallpaper` (`open`, `files`, `selected`, `effect`, `dimensions`, `shown`, `step`, `select`, `cycleEffect`, `setEffect`, `commit`, `cancel`, `drop`), `Logic` (`EFFECTS`, `LABELS`, `offset`, `slot`, `isNear`, `lampIndex`, `displayName`, `fileUrl`), `Theme`.
- Produces: `WallpaperPicker` (Overlay layer, namespace `tk421-wallpaper-picker`, exclusive keyboard focus while open). Keys: ← → ↑ ↓ Enter Esc. Click on a plate selects, click on an effect name selects it, click outside the door cancels.

Geometry (design px, `u = min(1, width * 0.000734)`, so the door is 1280 px wide on the 2560 px screen): lintel 44, bay 340, sill 50, plates 400×225, chamfer 16. The prototype is the visual reference; match it.

- [ ] **Step 1: `wallpaper/Ease.qml`**

```qml
import QtQuick

// The exponential ease-out used across the shell (launcher, island).
NumberAnimation {
    easing.type: Easing.BezierSpline
    easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
}
```

- [ ] **Step 2: `wallpaper/Grooves.qml`**

```qml
import QtQuick

// The ribbed steel of the door: a flat base crossed by horizontal grooves (a dark line over a light one).
Rectangle {
    id: g

    property real u: 1
    readonly property real pitch: 36 * u

    Rectangle {
        width: parent.width
        height: 1
        color: Qt.rgba(1, 1, 1, 0.045)
    }

    Repeater {
        model: g.pitch > 0 ? Math.ceil(g.height / g.pitch) : 0

        Item {
            required property int index

            y: index * g.pitch
            width: g.width
            height: g.pitch

            Rectangle {
                y: 33 * g.u
                width: parent.width
                height: 2 * g.u
                color: Qt.rgba(0, 0, 0, 0.6)
            }

            Rectangle {
                y: 35 * g.u
                width: parent.width
                height: g.u
                color: Qt.rgba(1, 1, 1, 0.05)
            }
        }
    }
}
```

- [ ] **Step 3: `wallpaper/DoorLeaf.qml`**

```qml
import QtQuick

// One leaf of the blast door. It slides out of the bay and is hidden by its jamb; the opening is slow to start and slow to stop.
Item {
    id: leaf

    property int side: -1               // -1 = left leaf, 1 = right leaf
    property bool open: false
    property real u: 1
    property real bayWidth: 1280

    readonly property real closedX: side < 0 ? 0 : bayWidth / 2

    width: bayWidth / 2
    height: parent ? parent.height : 0
    x: closedX + (open ? side * width * 1.01 : 0)
    z: 5

    Behavior on x {
        SequentialAnimation {
            PauseAnimation { duration: leaf.open ? 260 : 0 }

            NumberAnimation {
                duration: leaf.open ? 820 : 520
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.65, 0, 0.2, 1, 1, 1]
            }
        }
    }

    Grooves {
        anchors.fill: parent
        u: leaf.u
        color: "#18181d"
    }

    // Sunken panel.
    Rectangle {
        x: 46 * leaf.u
        y: 40 * leaf.u
        width: parent.width - 92 * leaf.u
        height: parent.height - 80 * leaf.u
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.06)
    }

    // Seam strip at the edge that meets the other leaf, heavier than the grooves.
    Rectangle {
        x: leaf.side < 0 ? parent.width - width : 0
        width: 16 * leaf.u
        height: parent.height
        border.width: 1
        border.color: "black"
        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop { position: 0; color: "#0b0b0d" }
            GradientStop { position: 0.45; color: "#202026" }
            GradientStop { position: 1; color: "#0b0b0d" }
        }
    }
}
```

- [ ] **Step 4: `wallpaper/DoorJamb.qml`**

```qml
import QtQuick

// The jamb the leaves retract into: it keeps the door readable as a door once it is open.
Item {
    id: jamb

    property int side: -1
    property bool open: false
    property real u: 1

    width: 58 * u
    height: parent ? parent.height : 0
    z: 7

    Grooves {
        anchors.fill: parent
        u: jamb.u
        color: "#121216"
    }

    Rectangle {
        x: jamb.side < 0 ? parent.width - 1 : 0
        width: 1
        height: parent.height
        color: "#2A2A31"
    }

    // Status lamp: lit once the door is open.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 16 * jamb.u
        width: 14 * jamb.u
        height: 3 * jamb.u
        color: jamb.open ? "#F2F0ED" : "#2A2A31"

        Behavior on color {
            SequentialAnimation {
                PauseAnimation { duration: jamb.open ? 520 : 0 }
                ColorAnimation { duration: 240 }
            }
        }
    }
}
```

- [ ] **Step 5: `wallpaper/KeyHint.qml`**

```qml
import QtQuick

import "../theme"

// Key caps plus what they do, for the sill.
Row {
    id: hint

    property var caps: []
    property string label: ""
    property real u: 1

    spacing: 8 * u

    Repeater {
        model: hint.caps

        Rectangle {
            id: capBox

            required property string modelData

            width: Math.max(22 * hint.u, cap.implicitWidth + 10 * hint.u)
            height: 22 * hint.u
            color: "transparent"
            border.width: 1
            border.color: Theme.imperial.border

            Text {
                id: cap

                anchors.centerIn: parent
                text: capBox.modelData
                color: Theme.imperial.text
                textFormat: Text.PlainText
                font.family: Theme.fontFamily
                font.pixelSize: 11 * hint.u
                renderType: Text.CurveRendering
            }
        }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: hint.label
        color: Theme.imperial.muted
        font.family: Theme.displayFont
        font.pixelSize: 11 * hint.u
        font.weight: Font.Medium
        font.letterSpacing: 1.8 * hint.u
        renderType: Text.CurveRendering
    }
}
```

- [ ] **Step 6: `wallpaper/Plate.qml`**

```qml
import QtQuick

import "../services"
import "logic.js" as Logic

// One wallpaper in the bay. Position, scale and opacity follow its distance from the selection; only the nearest plates keep their
// image decoded. An image that cannot be decoded drops out of the bay.
Item {
    id: plate

    required property int index
    required property string modelData       // absolute path
    property real u: 1
    property int selected: 0
    property int count: 1
    property bool revealed: false            // false while the door is shut; true: the plates fade in from the centre outwards
    property color steel: "#B9B6B2"
    property color steelText: "#F2F0ED"
    property color edge: "#3F3E44"

    readonly property int off: Logic.offset(index, selected, count)
    readonly property var place: Logic.slot(off)
    readonly property bool current: off === 0
    property real fadeIn: revealed ? 1 : 0
    property real slotScale: place.scale

    width: 400 * u
    height: 225 * u
    x: parent.width / 2 - width / 2 + place.x * u
    y: parent.height / 2 - height / 2
    scale: slotScale * (0.92 + 0.08 * fadeIn)
    opacity: place.opacity * fadeIn
    z: 10 - Math.abs(off)
    visible: opacity > 0.01

    Behavior on x { Ease { duration: 560 } }
    Behavior on slotScale { Ease { duration: 560 } }

    Behavior on fadeIn {
        SequentialAnimation {
            PauseAnimation { duration: plate.revealed ? Math.abs(plate.off) * 70 + 460 : 0 }
            NumberAnimation { duration: 420 }
        }
    }

    Image {
        anchors.fill: parent
        source: Logic.isNear(plate.off) ? Logic.fileUrl(plate.modelData) : ""
        sourceSize.width: 480
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true

        onStatusChanged: {
            if (status === Image.Error)
                Wallpaper.drop(plate.modelData)
        }
    }

    // Plates that are not selected are dimmed.
    Rectangle {
        anchors.fill: parent
        color: "#050505"
        opacity: plate.current ? 0 : 0.38

        Behavior on opacity { NumberAnimation { duration: 420 } }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: 1
        border.color: plate.current ? plate.steel : plate.edge

        Behavior on border.color { ColorAnimation { duration: 200 } }
    }

    // Corner brackets on the selected plate.
    Item {
        anchors.fill: parent
        opacity: plate.current ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 260 } }

        Repeater {
            model: 4

            Item {
                id: corner

                required property int index
                readonly property bool atLeft: index % 2 === 0
                readonly property bool atTop: index < 2

                x: atLeft ? -9 * plate.u : plate.width + 9 * plate.u - width
                y: atTop ? -9 * plate.u : plate.height + 9 * plate.u - height
                width: 14 * plate.u
                height: width

                Rectangle {
                    y: corner.atTop ? 0 : corner.height - 1
                    width: corner.width
                    height: 1
                    color: plate.steelText
                }

                Rectangle {
                    x: corner.atLeft ? 0 : corner.width - 1
                    width: 1
                    height: corner.height
                    color: plate.steelText
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Wallpaper.select(plate.index)
    }
}
```

- [ ] **Step 7: `wallpaper/WallpaperPicker.qml`**

```qml
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes

import "../services"
import "../theme"
import "logic.js" as Logic

// Wallpaper picker: a blast door in the middle of the screen. The leaves part (and retract into the jambs) to show a bay with the
// wallpapers; ← → move the selection and the desktop behind changes live (wallpaper/WallpaperStage.qml); ↑ ↓ pick the transition
// effect; Enter keeps the wallpaper, Esc restores the original. Prototype: prototypes/wallpaper/index.html
// IPC lives in services/Wallpaper.qml (target `wallpaper`).
PanelWindow {
    id: win

    // Graphite and steel only, as the prototype and the launcher. Theme.imperial.accent is blue, so the steel tokens live here.
    readonly property QtObject k: QtObject {
        readonly property color surface: Theme.imperial.surface
        readonly property color border: Theme.imperial.border
        readonly property color text: Theme.imperial.text
        readonly property color muted: Theme.imperial.muted
        readonly property color steel: "#B9B6B2"
        readonly property color steelText: "#F2F0ED"
        readonly property color lamp: "#2A2A31"
        readonly property color bay: "#060608"
    }

    readonly property real u: Math.min(1, width * 0.000734)      // 1 design px: the door is 1280 wide on a 2560 px screen
    readonly property bool open: Wallpaper.open
    readonly property int count: Wallpaper.files.length

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: open || door.opacity > 0.01

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "tk421-wallpaper-picker"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: {
        if (open)
            keys.forceActiveFocus()
    }

    Item {
        id: keys

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Right)
                Wallpaper.step(1)
            else if (event.key === Qt.Key_Left)
                Wallpaper.step(-1)
            else if (event.key === Qt.Key_Down)
                Wallpaper.cycleEffect(1)
            else if (event.key === Qt.Key_Up)
                Wallpaper.cycleEffect(-1)
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                Wallpaper.commit()
            else if (event.key === Qt.Key_Escape)
                Wallpaper.cancel()
            else
                return

            event.accepted = true
        }
    }

    // A light scrim: the desktop behind is the preview, so it must stay readable. Click outside the door cancels.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(5 / 255, 5 / 255, 5 / 255, 0.3)
        opacity: win.open ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: win.open ? 360 : 220 } }

        MouseArea {
            anchors.fill: parent
            onClicked: Wallpaper.cancel()
        }
    }

    Item {
        id: door

        readonly property real ch: 16 * win.u            // corner chamfer

        width: 1280 * win.u
        height: 434 * win.u
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.985

        Behavior on opacity { NumberAnimation { duration: win.open ? 220 : 180 } }
        Behavior on scale { Ease { duration: win.open ? 520 : 260 } }

        // Swallows clicks on the door so they do not reach the scrim.
        MouseArea { anchors.fill: parent }

        // The frame: a chamfered plate with a 1 px steel edge.
        Shape {
            anchors.fill: parent
            layer.enabled: true
            layer.samples: 4

            ShapePath {
                fillColor: win.k.surface
                strokeColor: win.k.border
                strokeWidth: 1

                PathPolyline {
                    path: [
                        Qt.point(door.ch, 0.5),
                        Qt.point(door.width - door.ch, 0.5),
                        Qt.point(door.width - 0.5, door.ch),
                        Qt.point(door.width - 0.5, door.height - door.ch),
                        Qt.point(door.width - door.ch, door.height - 0.5),
                        Qt.point(door.ch, door.height - 0.5),
                        Qt.point(0.5, door.height - door.ch),
                        Qt.point(0.5, door.ch),
                        Qt.point(door.ch, 0.5)
                    ]
                }
            }
        }

        // ---------- lintel: the effect names (left), one lamp per wallpaper (right) ----------
        Item {
            id: lintel

            width: parent.width
            height: 44 * win.u

            Rectangle {
                y: parent.height - 1
                width: parent.width
                height: 1
                color: win.k.border
            }

            Row {
                id: tabs

                x: 28 * win.u
                height: parent.height
                spacing: 26 * win.u

                Repeater {
                    model: Logic.EFFECTS

                    Item {
                        id: tab

                        required property string modelData
                        readonly property bool on: Wallpaper.effect === modelData

                        width: label.implicitWidth
                        height: tabs.height

                        Text {
                            id: label

                            anchors.verticalCenter: parent.verticalCenter
                            text: Logic.LABELS[tab.modelData]
                            color: tab.on ? win.k.steelText : hover.containsMouse ? win.k.text : win.k.muted
                            font.family: Theme.displayFont
                            font.pixelSize: 12 * win.u
                            font.weight: Font.Medium
                            font.letterSpacing: 2.6 * win.u
                            renderType: Text.CurveRendering

                            Behavior on color { ColorAnimation { duration: 160 } }
                        }

                        MouseArea {
                            id: hover

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Wallpaper.setEffect(tab.modelData)
                        }

                        // The rule under the names slides to the active one.
                        Binding { target: rule; property: "x"; value: tab.x + tabs.x; when: tab.on }
                        Binding { target: rule; property: "width"; value: tab.width; when: tab.on }
                    }
                }
            }

            Rectangle {
                id: rule

                y: parent.height - 1
                height: 1
                color: win.k.steel

                Behavior on x { Ease { duration: 380 } }
                Behavior on width { Ease { duration: 380 } }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 28 * win.u
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6 * win.u

                Repeater {
                    model: Math.min(win.count, 24)

                    Rectangle {
                        required property int index
                        readonly property bool on: index === Logic.lampIndex(Wallpaper.selected, win.count, 24)

                        width: 14 * win.u * (on ? 1.5 : 1)
                        height: 3 * win.u
                        color: on ? win.k.steelText : win.k.lamp

                        Behavior on width { Ease { duration: 380 } }
                        Behavior on color { ColorAnimation { duration: 220 } }
                    }
                }
            }
        }

        // ---------- bay: dark recess; the leaves cover it until the door opens ----------
        Item {
            id: bay

            y: 44 * win.u
            width: parent.width
            height: 340 * win.u
            clip: true

            Rectangle {
                anchors.fill: parent
                color: win.k.bay
            }

            // Ceiling and floor ribs of the corridor. (Inline components cannot see ids of the enclosing file, so the geometry
            // is passed in.)
            component Ribs: Item {
                id: ribs

                required property bool floor
                property real u: 1
                property real bayWidth: 0
                property real bayHeight: 0

                y: floor ? bayHeight - 22 * u : 0
                width: bayWidth
                height: 22 * u
                z: 1

                Repeater {
                    model: 3

                    Rectangle {
                        required property int index

                        y: index * 7 * ribs.u
                        width: parent.width
                        height: 5 * ribs.u
                        color: "#121216"
                    }
                }

                Rectangle {
                    y: ribs.floor ? 0 : parent.height - 1
                    width: parent.width
                    height: 1
                    color: "#22222A"
                }
            }

            Ribs { floor: false; u: win.u; bayWidth: bay.width; bayHeight: bay.height }
            Ribs { floor: true; u: win.u; bayWidth: bay.width; bayHeight: bay.height }

            // Strip light in the ceiling: a hairline and a wash falling on the wallpapers. It comes on after the leaves start to part.
            Rectangle {
                x: bay.width * 0.12
                y: 22 * win.u
                z: 1
                width: bay.width * 0.76
                height: 150 * win.u
                opacity: win.open ? 1 : 0
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(0.95, 0.94, 0.93, 0.10) }
                    GradientStop { position: 0.85; color: Qt.rgba(0.95, 0.94, 0.93, 0) }
                }

                Behavior on opacity {
                    SequentialAnimation {
                        PauseAnimation { duration: win.open ? 380 : 0 }
                        NumberAnimation { duration: win.open ? 700 : 260 }
                    }
                }

                // The wash has no hard side edges: both ends fade into the bay colour.
                Rectangle {
                    width: parent.width * 0.22
                    height: parent.height
                    gradient: Gradient {
                        orientation: Gradient.Horizontal

                        GradientStop { position: 0; color: win.k.bay }
                        GradientStop { position: 1; color: Qt.rgba(0.024, 0.024, 0.031, 0) }
                    }
                }

                Rectangle {
                    x: parent.width * 0.78
                    width: parent.width * 0.22
                    height: parent.height
                    gradient: Gradient {
                        orientation: Gradient.Horizontal

                        GradientStop { position: 0; color: Qt.rgba(0.024, 0.024, 0.031, 0) }
                        GradientStop { position: 1; color: win.k.bay }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal

                        GradientStop { position: 0; color: Qt.rgba(0.95, 0.94, 0.93, 0) }
                        GradientStop { position: 0.22; color: Qt.rgba(0.95, 0.94, 0.93, 0.5) }
                        GradientStop { position: 0.78; color: Qt.rgba(0.95, 0.94, 0.93, 0.5) }
                        GradientStop { position: 1; color: Qt.rgba(0.95, 0.94, 0.93, 0) }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: win.count === 0
                text: "NO IMAGES"
                color: win.k.muted
                font.family: Theme.displayFont
                font.pixelSize: 12 * win.u
                font.weight: Font.Medium
                font.letterSpacing: 3 * win.u
                renderType: Text.CurveRendering
            }

            Item {
                anchors.fill: parent
                z: 2

                Repeater {
                    model: Wallpaper.files

                    Plate {
                        u: win.u
                        selected: Wallpaper.selected
                        count: win.count
                        revealed: win.open
                        steel: win.k.steel
                        steelText: win.k.steelText
                        edge: win.k.border
                    }
                }
            }

            DoorLeaf { side: -1; open: win.open; u: win.u; bayWidth: bay.width }
            DoorLeaf { side: 1; open: win.open; u: win.u; bayWidth: bay.width }
            DoorJamb { side: -1; x: 0; open: win.open; u: win.u }
            DoorJamb { side: 1; x: bay.width - width; open: win.open; u: win.u }

            // The lock between the leaves clears as they part.
            Rectangle {
                x: (bay.width - width) / 2
                y: (bay.height - height) / 2
                z: 6
                width: 4 * win.u
                height: 54 * win.u
                color: win.k.lamp
                opacity: win.open ? 0 : 1

                Behavior on opacity {
                    SequentialAnimation {
                        PauseAnimation { duration: win.open ? 260 : 0 }
                        NumberAnimation { duration: 260 }
                    }
                }
            }
        }

        // ---------- sill: name and size (left), keys (right) ----------
        Item {
            id: sill

            y: 384 * win.u
            width: parent.width
            height: 50 * win.u

            Rectangle {
                width: parent.width
                height: 1
                color: win.k.border
            }

            Row {
                x: 28 * win.u
                anchors.verticalCenter: parent.verticalCenter
                spacing: 16 * win.u

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.count > 0 ? Logic.displayName(Wallpaper.shown).toUpperCase() : "NO IMAGES"
                    color: win.k.text
                    textFormat: Text.PlainText
                    font.family: Theme.fontFamily
                    font.pixelSize: 15 * win.u
                    font.weight: Font.Medium
                    renderType: Text.CurveRendering
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Wallpaper.dimensions
                    color: win.k.muted
                    textFormat: Text.PlainText
                    font.family: Theme.displayFont
                    font.pixelSize: 11 * win.u
                    font.weight: Font.Medium
                    font.letterSpacing: 2.2 * win.u
                    renderType: Text.CurveRendering
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 28 * win.u
                anchors.verticalCenter: parent.verticalCenter
                spacing: 20 * win.u

                KeyHint { u: win.u; caps: ["←", "→"]; label: "WALLPAPER" }
                KeyHint { u: win.u; caps: ["↑", "↓"]; label: "EFFECT" }
                KeyHint { u: win.u; caps: ["↵"]; label: "APPLY" }
                KeyHint { u: win.u; caps: ["ESC"]; label: "CANCEL" }
            }
        }
    }
}
```

- [ ] **Step 8: Lint all of the picker files**

Run: `cd /home/tk421/Development/quickshell && /usr/lib/qt6/bin/qmllint -I /usr/lib/qt6/qml -I . wallpaper/*.qml 2>&1 | grep -iE "error|syntax" | head`
Expected: no output. Fix anything that appears (inline components must not reference ids of the enclosing file; this is the usual source of lint errors here).

- [ ] **Step 9: Wire the picker into `shell.qml` (one reload)**

```bash
cd /home/tk421/Development/quickshell && python3 - <<'EOF'
def patch(path, old, new):
    s = open(path).read()
    assert s.count(old) == 1, (path, old, s.count(old))
    open(path, "w").write(s.replace(old, new))

patch("shell.qml", "    WallpaperStage {}\n", "    WallpaperStage {}\n    WallpaperPicker {}\n")
EOF
sleep 2; qs log -p /home/tk421/Development/quickshell/shell.qml 2>&1 | awk '/Reloading configuration/{buf=""} {buf=buf $0 "\n"} END{printf "%s", buf}' | grep -E "WARN|ERROR" | grep -v "enableSurface\|disableSurface" | head
```
Expected: no output. **Tell the user first** that the next steps open the picker, which takes the keyboard while it is open, so they should not type until it is closed.

- [ ] **Step 10: Verify the door**

```bash
QS="qs ipc -p /home/tk421/Development/quickshell/shell.qml call wallpaper"
ORIG=$(awww query | sed -n 's/.*image: //p'); echo "original: $ORIG"
$QS toggle; sleep 2
$QS isOpen
hyprctl layers -j | jq -r '.[].levels | to_entries[] | .key as $l | .value[] | "\($l) \(.namespace)"' | grep wallpaper
grim -g "660,343 1240x394" /tmp/claude-1000/-home-tk421-Development-quickshell/a50055ea-8ffc-42a7-bde2-0d718834a611/scratchpad/door-open.png
$QS next; sleep 1.5; $QS next; sleep 1.5
grim -g "660,343 1240x394" /tmp/claude-1000/-home-tk421-Development-quickshell/a50055ea-8ffc-42a7-bde2-0d718834a611/scratchpad/door-next.png
$QS cancel; sleep 1.5; awww query
```
Expected:
- `isOpen` is `true`; the layers list shows `1 tk421-wallpaper-stage` and `3 tk421-wallpaper-picker` (level 3 is Overlay).
- The two screenshots (the region is inside the door, which is opaque) show the door as in `prototypes/wallpaper/index.html`: lintel with the four effect names and the lamps, jambs on both sides, five plates with the selected one framed by corner brackets, sill with name, size and key hints. The second shows a different selected plate.
- After `cancel`, `awww query` still shows `$ORIG` (nothing was applied).
- Ask the user to press `Super+Alt+B` themselves only after Task 6 adds the bind.

- [ ] **Step 11: Checkpoint**

No commit. Record any visual difference from the prototype that the user points out and fix it in the file it belongs to (one save per fix).

---

### Task 6: Login restore and the `Super+Alt+B` bind

**Files:**
- Create: `wallpaper/restore.sh`, `tests/wallpaper-restore.sh`
- Modify: `hypr/hyprland.lua` (two exact replacements; `hypr/` is a symlink to `~/.config/hypr`, so this is the live Hyprland config)

**Interfaces:**
- Consumes: `wallpaper/state.json` as written by `Wallpaper.save()` (`{"path": "...", "effect": "..."}`).
- Produces: `wallpaper/restore.sh` paints the saved wallpaper with `awww` (or the default image when there is no usable state); `restore.sh --print` only prints the path it would paint; `WALLPAPER_STATE=<file>` overrides the state file (for tests).

**Refinement of the spec:** the spec had the shell restore the wallpaper at login. The existing "TK421 SESSION STARTUP" block in `hypr/hyprland.lua` already waits for `awww-daemon` and paints a fixed image, so the restore goes there, through this script, and the shell only reads the state (no race between two painters). The user approves the exact diff below by approving this plan.

- [ ] **Step 1: Write the failing test**

Create `tests/wallpaper-restore.sh`:

```sh
#!/bin/sh
# Tests for wallpaper/restore.sh in --print mode, so awww is never called. Run: sh tests/wallpaper-restore.sh
here=$(cd "$(dirname "$0")/.." && pwd)
script="$here/wallpaper/restore.sh"
default=/home/tk421/Projects/tk421/theme-engine/collections/star-wars/imperial-destroyer/wallpaper.png
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0

expect() {   # name, wanted, got
    if [ "$2" = "$3" ]; then
        echo "ok   $1"
    else
        echo "FAIL $1: wanted [$2] got [$3]"
        fail=1
    fi
}

run() {      # state file
    WALLPAPER_STATE="$1" "$script" --print 2>/dev/null
}

img="$tmp/my wall #1.png"
: > "$img"
printf '{"path": "%s", "effect": "scan"}' "$img" > "$tmp/valid.json"
expect "valid state, awkward name"  "$img"     "$(run "$tmp/valid.json")"

printf '{"path": "%s/gone.png"}' "$tmp" > "$tmp/gone.json"
expect "saved file is gone"         "$default" "$(run "$tmp/gone.json")"

printf 'not json' > "$tmp/corrupt.json"
expect "corrupt state"              "$default" "$(run "$tmp/corrupt.json")"

printf '[]' > "$tmp/array.json"
expect "state is an array"          "$default" "$(run "$tmp/array.json")"

printf '{"path": 5}' > "$tmp/number.json"
expect "path is not a string"       "$default" "$(run "$tmp/number.json")"

printf '{"path": ""}' > "$tmp/empty.json"
expect "empty path"                 "$default" "$(run "$tmp/empty.json")"

expect "no state file"              "$default" "$(run "$tmp/none.json")"

exit $fail
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd /home/tk421/Development/quickshell && sh tests/wallpaper-restore.sh; echo "exit $?"`
Expected: seven `FAIL` lines (the script does not exist yet) and `exit 1`.

- [ ] **Step 3: Write `wallpaper/restore.sh`**

```sh
#!/bin/sh
# Paints the wallpaper saved by the picker (wallpaper/state.json), or the default one when there is no usable state.
# Run at login by hypr/hyprland.lua once awww-daemon is up. `restore.sh --print` only prints the path it would paint.
dir=$(cd "$(dirname "$0")" && pwd)
state=${WALLPAPER_STATE:-$dir/state.json}
default=/home/tk421/Projects/tk421/theme-engine/collections/star-wars/imperial-destroyer/wallpaper.png

path=$(jq -r 'if (.path | type) == "string" then .path else empty end' "$state" 2>/dev/null)
if [ -z "$path" ] || [ ! -f "$path" ]; then
    path=$default
fi

if [ "$1" = "--print" ]; then
    printf '%s\n' "$path"
    exit 0
fi

exec /usr/bin/awww img --transition-type none "$path"
```

Then: `chmod +x /home/tk421/Development/quickshell/wallpaper/restore.sh`

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd /home/tk421/Development/quickshell && sh tests/wallpaper-restore.sh; echo "exit $?"`
Expected: seven `ok` lines and `exit 0`.

- [ ] **Step 5: Edit the live Hyprland config (exact diff, assert each match once)**

The two changes:

```diff
 hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
+-- Wallpaper picker: Quickshell (wallpaper/). SUPER+ALT+B opens the blast door; there is no other picker to fall back to.
+hl.bind(
+	"SUPER + ALT + B",
+	hl.dsp.exec_cmd("quickshell ipc -p /home/tk421/Development/quickshell/shell.qml call wallpaper toggle")
+)
```
(inserted just before the `+ P` bind), and in the "TK421 SESSION STARTUP" block the last command of the `exec_cmd` string changes from `/usr/bin/awww img --transition-type none /home/tk421/Projects/tk421/theme-engine/collections/star-wars/imperial-destroyer/wallpaper.png` to `/home/tk421/Development/quickshell/wallpaper/restore.sh`.

```bash
cd /home/tk421/Development/quickshell && cp hypr/hyprland.lua /tmp/hyprland.lua.before-wallpaper && python3 - <<'EOF'
def patch(path, old, new):
    s = open(path).read()
    assert s.count(old) == 1, (path, old[:60], s.count(old))
    open(path, "w").write(s.replace(old, new))

p = "hypr/hyprland.lua"
patch(p, 'hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())\n',
      '-- Wallpaper picker: Quickshell (wallpaper/). SUPER+ALT+B opens the blast door; there is no other picker to fall back to.\n'
      'hl.bind(\n\t"SUPER + ALT + B",\n'
      '\thl.dsp.exec_cmd("quickshell ipc -p /home/tk421/Development/quickshell/shell.qml call wallpaper toggle")\n)\n'
      'hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())\n')
patch(p, '/usr/bin/awww img --transition-type none /home/tk421/Projects/tk421/theme-engine/collections/star-wars/imperial-destroyer/wallpaper.png")',
      '/home/tk421/Development/quickshell/wallpaper/restore.sh")')
EOF
sleep 2
hyprctl configerrors
hyprctl binds -j | jq -c '.[] | select((.key | ascii_downcase) == "b" and .modmask == 5)'
```
Expected: `hyprctl configerrors` prints nothing (or `no errors`), and exactly one bind object comes back for key `B` with modmask 5 (CTRL = 4, SHIFT = 1). If Hyprland reports an error, restore `/tmp/hyprland.lua.before-wallpaper` over `hypr/hyprland.lua` and fix the edit.

- [ ] **Step 6: Checkpoint**

No commit. Tell the user the bind is live and that the login restore only takes effect at the next login (it runs in `hyprland.start`).

---

### Task 7: End-to-end verification, docs, spec sync

**Files:**
- Modify: `CLAUDE.md` (two exact insertions), `docs/superpowers/specs/2026-10-14-wallpaper-picker-design.md` (file names and the boot paragraph)

- [ ] **Step 1: Record the starting point and run the whole test suite**

```bash
cd /home/tk421/Development/quickshell
QS="qs ipc -p /home/tk421/Development/quickshell/shell.qml call wallpaper"
S=/tmp/claude-1000/-home-tk421-Development-quickshell/a50055ea-8ffc-42a7-bde2-0d718834a611/scratchpad
ORIG=$(awww query | sed -n 's/.*image: //p'); echo "original: $ORIG"
echo "$ORIG" > "$S/orig-wallpaper.txt"
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml 2>&1 | tail -4
sh tests/wallpaper-restore.sh
rm -f wallpaper/state.json
```
Expected: `0 failed` from the QML tests, seven `ok` lines from the restore test. Keep `$ORIG`: every later step ends by returning to it. **Tell the user** that the next steps open the picker (it takes the keyboard while open) and change the wallpaper, and that they should not type until you say it is done.

- [ ] **Step 2: Flow, burst, cancel and no-op apply (Review Focus 2, 4)**

```bash
S0=$($QS status | jq -r .selected); N=$($QS status | jq -r .count); echo "start $S0 of $N"
$QS toggle; sleep 1
for i in 1 2 3 4 5; do $QS next; done; sleep 2
$QS status | jq -c '{open, selected, count, effect, shown: (.shown | split("/") | last)}'
$QS next; $QS cancel; sleep 2
$QS status | jq -c '{open, applied: (.applied | split("/") | last), shown: (.shown | split("/") | last)}'
awww query
rm -f wallpaper/state.json; $QS toggle; sleep 1; $QS apply; sleep 1
ls wallpaper/state.json 2>&1 | head -1
awww query
```
Expected: after five quick `next`, `selected` equals `(S0 + 5) mod N` and nothing is left running; after `next` + `cancel` the `shown` equals `applied` and `awww query` still shows `$ORIG`; the no-op `apply` leaves `wallpaper/state.json` absent (`No such file`) and `awww query` unchanged. Zero new `WARN|ERROR` in the log (filter as in Task 2 Step 3).

- [ ] **Step 3: Apply for real, persistence, and the hand-over (Review Focus 3)**

```bash
$QS toggle; sleep 1; $QS next; sleep 1.5; $QS apply; sleep 2
awww query
cat wallpaper/state.json
hyprctl layers -j | jq -r '.[].levels | to_entries[] | .value[] | .namespace' | grep -c wallpaper
$QS status | jq -c '{open, applying, applied: (.applied | split("/") | last)}'
```
Expected: `awww query` shows the next image (different from `$ORIG`); `state.json` holds that path and `"effect": "laser"`; the layer count is `0` (stage and picker are gone, so the hand-over finished); `open` and `applying` are `false`. Ask the user whether they saw a flash or a jump at the moment the door closed; they should not have.

Then check the state survives a shell reload (two saves of `shell.qml`: add a comment line, then remove it):

```bash
echo "// reload probe" >> shell.qml; sleep 3
$QS status | jq -c '{applied: (.applied | split("/") | last), effect}'
python3 - <<'EOF'
p = "/home/tk421/Development/quickshell/shell.qml"
s = open(p).read()
assert s.count("// reload probe\n") == 1
open(p, "w").write(s.replace("// reload probe\n", ""))
EOF
sleep 3
$QS status | jq -c '{applied: (.applied | split("/") | last), effect}'
```
Expected: both `status` calls report the new image and `laser`.

Return to the original through the model (so its in-memory state is right):

```bash
$QS toggle; sleep 1
for i in $(seq 1 40); do [ "$($QS status | jq -r .shown)" = "$ORIG" ] && break; $QS next; sleep 0.25; done
$QS apply; sleep 2; awww query
```
Expected: `awww query` shows `$ORIG` again. If the loop could not find it, restore with `awww img --transition-type none "$ORIG"`, `rm -f wallpaper/state.json`, and tell the user the shell needs a reload.

- [ ] **Step 4: Failure paths (Review Focus 5)**

An apply that `awww` rejects (the file disappears between selecting and applying), and a file that cannot be decoded:

```bash
W=$HOME/Pictures/Wallpapers
magick -size 64x64 xc:gray20 "$W/zz-test-copy.png"
printf 'this is not an image' > "$W/zz-broken-test.png"
$QS toggle; sleep 1
$QS list | grep -c "zz-test-copy\|zz-broken-test"
for i in $(seq 1 40); do case "$($QS status | jq -r .shown)" in *zz-test-copy.png) break;; esac; $QS next; sleep 0.25; done
sleep 1.5
$QS list | grep -c "zz-broken-test"
rm -f "$W/zz-test-copy.png"
$QS apply; sleep 2
$QS status | jq -c '{open, applied: (.applied | split("/") | last), shown: (.shown | split("/") | last)}'
awww query
ls wallpaper/state.json 2>&1 | head -1
rm -f "$W/zz-broken-test.png"
```
Expected: the first `grep -c` prints `2` (both files listed); after the walk the second `grep -c` prints `0` (the undecodable file dropped out of the bay once its plate tried to load); after the failed apply `applied` and `awww query` still show `$ORIG`, `shown` equals `applied` (the stage returned to the last good image), `state.json` is absent, and the island showed a `WALLPAPER awww failed` pill (ask the user if they saw it). `zz-test-copy.png` and `zz-broken-test.png` must be gone from the folder afterwards (`ls "$W" | grep zz-` prints nothing).

- [ ] **Step 5: Look at the door (a region inside it only)**

```bash
S=/tmp/claude-1000/-home-tk421-Development-quickshell/a50055ea-8ffc-42a7-bde2-0d718834a611/scratchpad
$QS toggle; sleep 2
grim -g "660,343 1240x394" $S/door-final.png
$QS cancel
```
Read `$S/door-final.png` and compare with `prototypes/wallpaper/index.html?open=1`. The region is inside the opaque door; never capture outside it. Then ask the user to press `Super+Alt+B` themselves and walk through: ←/→, ↑/↓ on all four effects, Enter, `Super+Alt+B` then Esc. Ask them specifically about the open question from the spec: whether the Superlaser reads well when the door hides its origin, and whether the effect names and the door size feel right. Fix what they report in the file it belongs to, one save per fix.

- [ ] **Step 6: Document it in `CLAUDE.md` (exact insertions, assert each match once)**

```bash
cd /home/tk421/Development/quickshell && python3 - <<'EOF'
def patch(path, old, new):
    s = open(path).read()
    assert s.count(old) == 1, (path, old[:60], s.count(old))
    open(path, "w").write(s.replace(old, new))

patch("CLAUDE.md",
      "  - `dropdown`: `open <power|tray|menu|net|bt|sound>`",
      "  - `wallpaper`: `toggle`, `isOpen`, `next`, `prev`, `effect <laser|hyperspace|doors|scan>`, `apply`, `cancel`, `status`, `list` (the picker; `next`/`prev` only act while it is open). **Tests change the real desktop wallpaper**: note `awww query` first and return to that image through the model (`apply`), never leave the picker open.\n"
      "  - `dropdown`: `open <power|tray|menu|net|bt|sound>`")

patch("CLAUDE.md",
      "- **`usage/`** is the Claude plan-limits widget",
      "- **`wallpaper/`** is the wallpaper picker (spec `docs/superpowers/specs/2026-10-14-wallpaper-picker-design.md`, plan `docs/superpowers/plans/2026-10-14-wallpaper-picker.md`, prototype `prototypes/wallpaper/index.html`). `SUPER+ALT+B` (bind in `hypr/hyprland.lua`) calls `wallpaper toggle`: a blast door opens in the middle of the screen, ←/→ change the wallpaper live, ↑/↓ pick the transition (SUPERLASER default, HYPERSPACE, BLAST DOORS, TACTICAL SCAN), Enter keeps it, Esc restores the original. **`awww` stays the real wallpaper.** `services/Wallpaper.qml` is the model (folder `~/Pictures/Wallpapers`, `applied`/`shown`, effect, IPC, persistence in git-ignored `wallpaper/state.json`); `WallpaperStage` is a Bottom-layer, click-through window (above the awww background, below every window) that draws the transition and hides right after `awww img --transition-type none` has taken the new image; `WallpaperPicker` is the door (Overlay layer, exclusive keyboard); `effects/*.qml` share one interface (`fromSource`, `toSource`, `progress`) and are ported from the prototype's `render(p)`. `wallpaper/logic.js` is pure and tested (`tests/qml/tst_wallpaperlogic.qml`). `wallpaper/restore.sh` runs from the \"TK421 SESSION STARTUP\" block of `hypr/hyprland.lua` at login and repaints the saved wallpaper (`tests/wallpaper-restore.sh`). The applied wallpaper always appears in the bay, even when it lives outside the folder. `Theme.imperial.accent` is blue, so the picker keeps its own steel tokens. Inline `component X:` types cannot see ids of the enclosing file: pass what they need as properties.\n"
      "- **`usage/`** is the Claude plan-limits widget")
EOF
grep -c "wallpaper" CLAUDE.md
```
Expected: `grep -c` prints a number above 2 and no assertion error appeared (each anchor matched exactly once; other sessions edit `CLAUDE.md`, so a count of 0 or 2 means re-read the file and pick a new exact anchor).

- [ ] **Step 7: The spec already matches the plan**

The spec was synced while this plan was written (file names `WallpaperPicker`/`WallpaperStage`, the applied wallpaper always in the bay, ~400 stars, and the boot restore through `restore.sh`). Check that nothing drifted during execution:

Run: `cd /home/tk421/Development/quickshell && grep -n "Picker.qml\|Stage.qml\|Boot restore" docs/superpowers/specs/2026-10-14-wallpaper-picker-design.md | cut -c1-120`
Expected: only the `Wallpaper…` file names and the new boot paragraph. If an implementation choice changed while executing (a different file name, an effect number), update the spec in the same change.

- [ ] **Step 8: Final state**

```bash
cd /home/tk421/Development/quickshell
awww query                                  # must show $ORIG
ls ~/Pictures/Wallpapers | grep -c "zz-"    # must print 0
$QS isOpen                                  # must print false
ls wallpaper/state.json 2>&1 | head -1      # absent, unless the user applied something themselves
qs log -p /home/tk421/Development/quickshell/shell.qml 2>&1 | awk '/Reloading configuration/{buf=""} {buf=buf $0 "\n"} END{printf "%s", buf}' | grep -E "WARN|ERROR" | grep -v "enableSurface\|disableSurface" | head
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml 2>&1 | tail -3
sh tests/wallpaper-restore.sh
```
Expected: the original wallpaper, no leftover test files, picker closed, no new `WARN|ERROR`, all tests green. Tell the user it is done; remind them that the login restore applies at the next login, and that nothing was committed.

---

## Self-review (against the spec)

- **Behaviour:** source and filter (Task 1, 2), open/close and the door's opening (Task 5), keys and click handling (Task 5), live preview with interruption and replay on effect change (Tasks 2, 4), four effects plus the reduced-motion crossfade (Tasks 3, 4), remembered effect (Task 2).
- **Architecture:** `awww` as the base, stage window on the Bottom layer with an empty mask, hand-over on apply, cancel by reversing, failure keeps the last good image with a `Hud` pill (Tasks 2, 4); units and files match the spec table; IPC names match.
- **State and boot:** `state.json` git-ignored (Task 2), restore through the existing startup block (Task 6, a stated refinement of the spec, synced in Task 7).
- **Errors and safety:** names are plain text, cleaned and cut (Tasks 1, 5), undecodable files dropped (Tasks 2, 5, 7), decoded sizes bounded (Tasks 3, 4: screen width for the stage, 480 px for plates, only the seven nearest plates loaded).
- **Testing:** logic and restore tests (Tasks 1, 6), IPC flows and failure paths (Task 7), region-only `grim` (Tasks 5, 7), the wallpaper is restored at the end.
- **Open points from the spec** (Superlaser origin hidden by the door, beam colour, lock screen) are put to the user in Task 7 Step 5; the lock screen stays out of scope.
- **Not covered, on purpose:** automatic frame-rate measurement (the user judges smoothness by eye in Tasks 4 and 7), and a real `uinput` key test (the user presses the real bind).
