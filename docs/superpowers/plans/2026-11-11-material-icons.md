# Material Symbols Icons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the shell's mixed Nerd Font glyphs (Font Awesome + Material Design from "Symbols Nerd Font Mono") with one family, Material Symbols Sharp, and draw the tray apps in one grey.

**Architecture:** One pure table (`theme/icons.js`) maps an icon *name* (`"volume_up"`, plus a few virtual names such as `"mic_muted"`) to how it is drawn (glyph ligature, weight, fill, optical scale, slash). One component (`components/Icon.qml`) renders a name with that table through the variable font's ligatures. Logic files return names instead of private-use characters, so tests read as words. Tray icons get a per-app monochrome override (Simple Icons SVGs) and a greyscale fallback.

**Tech Stack:** Quickshell 0.3.2, Qt 6.12 QML (`font.variableAxes`, `MultiEffect`), `qmltestrunner`, Arch package `ttf-material-symbols-variable` (Apache-2.0), Simple Icons SVGs (CC0).

**Spec:** the decisions below were made with the user on 2026-11-11 after the prototype `prototypes/icons/index.html` (Material Sharp chosen over Phosphor Light) and a measured review of 91 Material variants (bounding box, coverage, stroke width, centring). The state table in "Icon table" is the spec; copy its values verbatim.

## Global Constraints

- Font: family `Material Symbols Sharp`, axes `wght 300`, `FILL 0`, `GRAD 0`, `opsz 24` (the reviewer measured at opsz 24: a weight-300 stroke is 60/960 units, exactly 1 px at 16 px).
- Every state of one icon uses the same base glyph, same height, width and weight. **FILL is never a state signal**; active/inactive is colour and the existing `surfaceAlt` hover chip.
- Sizes: every toolbar glyph 16 px (`Theme.iconSize.bar`); panel rows 16 px (`Theme.iconSize.panel`); large single glyphs 24 px (`Theme.iconSize.hero`). Media transport keeps its current 26/20 px.
- The running shell is the user's desktop and hot-reloads on every save: save each file once, working; after each save check `qs log -p /home/tk421/.config/quickshell/shell.qml` past the last `Reloading configuration` for `WARN|ERROR`. Shared files (`theme/Theme.qml`, `shell.qml`, `services/qmldir`, `bar/Toolbar.qml`, `CLAUDE.md`) are edited by other sessions: exact-match replacements that assert their match count, never whole rewrites.
- Dropdown panels are loaded by a `Loader`: saving only a panel does not reload; touch `dropdown/DropdownHost.qml` with a real edit and check the reload count.
- No git commits (CLAUDE.md: do not commit unless asked). Each task ends with a log check and the task's tests instead.
- Visual checks only with `grim -g` on the bar strip (`0,0 2560x40`) or a region fully inside an open panel; never the full screen, never the clipboard archive with real history. Never test power actions, real network/Bluetooth changes, or keyboard writes (use `Net.mock`, `Bt.mock`, `Sound.mock`).
- UI copy stays English; strings from apps stay `Text.PlainText`.

## Icon table (the spec)

| Name used in code | Glyph (ligature) | Weight | Fill | Scale | Slash |
|---|---|---|---|---|---|
| `volume_up`, `volume_off` | same | 300 | 0 | 1 | no |
| `mic` | `mic` | 300 | 0 | 1 | no |
| `mic_muted` (virtual) | `mic` | 300 | 0 | 1 | yes |
| `lan` (ethernet, and offline dimmed) | `lan` | 300 | 0 | 0.94 | no |
| `wifi`, `wifi_off` | same | **200** | 0 | 1 | no |
| `bluetooth` (every state) | `bluetooth` | 300 | 0 | 1 | no |
| `notifications`, `notifications_paused` (DND, COMMS HUD, drawer empty state) | same | 300 | 0 | 1 | no |
| `keyboard` (online and offline) | `keyboard` | 300 | 0 | 1 | no |
| `power_settings_new` | same | 300 | 0 | 0.94 | no |
| `play_arrow` | `play_arrow` | 300 | **1** | **1.07** | no |
| `pause`, `skip_previous`, `skip_next` | same | 300 | **1** | 1 | no |
| `lock`, `lock_open`, `bedtime`, `logout`, `restart_alt`, `arrow_forward`, `refresh`, `calendar_today`, `music_note`, `chevron_left`, `chevron_right`, `expand_more`, `check`, `close`, `headphones`, `videocam`, `tv`, `speaker`, `mouse`, `smartphone`, `sports_esports`, `content_paste`, `content_copy`, `delete`, `link`, `code`, `description`, `auto_awesome` | same | 300 | 0 | 1 | no |
| `radio_checked` (virtual, tray menu radio) | `circle` | 300 | 1 | 0.6 | no |

