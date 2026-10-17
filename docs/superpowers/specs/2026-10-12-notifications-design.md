# Notifications — Design

## Goal

Replace `swaync` with a notification server that lives inside the Quickshell shell, styled Imperial and matching the approved prototype `prototypes/notifications/index.html`.

- **Popups** appear as a new Dynamic Island state (the pill grows into a toast card).
- **History and Do Not Disturb** live in a dropdown opened from a bell in a new right-hand toolbar capsule.

Success: `notify-send` from any app shows an island toast; the bell counts unread items; the dropdown lists, dismisses, clears and mutes; `swaync` is no longer started; nothing is lost across Quickshell hot reloads; and a bad notification (markup, a huge body, a flood) can never break or spoof the shell.

This is the first part of the toolbar. Network, Bluetooth and Power get their own specs and prototypes. The toolbar capsule built here must take those items later without rework.

## Decisions

| Decision | Value | Why |
|---|---|---|
| Daemon | `NotificationServer` from `Quickshell.Services.Notifications` (0.3.2), replacing `swaync` | User choice. One process, one theme, no second D-Bus owner |
| Popup surface | New island state, priority **open > notify > hud > media > idle** | Approved in the prototype |
| History surface | Dropdown `PanelWindow` under the bell, opened by click | Approved. Hover is reserved for the island |
| Popup timing | 5 s, paused while hovered. **Critical** never auto-dismisses | Approved |
| Do Not Disturb | Silences popups, **critical still pops**. Bell still pings and counts. Switched by the moon button in the dropdown header (and by IPC `toggleDnd`) | Approved |
| `low` urgency | History only: no popup, no ping | Freedesktop meaning of "low". *Assumption, not in the prototype* |
| `transient` hint | Popup only: not listed in the dropdown, not counted | Spec meaning of the hint. *Assumption* |
| App-supplied timeout | Ignored. We use our own 5 s / sticky policy | One consistent feel |
| History | In memory, newest first, capped at 50 (oldest is dismissed on overflow) | YAGNI. See non-goals |
| Body format | Plain text only: `bodyMarkupSupported`, `bodyHyperlinksSupported`, `bodyImagesSupported` all `false` | Invites and chat apps send strangers' text. CLAUDE.md rule |
| Actions | Supported, rendered as quiet text buttons; the first one has a thin accent outline | Approved |
| Inline reply, notification images, sounds | Not supported (`inlineReplySupported: false`, `imageSupported: false`) | YAGNI |
| Hot reload | `keepOnReload: true`; history is rebuilt from `trackedNotifications` | The shell reloads on every file save |

## Architecture

```
D-Bus org.freedesktop.Notifications
        │
 services/Notifications.qml  (singleton: server, history, unread, DND, toast, IPC handler)
        │
        ├── island/Island.qml ── island/NotificationToast.qml   popup state
        ├── bar/Toolbar.qml ──── bar/NotificationBell.qml        count + ping
        └── notifications/NotificationCenter.qml                 dropdown window
                                 └── notifications/NotificationItem.qml
 shared: components/AppTile.qml (app icon used by toast and item), components/ActionButton.qml
 IPC:    notifications target in services/Notifications.qml (see below)
```

- **The singleton is the only owner of state.** The UI reads properties and calls functions. It never touches a `Notification` object directly.
- **History entries are our own objects.** A `Notification` from D-Bus can be replaced or withdrawn by the app at any moment, so each entry copies the display fields and keeps the live reference separately.

### Files

- Create `services/Notifications.qml`, register it in `services/qmldir` (`singleton Notifications Notifications.qml`).
- Create `notifications/NotificationEntry.qml`, `notifications/NotificationCenter.qml`, `notifications/NotificationItem.qml`.
- Create `island/NotificationToast.qml`.
- Create `bar/Toolbar.qml` and `bar/NotificationBell.qml`.
- Create `components/AppTile.qml`.
- Modify `island/Island.qml` (new state, hover rule), `bar/Bar.qml` (replace the commented tray group with `Toolbar`), `shell.qml` (instantiate `NotificationCenter`).
- Modify `hypr/hyprland.lua` (remove `swaync` autostart on line 50; rebind `SUPER+N`). This file is the user's live config through the `hypr/` symlink, so it is done last and only after the shell side is verified (see Rollout).
- Update docs the project says must follow decisions: `CLAUDE.md` (architecture and the "tray group is commented out" note), `tk421/TK421.md` (§16 Notificações, §38 autostart, §39 pending, §42 superseded decisions).

