# Wallpaper picker — Design

`Super+Alt+B` opens a blast door in the middle of the screen; behind its leaves is a bay with the wallpapers. ←/→ move the selection and the desktop behind changes **live**, with a Star Wars transition. Prototype (approved direction, graphite and steel, no hue): `prototypes/wallpaper/index.html` (`?open=1`, `?effect=laser|hyperspace|doors|scan`, `?freeze=0.5` renders a transition frozen at that progress, `?seal=0..1` freezes the leaves).

## Behaviour

- **Source:** every `png jpg jpeg webp gif` in `~/Pictures/Wallpapers`, sorted by name, read when the picker opens. The wallpaper that is applied always appears in the bay too, even when it lives outside the folder (today it does). Videos (the `.mp4`) are ignored: `awww` only paints images and GIFs. Empty folder: the bay shows "NO IMAGES", Esc closes.
- **Open / close:** IPC `wallpaper toggle`; Hyprland binds `SUPER + ALT + B` to it (same shape as the launcher bind). Opening plays the one authored moment: the lock lamp clears, the two leaves part (820 ms, heavy ease) and retract into the jambs, the ceiling light comes on, the plates settle in from the centre outward. Closing is faster (520 ms). It always opens on the wallpaper that is currently applied.
- **Keys:** ← → previous/next wallpaper (wraps); ↑ ↓ previous/next effect; Enter applies; Esc cancels (the desktop transitions back to the original with the current effect); click on a plate selects it, click outside the door cancels. **The effect is one button** in the lintel (`EffectButton`): click it, or scroll the mouse wheel over it, to cycle the effect (down is next, up is previous); the name slides in the direction of the change. **Scrolling over the bay changes the wallpaper** the same way (down is forward). The wheel is read with `MouseArea.onWheel`, because `WheelHandler` never fires on this Quickshell/Qt. Exclusive keyboard focus while open, as the launcher.
- **Live preview:** every selection change starts a transition from what is on screen to the new wallpaper. A request that arrives mid-transition finishes the running one instantly and starts the next (arrow keys held down must not queue). Changing the effect does not touch the desktop: it applies to the next wallpaper change. (An earlier version replayed the effect from the previous wallpaper, which made the desktop jump to it and back; removed on request.)
- **Effects** (labels in English, order fixed; **Superlaser is the default**, the choice is remembered):
  1. **SUPERLASER** (1000 ms): eight beams converge on the centre, flash, a ring of light opens the new wallpaper from the centre.
  2. **HYPERSPACE** (1200 ms): stars streak out of the centre while the old wallpaper stretches, white flash, the new one drops out of lightspeed.
  3. **BLAST DOORS** (1000 ms): the old wallpaper is cut into nine slats that part from the centre, middle slats first.
  4. **TACTICAL SCAN** (900 ms): a scan line sweeps left to right with a trail and an `X 0000` readout; the new wallpaper is revealed behind it.
  With reduced motion (system setting) every effect becomes a 260 ms crossfade.
- **Out of scope:** the lock screen keeps its own fixed wallpaper (`Theme.wallpaper`); video or animated backgrounds; more than one monitor (only DP-1 exists).

## Architecture

**Approach: `awww` stays the real wallpaper, the shell draws only the transition.** `awww` has no hyperspace or blast doors, and replacing it would make the background vanish whenever the shell reloads (it hot-reloads on every save). So:

- `awww-daemon` (systemd user service `tk421-wallpaper`) keeps painting the persistent wallpaper. The shell never stops it.
- A **stage window** (`WlrLayer.Bottom`, above the background layer, below every window, input mask empty so clicks pass through) draws what the user sees while the picker is open or a transition runs. Its `from` image is the applied wallpaper, scaled exactly as `awww` does (cover, centred) so the hand-over is invisible.
- **Apply:** run `awww img --transition-type none <file>`, wait for the process to exit plus one frame, then hide the stage. **Cancel:** transition back, hide the stage, run nothing.
- If `awww` fails (daemon down, bad file): keep the stage on the last good image, show a `Hud` pill with the error, and leave the stored state untouched.

### Units