Mapping from today's states: volume high/mid/low → `volume_up`, muted or 0 → `volume_off` (the % text carries the level); mic on → `mic`, muted → `mic_muted`, missing → `mic` with the existing "?" badge; network eth → `lan`, no network and no Wi-Fi → `lan` dimmed, wifi → `wifi`, Wi-Fi present but disconnected → `wifi_off`; bell DND → `notifications_paused`; Bluetooth device kinds (netlogic `btGlyph`): headphones/headset → `headphones`, keyboard → `keyboard`, mouse → `mouse`, phone → `smartphone`, audio-card → `speaker`, gaming → `sports_esports`, else → `bluetooth`; sound device kinds (soundlogic `deviceGlyph`): HDMI → `tv`, headphone/headset → `headphones`, webcam → `videocam`, other output → `speaker`, other input → `mic`; power: lock → `lock`, suspend → `bedtime`, logout → `logout`, reboot → `restart_alt`, poweroff → `power_settings_new`.

The slash for `mic_muted`: a 1 px line in the icon's colour from the top-right to the bottom-left of the mic glyph's ink box (Material grid: x 280→680, y -880→-80 of the 0 -960 960 960 box, i.e. 29%→71% across, 8%→92% down), drawn with a 1 px gap in the background colour on its upper side so it reads over the stroke.

## Review Focus

- Font not installed or family name wrong: an `Icon` must never print the ligature word ("volume_up") into the bar. Expected: nothing drawn, one warning in the log.
- Unknown name (typo, a new state, an old private-use character passed by another session, e.g. `Hud.show(..., "")`): expected nothing drawn and one warning, never tofu or a word.
- A name returned by a logic file that the table does not know: expected to be caught by a test, not on the desktop.
- Ligature broken by text settings (letter spacing, capitalization, `StyledText`, elide): expected `Icon` to pin its own text settings so the ligature always forms.
- Tray app with no override, with a broken icon source, or asking for attention: expected greyscale fallback, no crash, attention dot still visible.

---

### Task 0: Install the font (user action)

- [ ] **Step 1:** Ask the user to run `! sudo pacman -S ttf-material-symbols-variable` (official `extra` repo; needs their password).
- [ ] **Step 2:** Verify: `fc-list | grep -i "Material Symbols Sharp"` prints at least one line. If the family string differs, use the printed one everywhere this plan says `Material Symbols Sharp`.

### Task 1: Icon table, Icon component, size tokens

**Files:**
- Create: `theme/icons.js`, `components/Icon.qml`, `tests/qml/tst_icons.qml`
- Modify: `theme/Theme.qml` (add `iconSize` and `symbolsFont`; keep `iconFont` until Task 6)

**Interfaces:**
- Produces: `icons.js` (`.pragma library`): `resolve(name: string) -> { glyph: string, weight: int, fill: int, scale: real, slash: bool } | null` (null for unknown names, including any string with a private-use character); `known(): string[]` (every name in the table).
- Produces: `Icon { name: string; size: real = Theme.iconSize.bar; color: color = Theme.imperial.text; readonly ok: bool }` — `ok` is false when the name is unknown or the font did not form the ligature; then nothing is drawn.
- Produces: `Theme.iconSize: { bar: 16, panel: 16, hero: 24 }`, `Theme.symbolsFont: "Material Symbols Sharp"`.