## Service: `services/Notifications.qml`

### Server

```qml
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
```

`accept(n)` sets `n.tracked = true` (without it the notification is dropped), then:

1. If `n.lastGeneration` is true (carried over a hot reload): rebuild its entry silently. No popup, no ping.
2. If an entry for the same `n.id` already exists (the app replaced its own notification): update the entry in place, mark unread, treat as a new arrival for popup purposes.
3. Otherwise create an entry and treat it as a new arrival.

New arrival rules, decided **at arrival time** (a suppressed popup is never shown later):

| Condition | Popup | Ping | History / unread |
|---|---|---|---|
| Center open | no | no | yes, entry slides in at the top |
| Island open (hover or pinned) | no | yes | yes |
| `urgency == Low` | no | no | yes |
| DND on, urgency not Critical | no | yes | yes |
| `transient` | yes | yes | **no** (dismissed when the popup ends) |
| everything else | yes | yes | yes |

### Entry (`NotificationEntry`)

| Field | Source |
|---|---|
| `uid` | monotonic integer, stable key for the list model |
| `appName`, `appIcon`, `desktopEntry`, `summary`, `body` | copied from `Notification`, refreshed on the `*Changed` signals |
| `critical` | `urgency == NotificationUrgency.Critical` |
| `actions` | array of `{ identifier, text }` copied from `n.actions` |
| `timestamp` | arrival time (`new Date()`) |
| `unread` | true on arrival |
| `live` | the `Notification` while the app still owns it; `null` after `closed` |

When the app closes a notification (`closed` with `CloseRequested`) it is **withdrawn**: the entry is removed from history and from the popup. When `live` is null the action buttons are hidden.

### Public API

```
readonly property var  history         // entries, newest first (feeds a ScriptModel keyed on uid)
readonly property int  unreadCount
property bool          dnd             // not persisted
property bool          centerOpen      // owned here so the island and bell can read it
readonly property var  toast           // entry currently shown as a popup, or null
property bool          mock            // like Media.mock, see Testing

function dismiss(entry)                // user removed it: dismiss() on the live Notification, drop the entry
function clear()                       // dismiss all
function invoke(entry, index)          // action.invoke(); then dismiss unless n.resident
function markRead(entry)
function markAllRead()                 // called when the center closes
function hideToast(markRead)           // popup × / click: hide popup, entry stays in history
function toggleCenter(), toggleDnd()
```

### Toast policy (owned by the service, rendered by the island)

- One toast at a time. A new arrival **replaces** the current toast; the replaced entry stays in history, unread.
- Duration 5000 ms for non-critical. The countdown is a single `NumberAnimation` (progress 1 → 0, `paused` while the toast is hovered, `onFinished` hides). That animation also drives the 1 px accent hairline, so the visual and the timeout cannot drift apart.
- Critical: no countdown, no line, danger-coloured border, stays until dismissed.
- Hiding by timeout leaves the entry unread. Hiding by click or × marks it read. Pressing an action removes the entry.
- Opening the center hides any toast and marks it read.

### IPC (`IpcHandler`, target `notifications`)

| Function | Effect |
|---|---|
| `toggleCenter()` | open/close the dropdown (used by `SUPER+N`) |
| `toggleDnd()` | flip DND |
| `clear()` | clear history |
| `status()` | `"<unread>/<total> dnd=<bool> toast=<bool>"` for scripts and tests |
| `inject(kind)` | mock arrival without D-Bus. `kind` ∈ `normal`, `actions`, `critical`, `low`, `long`. Works only when `mock` is true |

`inject` replaces the prototype's keyboard shortcuts. Real traffic is tested with `notify-send` (see Testing).

## UI

### Island toast (`island/Island.qml`, `island/NotificationToast.qml`)

