# Power menu and system tray — Design

## Goal

Two more parts of the bar, as approved in `prototypes/toolbar/index.html`:

- **Power:** a button at the end of the toolbar capsule that opens a dropdown with Lock, Suspend, Log out, Restart and Power off. The destructive ones ask for confirmation in place.
- **Tray:** a capsule to the left of the toolbar with the icons of apps that keep one (Discord, Claude Desktop, Spotify…), real StatusNotifierItems. Left-click activates, right-click opens the app's own menu, extra icons go behind a chevron.

Both open dropdowns in **one shared slot** under the capsules, so opening one closes the other. The notification centre, Bluetooth and network will use the same slot later.

Success: every action runs the right command (verified without running it, see Safety); the confirmation cancels itself; tray icons appear and disappear as apps start and quit; an app's menu is usable (submenus, check marks, disabled and separator entries); nothing an app sends can break or spoof the shell.

## Decisions

| Decision | Value | Why |
|---|---|---|
| Dropdown | One `PanelWindow` host, panels switch inside it | Matches the prototype: one slot, one grab, one Esc handler |
| Close | Click outside (`HyprlandFocusGrab`), `Esc`, clicking the same button again | Same as the notification centre spec |
| Reopen race | A button click that follows the grab-close of **the same panel** within 400 ms is ignored. Clicking a *different* button switches panels | Closing then reopening the same panel is a bug; switching is a feature |
| Actions | Lock → the existing `lock lock` IPC (falls back to `hyprlock`). Suspend → `systemctl suspend`. Log out → the user's own command (`hyprshutdown` if installed, else `hyprctl dispatch 'hl.dsp.exit()'`). Restart → `systemctl reboot`. Power off → `systemctl poweroff` | Reuses what already works on this machine; logind answers `yes` to all three |
| No Hibernate | Not offered | TK-421 policy: 0 swap (TK421.md §5) |
| Confirmation | Log out, Restart, Power off ask in the row. Auto-cancels after 5 s. `Esc` cancels | Approved in the prototype |
| Feedback | A brief pill in the island ("POWERING OFF …", the tray app's name + "Opening") for 2 s | Approved in the prototype |
| Tray visible limit | 3 icons, the rest and every `Passive` item behind the chevron | Approved |
| Tray menus | Our own styled menu fed by the app's D-Bus menu (`QsMenuOpener`), not the native toolkit menu | Matches the look; the native menu would be a different window system |
| Tray icons | The app's own icon as given (coloured), no tile | Approved |
| Safety default | `Power.dryRun` is **true** until the user switches it off, in code, at the end | The shell hot-reloads while other sessions edit this repo: a test must never be able to suspend the machine |

## Architecture

```
services/Dropdown.qml   current panel, anchor for menus, open/toggle/close, reopen guard, IPC "dropdown"
services/Hud.qml        brief island pill (label + state + glyph or image), IPC-free
services/Power.qml      actions, confirmation state, dryRun, command execution, IPC "power"
dropdown/DropdownHost.qml      the window: grab, Esc, frame animation, panel switching
dropdown/PowerPanel.qml        rows + inline confirmation
dropdown/TrayPanel.qml         overflow list (hidden + passive items)
dropdown/TrayMenuPanel.qml     an app's menu, with submenus
bar/PowerButton.qml            glyph in the toolbar
bar/Tray.qml, bar/TrayIcon.qml the tray capsule
bar/trayLogic.js  power.js     pure rules, unit-tested
island/Island.qml              + the HUD pill state
```

- **State lives in singletons** so the UI is declarative and testable over IPC (`power ask off`, `dropdown open tray`) without a pointer.
- **Pure rules in `.js`** with Qt Quick Test: command mapping, tray partitioning, label clipping, menu entry cleaning.

### Files

- Create: `services/Dropdown.qml`, `services/Hud.qml`, `services/Power.qml` (+ `services/qmldir` lines).
- Create: `dropdown/DropdownHost.qml`, `dropdown/PowerPanel.qml`, `dropdown/TrayPanel.qml`, `dropdown/TrayMenuPanel.qml`.
- Create: `bar/PowerButton.qml`, `bar/Tray.qml`, `bar/TrayIcon.qml`, `bar/trayLogic.js`, `dropdown/power.js`.
- Create: `tests/qml/tst_power.qml`, `tests/qml/tst_traylogic.qml`.
- Modify (targeted edits only, **other sessions edit these files too**): `shell.qml` (instantiate the host), `bar/Toolbar.qml` (power button), `bar/Bar.qml` (tray capsule), `island/Island.qml` (HUD pill).
- Update `CLAUDE.md` and `tk421/TK421.md` (§25 Quickshell, §39 pending).

## Services

### `Dropdown`

- `current: string` — `""`, `"power"`, `"tray"`, `"menu"` (later `"notif"`, `"net"`, `"bt"`).
- `menuItem` (the `SystemTrayItem` whose menu is shown) and `menuAnchorX` (screen x, in pixels, of the icon it belongs to).
- `open(name)`, `toggle(name)`, `close()`, `openMenu(item, anchorX)`, `closeByGrab()`.
- Closing by grab records `(name, time)`; `toggle(name)` and `open(name)` ignore a call for that same name within 400 ms.
- Closing power cancels any pending confirmation.
- IPC target `dropdown`: `open(name)`, `close()`, `status()` → `"current=<name>"`.

### `Hud`

- `show(label, state, glyph, image)`: sets the fields and `active = true` for 2000 ms (a new call restarts it). `glyph` is a Nerd Font character, `image` an `image://` or file URL; the island shows whichever is non-empty.

### `Power`

- `dryRun: bool` (default **true**), `confirming: string` (`""` or an action id), `last: string` (what was run or would have been, for tests).
- `actions`: `[{ id, label, hint, glyph, confirm, hud }]` in the order Lock, Suspend, Log out, Restart, Power off.
- `ask(id)` sets `confirming` for destructive actions and starts the 5 s timer; `cancel()`; `confirm()` runs `confirming`; `run(id)` runs an action directly.
- `run(id)`: builds the command with `power.js`; if `dryRun` it only records `last`, otherwise `Quickshell.execDetached(command)`. Either way it shows the HUD (state text `…`, or `dry run` when not executing) and closes the dropdown.
- IPC target `power`: `status()` → `"dryRun=<bool> confirming=<id> last=<text>"`, `setDryRun(bool)`, `ask(id)`, `cancel()`, `confirm()`, `run(id)`.

## UI

### Host (`DropdownHost`)

- `PanelWindow`, layer Top, namespace `tk421-dropdown`, anchored top-right, `margins.top: 40`, `margins.right: 30`, width **640**, height **520**, click-through except the panel (`mask`). `HyprlandFocusGrab` active while open, `cleared` → `Dropdown.closeByGrab()`. `Escape` first cancels a pending power confirmation, otherwise closes. `keyboardFocus: OnDemand`.
- Frame: `Rectangle`, `surface` fill, 1 px `border`, radius 20, grows from the capsule exactly like the notification centre (width from 240 to the panel's own width, height from 0 to content, 520/340 ms, same curve, content fades in after 140 ms with a 0.97 → 1 scale, no blur). Widths: power 260, tray 280, tray menu 210.
- Slot panels are right-aligned to the window edge (= the toolbar's right edge). The tray menu is placed under its icon: `x = clamp(menuAnchorX − hostLeft − 24, 12, 640 − 210 − 12)`.
- Switching panels while open keeps the frame and cross-fades the content (new content rises in over 300 ms); the frame animates to the new width and height.
- The panel in the frame stays mounted until the close animation ends.

### Power panel

- Header: "POWER" (Orbitron 11, regular, tracking 0.2 em) and the user name in muted Geist 11.
- Rows 40 px: glyph (muted, 18 px), label Geist 13/500, optional shortcut hint (Orbitron 9, muted; "Super L" for Lock). Hover: 3.5 % white wash. An 8 px gap before "Log out".
- A destructive row asks: the label becomes "<Action>?" in `dangerText`, a small × (cancel) and a "CONFIRM" button outlined in `danger`, and a 1 px `danger` hairline drains over 5 s. Only one row asks at a time.
- Lock and Suspend run immediately.

### Tray capsule

- Left of the toolbar capsule, gap 8, same geometry (28 px, top 4). Hidden when there are no items. Icons are 16 px images of `item.icon` in 24×22 hit areas, 2 px apart; hover wash `surfaceAlt`. A 6 px accent dot (with a `surface` ring) at the top-right marks `NeedsAttention`.
- Items appear with a short scale/fade pop (300 ms).
- Chevron: shown when more than 3 active items exist or any item is `Passive`; carries the attention dot if any hidden item needs attention.
- **Tooltip** after 500 ms of hover: `item.tooltipTitle`, else `item.title`, in a small `PopupWindow`.
- **Left-click** → `item.activate()` (if `item.onlyMenu`, open the menu instead) and a HUD pill with the app's icon and "Opening". **Middle-click** → `secondaryActivate()`. **Right-click** → the menu (if `item.hasMenu`). **Scroll** → `item.scroll(delta, horizontal)`.

### Tray overflow panel

Header "TRAY" and "N hidden". Rows: icon, name, status ("Needs attention" with a dot, "Running", "Passive"), "OPEN" on hover. Click activates; right-click opens that item's menu in the host.

### Tray menu panel

- Header: the app's title in Orbitron 9, muted. Rows 32 px: a 14 px check column (check mark for `CheckBox` and `RadioButton` entries that are checked), the text (Geist 13), a chevron for submenus, 8 px gap for separators. Disabled entries are dimmed and inert. A "Quit"-like entry is not special-cased (the app decides).
- Submenus open in the same panel with a "‹ Back" row at the top.
- Activating an entry calls `entry.triggered()`. Check/radio entries keep the menu open; everything else closes it.

## Security and robustness

- All app text (titles, tooltips, menu labels) renders with `textFormat: Text.PlainText`; labels are cleaned of control and bidi-override characters and limited (title 40, menu text 60) with the same `clip` rules as notifications.
- Icons come only from `item.icon`, which Quickshell resolves through its own `image://` provider; no remote URL is ever loaded.
- A menu with hundreds of entries is limited to 40 rows and scrolls; a menu entry that disappears while open is dropped without error.
- If no StatusNotifier host can be registered because another one exists, Quickshell logs a warning; the tray capsule is then empty and hidden.
- Power actions are never run from tests (see `dryRun`). Lock is tested only through `dryRun`; the real `lock lock` is never called.

## Rollout

1. Build everything with `dryRun = true`. Verify with IPC and `grim` of the exact panel rectangles.
2. Verify the tray with whatever apps run; `Hud`/menus are also verifiable with a throw-away StatusNotifier item (a small script using `dbus-next`/`gdbus` is **not** required: if no app with a tray is running, the user starts Discord/Claude Desktop/Spotify).
3. Final step, **only with the user's go-ahead**: flip `dryRun` to `false`. The user is then told to try Lock first, never Power off first.

## Non-goals

- Bluetooth and network panels, the notification centre inside the host (their own specs and plans; the notification plan must be updated to use `Dropdown`).
- Hibernate, hybrid sleep, switching users, per-app tray ordering or hiding rules.
- Keyboard navigation inside dropdowns beyond `Esc` and `Tab` focus.
- Keyboard shortcuts for power actions (an IPC exists; binding keys is the user's choice).

## Acceptance criteria

1. The power button opens the panel; `Esc`, an outside click and the button close it; another toolbar button switches panels.
2. `power run <id>` under `dryRun` records the exact command in `status()`; the mapping equals the table above.
3. Log out / Restart / Power off ask first; the question cancels itself after 5 s and with `Esc`; confirming runs the action (dry) and shows the HUD.
4. With tray apps running, their icons appear, attention dots show, left/right/middle clicks and scroll work, the menu is usable including a submenu, and quitting the app removes the icon.
5. More than 3 active items or any passive item shows the chevron with a working overflow panel.
6. No `WARN`/`ERROR` in the latest reload other than the known notification-server registration warning while `swaync` is still running.
7. Unit tests pass; `CLAUDE.md` and `TK421.md` are updated.