- [ ] **Step 1: Write the failing tests** in `tests/qml/tst_icons.qml` (`TestCase`, import `"../../theme/icons.js" as Icons` and the `Icon` component):
  - `test_resolveDefaults`: `resolve("volume_up")` → `{ glyph: "volume_up", weight: 300, fill: 0, scale: 1, slash: false }`.
  - `test_resolveExceptions`: `resolve("wifi").weight === 200`; `resolve("wifi_off").weight === 200`; `resolve("play_arrow")` has `fill 1, scale 1.07`; `resolve("pause").fill === 1`; `resolve("mic_muted")` → `glyph "mic", slash true`; `resolve("lan").scale === 0.94`; `resolve("power_settings_new").scale === 0.94`; `resolve("radio_checked")` → `glyph "circle", fill 1, scale 0.6`.
  - `test_resolveUnknown`: `resolve("nope") === null`; `resolve("") === null`; `resolve(undefined) === null`; `resolve("") === null`; `resolve("\u{f057e}") === null`.
  - `test_ligatureForms`: create `Icon { name: "volume_up"; size: 16 }`; `verify(icon.ok)`; the inner text's `contentWidth` ≤ `16 * 1.5` (a ligature is one glyph; the word would be ~5× wider).
  - `test_unknownDrawsNothing`: `Icon { name: "nope" }` → `ok === false`, `visible` content width 0.
  - `test_missingFontDrawsNothing`: an `Icon` whose font family is overridden to `"No Such Font 421"` → `ok === false`.
- [ ] **Step 2:** Run `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_icons.qml` → FAIL (files missing).
- [ ] **Step 3: Implement** `icons.js` from the Icon table (a default entry plus an exceptions object; `known()` lists every name in the table) and `Icon.qml`: an `Item` sized `size × size` holding a `Text` with `font.family: Theme.symbolsFont`, `font.pixelSize: size`, `font.variableAxes: { "wght": r.weight, "FILL": r.fill, "GRAD": 0, "opsz": 24 }`, `font.letterSpacing: 0`, `font.capitalization: Font.MixedCase`, `textFormat: Text.PlainText`, `renderType: Text.CurveRendering`, centred, `scale: r.scale`; `ok` = `r !== null && text.contentWidth <= size * 1.5`; the `Text` is `visible: ok`; when not ok and name non-empty, `console.warn("Icon: cannot draw", name)` once. The slash is a `Shape` child (1 px stroke, `color`, plus a 1 px background-colour line offset up-right) with the geometry from "The slash" above, `visible: ok && r.slash`. Add `iconSize` and `symbolsFont` to `Theme.qml` with an exact-match edit. Register nothing in a qmldir (components are imported by path like the others).
- [ ] **Step 4:** Run the test → PASS; check the shell log after the `Theme.qml` save (no new `WARN|ERROR`).

### Task 2: Logic files return names

**Files:**
- Modify: `dropdown/soundlogic.js` (`speakerGlyph`, `micGlyph`, `deviceGlyph`), `dropdown/netlogic.js` (`btGlyph` and the network mode glyphs), `dropdown/power.js` (`glyph` of each action)
- Modify: `tests/qml/tst_soundlogic.qml`, `tests/qml/tst_netlogic.qml`, `tests/qml/tst_power.qml`
- Modify (the consumers of those functions, switched in the same task so the desktop never shows a word): `bar/VolumeButton.qml`, `bar/MicButton.qml`, `island/Island.qml` (the HUD glyph `Text` only), and the glyph `Text` of the device / action rows in the sound, Bluetooth and power panels (`grep -ln "speakerGlyph\|micGlyph\|deviceGlyph\|btGlyph\|\.glyph" dropdown/*.qml`), plus one real edit to `dropdown/DropdownHost.qml` to reload the panels

**Interfaces:**
- Consumes: `icons.js` `resolve`, `known` (Task 1).
- Produces: the same function names and signatures, now returning names from the Icon table (see "Mapping from today's states"). `speakerGlyph(volume, muted)` returns only `volume_up` or `volume_off`.