- **Design:** the light pass of the prototype (`prototypes/notifications/index.html`): less chrome, same fonts. Compact state shows only the icon, the title and one line of body. The app name and the time appear on hover.
- **Card geometry:** idle 108×28 → toast **360×58**, radius **20**; hovered, the height follows the toast's content (header row, up to three body lines, action row): 96 for one action. Same `Ease` curve, 520 ms growing and 340 ms shrinking, as the other states.
- **Layout:** 28 px app icon with **no box around it** at x 18; text column at x 58 (254 px wide): title Geist 13/500 one line, body Geist 12 muted one line (up to three lines with an ellipsis when hovered). On hover a header row fades in above the title (app name in Orbitron 9 px, regular weight, uppercase, tracking 0.18 em, muted; time or "Critical" on the right), the action row appears below the body, and a 24 px × button appears at the right. A 1 px accent hairline drains along the bottom edge.
- **Clock** fades out while a toast shows (as it does for the HUD).
- **Swap animation** when a new toast replaces the current one: old content rises out and fades in 200 ms, new content rises in over 460 ms. Opacity and slide only, no blur (the existing island has none).
- **Content is laid out at its final width (360 px) and clipped by the growing card.** If it were laid out at the animated width the text would wrap and the measured height would be wrong. The prototype hit exactly this bug; in QML it is avoided by giving the content a fixed width, not by re-measuring.
- **Critical:** danger border on the card, title and header label in `dangerText`, and the first action outlined in `danger`. No filled elements.

### Toolbar capsule and bell (`bar/Toolbar.qml`, `bar/NotificationBell.qml`)

- `Toolbar` is a capsule anchored at `right: 30`, `top: 4`, height 28, radius 14, `surface` fill, `border` outline: the mirror of the CPU/RAM/GPU capsule. It is a `Row` that clips nothing, so later items (network, Bluetooth, power) are added by dropping a component into the row.
- **Only the bell ships now.** The prototype's inert Wi-Fi, Bluetooth and Power icons were placeholders for layout; shipping dead icons would mislead, so they arrive with their own specs.
- Bell: Nerd Font glyph `󰂚` (`󰂛` while DND), 14 px, `#B5BAC3`, text colour on hover or while the center is open. Count to its right in Orbitron 10 px (`9+` above nine), hidden at zero and while the center is open, muted while DND.
- Count change: the new digit rises in over 280 ms. Arrival: one accent ring expands and fades over 900 ms (`ping`).
- Click toggles the center. The bell shows the Do Not Disturb state (slashed glyph, muted count).

### Dropdown (`notifications/NotificationCenter.qml`)

- A `PanelWindow` (layer Top, namespace `tk421-notifications`) anchored top-right, `margins.top: 40`, `margins.right: 30`, sized for the largest panel (340×500). `mask: Region { item: panel }`, so everything outside the panel is click-through.
- **Opening motion:** the panel grows from the capsule: width 240 → 340, radius 14 → 20, height 0 → content height, with the same curve and 520/340 ms. Content fades in with a 0.97 → 1 scale after 140 ms, no blur. The animated width must not reflow the content: content has a fixed 338 px width, right-aligned, and is clipped.
- **Close:** click outside (`HyprlandFocusGrab` on the window, `cleared` closes it), `Esc` (window takes `keyboardFocus: OnDemand`), bell click, `SUPER+N`. Clicking the bell while open must close it once, not close-then-reopen: the grab's `cleared` fires before the bell's click, so the toggle ignores a click that arrives within the same event as a grab clear (exact guard is a plan detail).
- **Header (48 px, no divider line):** "NOTIFICATIONS" in Orbitron 11 px, regular weight, tracking 0.2 em; "N new" in muted Geist 11; a 28 px borderless moon button (DND, `accentDim` fill when on); a borderless "CLEAR" text button (dimmed when empty).
- **DND strip** (30 px, no lines) below the header while DND is on: "Do not disturb · popups muted, critical alerts still show".
- **List:** `ListView` over `ScriptModel { values: Notifications.history; objectProp: "uid" }`, max height 392 px, thin scrollbar, `section` delegate for day labels ("Today", "Yesterday", then `ddd d MMM`) in Orbitron 9 px muted. Rows have no divider lines.
- **Item (`NotificationItem`):** 24 px icon with no box, header (app name in Orbitron 9 px with a 5 px accent dot while unread; relative time right), title Geist 13/500, body (two lines), actions row. × appears on hover. Hover fill is a 3.5% white wash. Clicking the body marks it read. × or an action removes it.
- **Motion:** `add` slides in from above (460 ms), `remove` fades out and `displaced` slides the rest up (300 ms). "Clear" removes items in a cascade (40 ms stagger, first eight).
- **Empty state:** a bell-off glyph, "No notifications", "You're all caught up."
- **Unread dots** clear when the center closes (after the close animation, so they do not visibly blink out).
- **Relative time:** `now` under 45 s, `Xm`, `Xh` within today, then `HH:mm`. Re-evaluated every 30 s while the center is open.

