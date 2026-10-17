# Power menu and system tray — Implementation Plan

> **For agentic workers:** execute inline with superpowers:executing-plans. Steps use checkboxes.

**Goal:** Add the power button + dropdown and the system tray capsule to the bar, sharing one dropdown slot.

**Architecture:** Three singletons (`Dropdown`, `Hud`, `Power`) hold state; `dropdown/DropdownHost.qml` is the single window that shows the active panel; pure rules live in two unit-tested `.js` files.

**Tech Stack:** Quickshell 0.3.2 (`Quickshell.Services.SystemTray`, `QsMenuOpener`, `Quickshell.Hyprland` `HyprlandFocusGrab`, `Quickshell.execDetached`), Qt 6 `qmltestrunner`.

**Spec:** `docs/superpowers/specs/2026-10-12-power-and-tray-design.md`. Visual reference: `prototypes/toolbar/index.html`.

## Global Constraints

- The running shell is the user's desktop and **hot-reloads on every save**. Another session edits this repo too: **never overwrite shared files** (`shell.qml`, `bar/Toolbar.qml`, `bar/Bar.qml`, `island/Island.qml`), patch them with exact-match replacements that assert their match count. Write each new QML file once, lint it first: `/usr/lib/qt6/bin/qmllint -I /usr/lib/qt6/qml <file>`; treat `[syntax]`, `[incompatible-type]`, `[import]` as blockers (`transient`-style reserved words, etc.).
- **Never run a real power action while building.** `Power.dryRun` stays `true` in code until the final step. Never call `lock lock`.
- No commits (the repo has none; CLAUDE.md). Ledger: `.superpowers/sdd/power-and-tray/progress.md`.
- Palette `Theme.imperial.*`; fonts Orbitron (labels/digits), Geist (UI), `Theme.iconFont` for glyphs (Font Awesome codepoints: lock ``, moon ``, sign-out ``, refresh ``, power-off ``, chevron-down ``, check ``, chevron-right ``, chevron-left ``, times ``). `textFormat: Text.PlainText` for anything from outside; `renderType: Text.CurveRendering` for small text.
- Motion: easing `[0.22, 1, 0.36, 1, 1, 1]`, 520 ms opening / 340 ms closing, content fades in after 140 ms.
- Tests: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml` (Qt 6 runner; `/usr/bin/qmltestrunner` is Qt 5).
- Latest-reload log check (expect nothing except the known notification-server warning): `qs log -p /home/tk421/Development/quickshell/shell.qml | awk '/Reloading configuration/{n=0; next} {n++; l[n]=$0} END{for(i=1;i<=n;i++) print l[i]}' | grep -E "WARN|ERROR"`.
- IPC: `qs ipc -p /home/tk421/Development/quickshell/shell.qml call <target> <function> [args]`. Screenshots with `grim -g` of exact rectangles only.

## Review Focus

1. A power action must never run during development: `dryRun` default, and a reload resets state to that default (safe).
2. Clicking the same toolbar button right after a grab-close must not reopen the panel; clicking a different one must switch.
3. Tray items that disappear (app quits) while their menu or overflow row is open.
4. Menu entries with empty text, separators only, hundreds of entries, hostile text (control/bidi characters).
5. An app that is `Passive` and later becomes `NeedsAttention` must move into view.

---

### Task 1: Pure logic (`dropdown/power.js`, `bar/trayLogic.js`) with tests

**Files:** create `dropdown/power.js`, `bar/trayLogic.js`, `tests/qml/tst_power.qml`, `tests/qml/tst_traylogic.qml`.

**Interfaces (produced):**
- `Power.ACTIONS` → array of `{ id, label, hint, glyph, confirm, hud, gap }` in order `lock, suspend, logout, reboot, poweroff`.
- `Power.commandFor(id, shellPath)` → `string[]` (argv) or `null` for unknown ids. `lock`: `["sh","-c","quickshell ipc -p <shellPath> call lock lock || pidof hyprlock || hyprlock"]`; `suspend`: `["systemctl","suspend"]`; `logout`: `["sh","-c","command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"]`; `reboot`: `["systemctl","reboot"]`; `poweroff`: `["systemctl","poweroff"]`. `shellPath` is shell-quoted with single quotes.
- `Power.isDestructive(id)` → `true` for `logout`, `reboot`, `poweroff`.
- `Tray.partition(items, max)` where `items` is `[{ id, passive, attention }]` → `{ visible, overflow, overflowAttention }`: `visible` = first `max` non-passive items, `overflow` = remaining non-passive then every passive item, order preserved; `overflowAttention` true if any overflow item has `attention`.
- `Tray.cleanLabel(text, max)` → control/bidi characters removed, newlines collapsed to spaces, trimmed, clipped with an ellipsis, never splitting a surrogate pair.
- `Tray.limitEntries(entries, max)` → `entries.slice(0, max)` with leading/trailing separators and consecutive separators removed (entries are `{ separator, text }`).

- [ ] **Step 1: write the tests.** `tests/qml/tst_power.qml` and `tests/qml/tst_traylogic.qml` (`TestCase` with `import "../../dropdown/power.js" as Power` / `import "../../bar/trayLogic.js" as Tray`), covering: action order and that only logout/reboot/poweroff are destructive; exact argv for all five ids; a shell path containing a space and a single quote is quoted safely (`'a b'\''c'`); unknown id → `null`; partition with 0, 3, 4, 5 active items and passive ones (order, `max`, `overflowAttention`); a passive item with attention is in overflow and sets `overflowAttention`; `cleanLabel` with bidi override, newlines, emoji at the cut, empty → `""`; `limitEntries` with leading/trailing/double separators and more than `max` entries.
- [ ] **Step 2: run** → fails (modules missing). Expected: `compile()` failures.
- [ ] **Step 3: implement** both files (`.pragma library`, ES5 style, `var`).
- [ ] **Step 4: run** → all pass. Ledger the line.