- [ ] **Step 1: Update the tests first** to the new names, e.g. `compare(Sound.speakerGlyph(0.8, false), "volume_up")`, `speakerGlyph(0.2, false) === "volume_up"`, `speakerGlyph(0, false) === "volume_off"`, `speakerGlyph(0.8, true) === "volume_off"`, `micGlyph("muted") === "mic_muted"`, `micGlyph("missing") === "mic"`, `Net.btGlyph("input-mouse") === "mouse"`, `Net.btGlyph(undefined) === "bluetooth"`, `deviceGlyph("Navi 31 HDMI/DP Audio Digital Stereo (HDMI 4)", {}, true) === "tv"`, each power action's `glyph` as in the mapping. Add to each test file `test_allNamesKnown`: every value these functions can return (iterate the inputs already in the file plus every power action) satisfies `Icons.resolve(v) !== null`.
- [ ] **Step 2:** Run the three files with `qmltestrunner` → FAIL on the old glyphs.
- [ ] **Step 3: Switch the consumers first.** Replace each glyph `Text` fed by these functions (or by `Hud.glyph`) with `Icon { name: <same expression>; size: Theme.iconSize.bar | panel | hero; color: <same colour binding> }`. Until the logic files change, these Icons receive old characters and draw nothing (Review Focus behaviour), never a word. Log check after each save.
- [ ] **Step 4:** Change the return values in the three logic files (and the literal glyphs in `services/Notifications.qml` COMMS HUD → `notifications_paused` / `notifications`, `services/Power.qml` uses `power.js`).
- [ ] **Step 5:** Run the three test files plus `tst_icons.qml` → PASS; shell log since the last reload has no `Icon: cannot draw`; `grim -g "0,0 2560x40"` shows the volume and mic glyphs drawn.

### Task 3: Bar and island

**Files:**
- Modify: `bar/NetworkButton.qml`, `bar/BluetoothButton.qml`, `bar/NotificationBell.qml`, `bar/PowerButton.qml`, `bar/KeyboardButton.qml`, `bar/TrayCapsule.qml` (chevron), `island/Island.qml` (tab glyphs; the HUD was done in Task 2), `island/SegTab.qml` if it draws the glyph, `island/MediaPane.qml`, `island/CalendarPane.qml`, `island/AgendaPane.qml`

**Interfaces:**
- Consumes: `Icon` (Task 1), logic names (Task 2).

- [ ] **Step 1:** Replace each icon `Text { font.family: Theme.iconFont ... }` with `Icon { name: ...; size: Theme.iconSize.bar; color: <the Text's colour binding> }` keeping position, colour bindings and opacity behaviours. Network: `lan` / `wifi` / `wifi_off`, offline → `lan` with the existing dim colour. Bell: `Notifications.dnd ? "notifications_paused" : "notifications"`. Media transport: `Icon { name: Media.playing ? "pause" : "play_arrow" }` etc. at the current 26/20 px. Calendar arrows `chevron_left/right`, island tabs `calendar_today` / `music_note`, agenda `calendar_today`.
- [ ] **Step 2:** Log check after each save; `grim -g "0,0 2560x40"` the bar and confirm: one family, all toolbar glyphs the same visual size, no words, mic muted shows the slash (use `sound setMock` + `setMockMic muted`, then restore `setMockMic on` and `setMock false`), DND bell via `notifications toggleDnd` twice (back to the original state).
- [ ] **Step 3:** Island HUD check: `qs ipc ... call sound volume out <current>` (same value, triggers the HUD) and capture `906,4 748x424` only while the HUD shows.

### Task 4: Dropdowns, notifications, clipboard, lock, usage

**Files:**
- Modify: `dropdown/NetworkPanel.qml`, `dropdown/BluetoothPanel.qml`, `dropdown/SoundPanel.qml` (or whichever panel files draw glyphs — `grep -l "Theme.iconFont" dropdown/`), `dropdown/PowerPanel.qml`, `dropdown/TrayMenuPanel.qml` (check → `check`, radio → `radio_checked`, chevrons → `chevron_left/right`), `dropdown/KeyboardPanel.qml` (chevron `expand_more`), `notifications/NotificationCenter.qml` (empty state `notifications_paused`), `notifications/NotificationItem.qml` (`close`), `clipboard/ClipboardCard.qml` (kinds `link`/`code`/`description`, HUD `content_paste`/`content_copy`/`delete`), `lock/LockCard.qml` (`lock`/`lock_open`), `lock/LoginPane.qml` (`arrow_forward`/`refresh`), `lock/MediaPane.qml` (same transport as the island), `usage/UsageCard.qml` (`refresh`), `components/AppTile.qml` (fallback `notifications`)
- Modify: `dropdown/DropdownHost.qml` with one real edit (a comment line about the icon set) to trigger the reload.

