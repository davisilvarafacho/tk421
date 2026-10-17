# Sound quick controls — Design

Part of the toolbar (prototype `prototypes/toolbar/index.html`), on the shared dropdown host. The full sound manager (list every device, enable/disable, per-app volumes) is a later step and is **not** part of this.

## What it adds

- **Volume of the default output:** a speaker glyph that mutes/unmutes on click, the level (Orbitron, `59%`, or `mute`) that opens the sound panel, and the mouse wheel to change the volume in 5 % steps. The island keeps showing its own volume HUD (it follows the same default sink).
- **Microphone of the default input, three states:** **on** (plain), **muted** (struck through, `dangerText`), **not recognised** (no input device at all: dimmed with a small "?"). Click mutes/unmutes; with no microphone, or on right-click, it opens the sound panel.
- **Sound panel (340 px):** Output: a draggable volume slider with mute button and the output devices; Input: the same for inputs ("No input device recognised." when there is none). Clicking a device makes it the default (`Pipewire.preferredDefaultAudioSink/Source`); the island confirms with a pill ("OUTPUT <name>").

## Rules and data

- `services/Sound.qml` wraps `Quickshell.Services.Pipewire`: non-stream audio nodes split into sinks and sources, tracked with `PwObjectTracker`; volume and mute are written straight to the node's `audio`. `mock` gives fake devices and microphone states for visual checks.
- Pure rules in `dropdown/soundlogic.js` (microphone state, volume step and clamp, texts, glyphs, device name/glyph/sub-line, cleaning of device names) with unit tests.
- Device names come from outside: `PlainText`, control and bidi characters removed, 40 characters.
- No `dryRun`: volume, mute and switching the default are reversible and expected to work at once.

## Acceptance

Real devices of this machine (two outputs, one input) listed correctly; the three microphone states render as in the prototype; volume and mute writes match `wpctl`; tests pass; no new warnings.