### Task 2: Services `Dropdown`, `Hud`, `Power`

**Files:** create `services/Dropdown.qml`, `services/Hud.qml`, `services/Power.qml`; append three `singleton` lines to `services/qmldir` (append only, never rewrite); patch `shell.qml` to add `import "dropdown"` is **Task 3** (nothing loads these yet except through IPC, so also add a `property bool dropdownActive: Dropdown.active` line to `shell.qml` by exact-match patch so the singletons and their IPC load).

**Interfaces (produced), exactly as in the spec:** `Dropdown { current, menuItem, menuAnchorX, active, open(name), toggle(name), close(), openMenu(item, anchorX), closeByGrab() }` + IPC `dropdown` (`open(name)`, `close()`, `status()`); `Hud { active, label, state, glyph, image, show(label, state, glyph, image) }`; `Power { dryRun (true), confirming, last, actions, ask(id), cancel(), confirm(), run(id) }` + IPC `power` (`status()`, `setDryRun(bool)`, `ask(id)`, `cancel()`, `confirm()`, `run(id)`).

- [ ] Write the three files (using `Power.commandFor`/`Power.ACTIONS`; `run` runs `Quickshell.execDetached` only when `dryRun` is false; HUD state is `dry run` under `dryRun`, else `…`; `run` and `confirm` close the dropdown; `Dropdown.close()` and `Dropdown.open()` of another panel call `Power.cancel()`).
- [ ] Lint, append qmldir, patch `shell.qml`, wait for the reload, run the log check.
- [ ] IPC checks: `power status` → `dryRun=true confirming= last=`; `power run suspend` → `last=suspend: systemctl suspend`; `power run lock` → shows the lock command, **and `isLocked` stays false** (`lock isLocked`); `power ask off` → `confirming=poweroff`; `power cancel`; `power ask lock` (non-destructive, ignored) → `confirming=`; `power confirm` with nothing pending → no-op; `dropdown open power` / `status` / `close`; unknown ids are ignored.

### Task 3: Host, power panel, power button, island HUD

**Files:** create `dropdown/DropdownHost.qml`, `dropdown/PowerPanel.qml`, `bar/PowerButton.qml`; patch `shell.qml` (import + `DropdownHost {}`), `bar/Toolbar.qml` (add `PowerButton {}` after the bell), `island/Island.qml` (HUD pill).

- [ ] Write the host (frame, grab, Esc, panel switching with `Loader`s, widths power 260 / tray 280 / menu 210) with only the power panel wired (tray panels arrive in Task 4), `PowerPanel`, `PowerButton`.
- [ ] Island patch (exact matches, asserted): a `readonly property bool pill: Hud.active && !open`, width 250 / height 44 / radius 22 when `pill` (priority above the volume HUD), the clock fades out, and a content row showing `Hud.glyph` or `Hud.image`, `Hud.label` (Orbitron 9, uppercase) and `Hud.state` on the right.
- [ ] Lint everything, apply patches, log check.
- [ ] Visual checks (`grim -g` of the host rectangle `2150,40 …` and the island `1130,4 250x44`): `dropdown open power`; `power ask off`; `power run suspend` → the HUD pill with "SUSPENDING dry run"; `dropdown close`. Compare with the prototype.
- [ ] Behaviour checks: `Esc`-cancel and outside-click are manual; test the 5 s auto-cancel by `power ask off`, sleeping 6 s, `power status` → `confirming=`.

### Task 4: Tray capsule, icons, overflow panel, app menu

**Files:** create `bar/Tray.qml`, `bar/TrayIcon.qml`, `dropdown/TrayPanel.qml`, `dropdown/TrayMenuPanel.qml`; patch `bar/Bar.qml` (tray capsule to the left of the toolbar), `dropdown/DropdownHost.qml` is written in Task 3 with the loaders already reserving `tray` and `menu` (create them as empty components first or add them here with one exact-match patch).

- [ ] Write the files per the spec (partition via `Tray.partition`, `cleanLabel` for every text, `QsMenuOpener` for menus with a stack for submenus, `limitEntries` 40).
- [ ] Lint, apply, log check.
- [ ] Verification needs a real tray app. Check which exist (`command -v nm-applet blueman-applet discord spotify steam telegram-desktop syncthing`); start one (for example `nm-applet`) and confirm: the icon appears, tooltip, left/middle/right click (right opens the menu in the host), submenu navigation, check marks, overflow when four or more apps run. Quit the app → the icon disappears and an open menu closes cleanly (log check clean).
- [ ] Screenshots of the capsule and each panel; compare with the prototype.

### Task 5: Docs, final review, `dryRun` hand-over

- [ ] Update `CLAUDE.md` (architecture bullet for `dropdown/`, `Power`/`Dropdown`/`Hud`, IPC list, "never run power actions while testing: `Power.dryRun`", the tray replaced the commented group) and `tk421/TK421.md` (§25, §39).
- [ ] Full test run + log check + IPC regression + visual regression of island (idle, `island toggle`, volume HUD via mute toggle twice).
- [ ] Self-review (no subagent tool allowed by the harness); ledger rulings and deferred minors.
- [ ] **Ask the user** before flipping `Power.dryRun` to `false`; when they agree, flip it with one exact-match edit, reload, and tell them to try Lock first.