| File | Does | Depends on |
|---|---|---|
| `services/Wallpaper.qml` (singleton) | lists the folder, holds `applied`, `selected`, `effect`, applies through `awww`, persists, IPC `wallpaper` | `awww`, `wallpaper/logic.js`, `Hud` |
| `wallpaper/WallpaperPicker.qml` (+ small parts: `Ease`, `Grooves`, `DoorLeaf`, `DoorJamb`, `Plate`, `KeyHint`, `EffectButton`) | the door: lintel (the effect button, one lamp per wallpaper), bay (plates), jambs, leaves, sill (name, size, keys); Overlay layer, exclusive focus | `Wallpaper`, `Theme` |
| `wallpaper/WallpaperStage.qml` | the Bottom-layer window; holds `from`/`to` images and the running effect | `Wallpaper` |
| `wallpaper/effects/{Superlaser,Hyperspace,BlastDoors,TacticalScan}.qml` | one effect each, same interface: `fromSource`, `toSource`, `progress` (0..1), plus `snap()` | none |
| `wallpaper/logic.js` | pure rules: file filter and sort, wrap-around index, plate slot (offset → x, scale, opacity), next/previous effect, `awww` argument list | none |

Also touched: `shell.qml` (instantiate `WallpaperPicker` and `WallpaperStage`), `services/qmldir`, `.gitignore` (`wallpaper/state.json`), `hypr/hyprland.lua` (the bind, and the boot restore below), `CLAUDE.md` (document the IPC and the layer trick).

IPC target `wallpaper`: `toggle`, `isOpen`, `next`, `prev`, `effect <laser|hyperspace|doors|scan>`, `status`, `list`. No `show`/`hide` names.

### Effects: how they map to QML

Scene-graph items and clips, not `Canvas` (no per-frame CPU painting at 2560×1080), no custom shaders unless an effect cannot be made without one. The circle of Superlaser is a `MultiEffect` mask (already used by the island); Hyperspace is a pool of ~400 thin rotated rectangles; Blast Doors is 18 clipped images sharing one texture; Tactical Scan is a clipped image plus a line and gradient. The timing and easing are the ones in the prototype; its `render(p)` functions are the reference.

### Images

Plates are decoded at plate size, asynchronously, and only for the seven nearest the selection. The stage decodes at screen size (cover) and keeps the previous, current and next wallpapers loaded so a key press never waits on a 4K PNG.

## State and boot

- `wallpaper/state.json` (inside the repo, git-ignored): `{ "path": "...", "effect": "laser" }`, written atomically after Enter. A missing or broken file means: current `awww` wallpaper, effect Superlaser.
- **Boot restore.** The "TK421 SESSION STARTUP" block of `hypr/hyprland.lua` already waits for `awww-daemon` and paints a fixed image at login. That command becomes `wallpaper/restore.sh`, which paints the saved wallpaper (or the default one when the state is missing, corrupt or points at a file that is gone). The shell only reads the state, so two painters never race. This edits the live Hyprland config; the exact diff is in the implementation plan.

## Errors and safety

- File names come from outside: shown `PlainText`, control and bidi characters stripped, 40 characters.
- A file that fails to decode is skipped from the bay and logged once.
- The folder is watched while the picker is open (a wallpaper added or removed appears without reopening).
- No `dryRun`: applying a wallpaper is reversible and is meant to work at once.

## Testing

- `tests/qml/tst_wallpaperlogic.qml` for `logic.js` (filter, sort, wrap, slots, effect cycle, `awww` args).
- IPC for the flow (`toggle`, `next`, `prev`, `effect`, `status`); real keys only through `/dev/uinput` and only when the user's own cursor and keyboard are idle.
- `grim` only on a region inside the door; never the whole screen.
- **The tests change the real desktop wallpaper**: record `awww query` first and restore that exact image at the end. Do not run them while the user is watching a video or presenting.
- Log check after the reload: zero new `WARN|ERROR`.

## Acceptance

`Super+Alt+B` opens the door in the middle of the screen; the leaves part smoothly; ←/→ slide the plates and change the desktop live with the chosen effect; ↑/↓ change and replay the effect; Enter keeps the wallpaper (surviving a shell reload and a login); Esc restores the original; no visible jump when the stage hands over to `awww`; the four effects look like the prototype; tests pass; no new warnings.

## Open points

- **Superlaser origin:** the door covers the screen centre, so the converging beams and the flash start behind it and only the expanding ring clears the frame. If that reads badly in the real thing, the origin moves to the door's frame edge or the charge phase is shortened.
- **Beam colour:** the prototype keeps it cold white to follow the no-hue rule; a pale green (the film's superlaser) is a one-token change if wanted.
- **Lock screen:** left out on purpose; following the chosen wallpaper is a small follow-up if wanted.