- [ ] **Step 1:** Same replacement as Task 3 for every glyph not already switched in Task 2, `size: Theme.iconSize.panel` in rows, `Theme.iconSize.hero` for the single large glyphs (Bluetooth off view, lock padlock).
- [ ] **Step 2:** Reload check (count `Reloading configuration` lines before/after). Visual: `dropdown open sound` / `net` / `bt` / `power` with `Net.mock`/`Bt.mock`/`Sound.mock` on, `dropdown status` first, capture a region inside the panel, then close and turn the mocks off. Power panel: open only, never `confirm`/`run`. Lock: `lock preview` (password `preview`, Esc closes) — never `lock lock`. Clipboard: do not open it with real history; review the code path only.

### Task 5: Tray apps in one grey

**Files:**
- Create: `assets/tray/spotify.svg`, `telegram.svg`, `discord.svg`, `steam.svg`, `firefox.svg`, `github.svg` (Simple Icons 13.21.0, CC0, from `https://cdn.jsdelivr.net/npm/simple-icons@13.21.0/icons/<name>.svg`; keep only the `path` and `viewBox`, fill `#E8E6E3`)
- Modify: `bar/trayLogic.js` (add `overrideFor`), `bar/TrayIcon.qml`, `tests/qml/tst_traylogic.qml`

**Interfaces:**
- Produces: `overrideFor(id: string) -> string` — file name under `assets/tray/` or `""`. Keys are SNI ids measured on this machine: `"spotify-client" → "spotify.svg"`, `"TelegramDesktop" → "telegram.svg"`; also `"discord" → "discord.svg"`, `"steam" → "steam.svg"`, `"firefox" → "firefox.svg"`, `"github-desktop" → "github.svg"` (unverified ids: confirm with `tray list` when such an app runs).

- [ ] **Step 1: Tests** in `tst_traylogic.qml`: `overrideFor("spotify-client") === "spotify.svg"`, `overrideFor("TelegramDesktop") === "telegram.svg"`, `overrideFor("unknown-app") === ""`, `overrideFor("") === ""`, `overrideFor(undefined) === ""`.
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement `overrideFor`. **Step 4:** Run → PASS.
- [ ] **Step 5:** In `TrayIcon.qml` the `Image` source becomes the override (`Quickshell.shellPath("assets/tray/" + file)`) when there is one, else `item.icon`; for the fallback set `layer.enabled: true` with `layer.effect: MultiEffect { saturation: -1 }`. Size stays 16 px; the attention dot, menu and hover chip untouched.
- [ ] **Step 6:** Visual: `grim -g "0,0 2560x40"`: Spotify and Telegram in the same grey as the toolbar glyphs.

### Task 6: Remove the old font and document

**Files:**
- Modify: `theme/Theme.qml` (remove `iconFont` once nothing uses it), `CLAUDE.md`, `prototypes/icons/index.html` (no change; referenced)

- [ ] **Step 1:** Verify nothing is left: `grep -rn "Theme.iconFont" --include=*.qml . | grep -v prototypes/` prints nothing except `flyouts/VolumeFlyout.qml` (superseded, not instantiated — leave it), and the private-use scan prints no file outside `prototypes/`, `graft/`, `flyouts/`:
  `python3 -c "import re,glob;p=re.compile(r'[-\U000f0000-\U000fffff]');print([f for f in glob.glob('**/*.qml',recursive=True)+glob.glob('**/*.js',recursive=True) if not f.startswith(('prototypes','graft','flyouts')) and p.search(open(f,encoding='utf-8').read())])"` → `[]`.
- [ ] **Step 2:** Remove `iconFont` from `Theme.qml` (exact-match edit) only if `VolumeFlyout.qml` is the sole user left and it is not instantiated; log check.
- [ ] **Step 3:** All tests: run every `tests/qml/tst_*.qml` with `qmltestrunner` → PASS. Shell log since the last reload: no `Icon: cannot draw`.
- [ ] **Step 4:** `CLAUDE.md`: in Architecture, one bullet: icons are Material Symbols Sharp (package `ttf-material-symbols-variable`), drawn only through `components/Icon.qml` + `theme/icons.js` (names, not glyphs; weight 300, FILL 0, opsz 24; exceptions in the table), states keep one glyph (no FILL as state), sizes `Theme.iconSize`, tray overrides in `assets/tray/` keyed by SNI id via `bar/trayLogic.js overrideFor`. Exact-match insert before the `- \`bar/Clock.qml\`` line.
