# Volume Flyout — Design

## Goal

When the default audio sink's volume or mute state changes, show a compact card at the bottom center of the screen (Modern Flyouts style). It hides itself after ~1.5s. It is a pure indicator: no interaction.

Out of scope for now: media, brightness, caps lock / num lock flyouts (later phases).

## Decisions

- Position: bottom center, ~60px margin from the bottom edge.
- Detection: Quickshell observes PipeWire (`Quickshell.Services.Pipewire`, available in Quickshell 0.3.2). Hyprland XF86 binds are not changed. Any volume change (keys, panel, other apps) triggers the flyout.

## Components

1. `services/Audio.qml` (singleton)
   - Wraps `Pipewire.defaultAudioSink` with a `PwObjectTracker`.
   - Exposes `volume` (0..1), `muted`, and a `changed` signal.
   - Only unit that knows about PipeWire.
2. `flyouts/VolumeFlyout.qml`
   - `PanelWindow`, overlay layer, anchored bottom + horizontally centered, no keyboard focus, does not block input outside the card.
   - Nerd Font icon by level (muted / low / medium / high), progress bar, percentage.
   - Fade + slight rise on show. A `Timer` hides it; each new change restarts the timer.
3. `theme/Theme.qml` (currently empty)
   - Gains the colors/fonts the flyout needs: background `#CC111418`, border `#39414D`, text `#E8E6E3`, font Geist.
   - Migrating the rest of the bar to Theme is a separate task.
4. `shell.qml` instantiates `VolumeFlyout`.

## Behavior details

- The first reading at shell startup does not show the flyout.
- Changing the default sink alone does not show it; only volume/mute changes do.
- Changes to `Theme.qml` are additive.

## Testing (manual)

Run `quickshell` manually, then:
- `wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+` / `5%-` shows the flyout with the right value and icon.
- `wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle` shows the muted icon.
- Repeated changes keep it visible and restart the timer; it hides ~1.5s after the last change.
- No flyout on startup or on sink switch.

## Note

Hyprland does not currently autostart Quickshell (`hyprland.lua` has a "paused" block). Re-enabling autostart is a separate step, done only on request.