### Icons (`components/AppTile.qml`)

Resolution order for the 28 px (toast) / 24 px (item) icon:

1. `Quickshell.iconPath(appIcon, true)` if `appIcon` is an icon name.
2. The `desktopEntry` icon if `appIcon` is empty.
3. A generic bell glyph.

**Deviation from the prototype:** the prototype drew a monochrome stroke glyph per mock app. Real apps ship their own icons, so the app's real icon is shown as it is, with no tile or border around it (the light pass of the prototype). If coloured icons clash with the palette, a desaturating effect can be added later without changing the structure.

`appIcon` is app-controlled. Only icon names and absolute file paths are used; anything with a URL scheme (`http://`, `https://`, …) is discarded so a notification cannot make the shell fetch a remote image.

## Security and robustness

- All external strings (`summary`, `body`, `appName`, action text) render with `textFormat: Text.PlainText`. Combined with the three `...Supported: false` flags, apps are told not to send markup, and anything that arrives anyway is shown literally.
- Every text is length-limited at the display boundary: summary 120 chars, body 600 chars, action text 24 chars, at most 3 actions. The limit is applied when copying into the entry, so a 1 MB body cannot reach the scene graph.
- A flood is bounded by design: toasts replace each other, history is capped at 50 and the oldest live notification is `dismiss()`ed on overflow.
- While the session is locked the lock surface covers the island and dropdown, nothing is drawn, and arrivals simply accumulate as unread. Nothing about a notification is ever shown on the lock screen.
- If another daemon already owns `org.freedesktop.Notifications`, registration fails and Quickshell logs a warning. The UI still works against injected mock data; no crash. This is the expected state until the cutover.

## Hyprland changes (last step)

`hypr/hyprland.lua` is the live config. Exact edits:

1. Remove `hl.exec_cmd("swaync")` (line 50).
2. Replace `hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("swaync-client -t -sw"))` (line 349) with the same bind running
   `quickshell ipc -p /home/tk421/Development/quickshell/shell.qml call notifications toggleCenter`.

`SUPER+N` stays the key for the center, matching the current muscle memory. The `swaync` package stays installed so rollback is a two-line revert.

## Rollout

Development and cutover are separate, so the real desktop never loses notifications by accident.

