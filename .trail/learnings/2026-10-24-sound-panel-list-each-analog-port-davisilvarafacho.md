---
title: "Sound panel: list each analog port as its own output"
author: Davisilvarafacho
date: 2026-10-24
branch: main
cost: { minutes: 2, tokens: 82968 }
touches:
  - dropdown/soundlogic.js
  - services/Sound.qml
  - tests/qml/tst_soundlogic.qml
  - CLAUDE.md
---

## Decided
- PipeWire exposes the motherboard analog out as ONE sink with two ports (Line Out rear, Headphones front), so the bar's sound panel showed 2 outputs instead of 3. Fix: services/Sound.qml expands a sink with 2+ available ports into one entry per port (id "<nodeId>:<port>", `port` field).
- Quickshell's Pipewire module does not expose ports. Ports are read with `pactl -f json list sinks` (Process + StdioCollector, parsed by Logic.parsePorts in dropdown/soundlogic.js) and set with `pactl set-sink-port`; default sink still set via Pipewire.preferredDefaultAudioSink.
- Tests: 3 new cases in tests/qml/tst_soundlogic.qml (run with QT_QPA_PLATFORM=offscreen qmltestrunner), 14 pass.

## Tried and ruled out
- `Array.flatMap` in QML: not available in this engine ("is not a function"), outputs became undefined. Use reduce + concat.
- Checked card profiles and ALSA jack controls (amixer): Front Headphone Jack and Line Out Jack both on, so both ports are really plugged in. No third sink exists.

## Watch out
- The running shell is `quickshell -p ~/.config/quickshell/shell.qml`, NOT ~/Development/quickshell as CLAUDE.md says; `qs ipc -p` must use the ~/.config path. Edits went to ~/.config/quickshell.
- Port info refreshes only on sink-node or default-sink change and after set-port, not on a live jack plug event.
- Verify with `qs ipc -p <shell.qml> call sound list`; switching ports for a test changes real audio, restore Line Out afterwards.