1. **Build with `swaync` still running.** The shell cannot take the D-Bus name, so the UI is developed and screenshot-tested with `mock = true` and `notifications inject <kind>`.
2. **Cutover (needs the user's go-ahead, it changes what shows their notifications):**
   `pkill swaync`, hot-reload or restart Quickshell with `mock = false`, then verify `busctl --user list | grep Notifications` shows Quickshell as the owner and run the real tests below.
3. **Persist the cutover:** apply the two `hyprland.lua` edits, reload Hyprland config.
4. **Rollback:** restore the two `hyprland.lua` lines, then hand the D-Bus name back: remove the `NotificationServer` from the loaded shell (revert `services/Notifications.qml` or restart Quickshell without it) and run `swaync`. Two daemons cannot own the name at once, so `swaync` only starts cleanly once the shell has released it.

## Testing

There is no QML test harness in this repo (pytest covers only `agenda/`), so verification is by running the real shell.

- **Visual (mock):** `qs ipc … call notifications inject normal|actions|critical|low|long`, then `grim -g "<region>" <file>` of only the island card or only the dropdown. Never the full screen. Compare with the prototype states `#toast`, `#actions`, `#critical`, `#center`, `#center-dnd`, `#empty`.
- **Real traffic (after cutover):**
  - `notify-send "Build finished" "quickshell · release build"` — normal toast, 5 s, bell count rises.
  - `notify-send -u critical "Disk space low" "..."` — sticky, danger border.
  - `notify-send -u low "..."` — history only, no popup.
  - `notify-send -A join=Join -A snooze=Snooze "Daily" "..."` — actions render; pressing one prints its id and removes the entry.
  - `notify-send -r <id> ...` / `-h string:x-canonical-private-synchronous:x` — replacement updates in place.
  - `notify-send -e` (transient) — popup, never listed.
  - `notify-send '<b>bold</b> & <a href="http://x">link</a>' ...` — shown literally.
  - 80 notifications in a loop — history stays at 50, UI stays responsive, toast keeps swapping.
  - The existing screenshot scripts (`screenshot-region`, `screenshot-full`) — their `notify-send` ends up in the island.
- **Behaviour:** DND silences normal but not critical; opening the island suppresses the toast; hovering a toast does not open the calendar; hover → toast ends → calendar does not open until re-entry; bell click while open closes once; `Esc` and click-outside close; `SUPER+N` toggles.
- **Reload:** save a QML file with 3 items in history. They survive (via `keepOnReload`) and nothing pops up again.
- **Logs:** after the last reload, text after the last `Reloading configuration` line has zero `WARN|ERROR`.
- **Never call `lock lock`.** Lock behaviour is checked only by reading the code path and the `lock preview` IPC.

## Acceptance criteria

1. `swaync` is not running and not autostarted; Quickshell owns `org.freedesktop.Notifications`.
2. Each `notify-send` variant above behaves as listed.
3. Popup, dropdown and bell match the prototype in geometry, type, colours and motion (same curve and durations), except for the documented deviations.
4. Markup, links and remote icon URLs are inert.
5. DND, critical bypass, low-urgency silence and the island priority rules work as specified.
6. History survives a hot reload; the 50-item cap holds.
7. `SUPER+N`, bell click, `Esc` and click-outside all behave as specified.
8. No `WARN` or `ERROR` in the latest reload.
9. `CLAUDE.md` and `tk421/TK421.md` reflect the change.

## Deviations from the approved prototype

1. Real app icons instead of per-app glyphs.
2. The toolbar capsule holds only the bell until the other items exist.
3. A toast that ends under a resting pointer does not open the calendar.
4. Test triggers are IPC (`notifications inject`), not keyboard shortcuts.
5. `SUPER+N` and the bell are the real entry points; `Esc` and click-outside close.

## Non-goals

- Persisting history across a Quickshell restart or reboot. History survives hot reloads only. DND is not persisted either (it resets on restart).
- Per-app mute rules, grouping by app, notification images, inline reply, sounds, markup and hyperlinks.
- Stacked toasts (one at a time; new replaces old).
- Network, Bluetooth and Power items (separate specs).
- Re-theming `swaync` (it is being removed, not styled).
- Multi-monitor placement (single output today).

## Risks

- **D-Bus name conflict during development.** Mitigated by the mock path and by doing the cutover as its own, explicit step.
- **`HyprlandFocusGrab` and the bell click race.** Known behaviour; the guard is small but must be tested on the real desktop.
- **Island hover refactor.** `hoverOpen` changes from imperative to derived. The island is the most visible part of the shell, so the existing states (idle, media pill, HUD, open, pinned) must be re-checked after this change, not only the new one.
- **App icon appearance.** Coloured third-party icons may look noisy next to the Imperial palette; revisit after seeing real traffic.

## Amendment 2026-10-17: comms drawer and Imperial copy

Approved in `prototypes/notifications/index.html`; supersedes the dropdown geometry above.

- **Drawer, not dropdown.** `NotificationCenter` is a `PanelWindow` anchored top/right/bottom (`margins.top: 40`, 360 px wide) that slides in from the right edge (520 ms open, 340 ms close, same `Ease`). Only the top-left corner is rounded. Fill `surface` at alpha 0.72, blurred by the Hyprland layer rule (namespace `tk421-notifications`). The list fills the height; the empty state sits at 30% of it. The focus grab yields to `Dropdown.held` (screenshots).
- **Imperial labels** (Orbitron, upper case; titles and bodies stay the apps' own): header `COMMS LOG` with `N UNREAD`; button `PURGE`; DND strip `COMMS SILENCED · critical still gets through`; empty `NO TRANSMISSIONS` / `All channels clear.`; toast header `TRANSMISSION · app` or `PRIORITY ALPHA · app` (critical, `dangerText`); low urgency items carry `ROUTINE`; relative times `NOW`, `4M`, `2H`; day labels in upper case. Toggling DND shows the `COMMS` HUD pill (`silenced` / `open`). Bell tooltip text `Comms log`.
- **Toast geometry** is the spec's 360 x 58 (not the 400 x 82 of the plan). Hovered, the card grows to its content: header, up to three body lines, actions.
- **Not in this amendment:** sounds, animated flourishes, the `swaync` cutover.

