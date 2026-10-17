# Volume Flyout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a bottom-center card when the default sink's volume or mute changes.

**Architecture:** An `Audio` singleton wraps PipeWire and emits `changed`. A `VolumeFlyout` overlay window listens, shows the card and auto-hides it. Colors/fonts come from the existing empty `Theme` singleton.

**Tech Stack:** Quickshell 0.3.2, QtQuick, `Quickshell.Services.Pipewire`, `Quickshell.Wayland` (layer shell).

**Spec:** `docs/superpowers/specs/2026-10-11-volume-flyout-design.md`

## Global Constraints

- Position: bottom center, ~60px margin from the bottom edge.
- Auto-hide after ~1.5s; each new change restarts the timer.
- No PipeWire logic outside `services/Audio.qml`.
- Do not change Hyprland XF86 binds or autostart.
- Colors: bg `#CC111418`, border `#39414D`, text `#E8E6E3`; font Geist; icons Symbols Nerd Font Mono.
- Existing QML style: 4-space indent, double quotes.

## Review Focus

- First reading at startup must not show the flyout (Task 1 `ready` guard, Task 3 check).
- Default sink switch must not show it (Task 1 compares sink identity).
- No sink available (`defaultAudioSink` null) must not error (Task 1 null guards).
- Volume above 100% (wpctl limit raised) must clamp the bar, not overflow (Task 2 clamp).
- Rapid repeated changes must keep the card visible and not flicker (Task 3 check).

---

### Task 1: Audio singleton

**Files:**
- Create: `services/Audio.qml`
- Create: `services/qmldir`

**Interfaces:**
- Produces: singleton `Audio` with `real volume`, `bool muted`, `signal changed()`.

- [ ] **Step 1: Check whether `services/` already has a qmldir**

Run: `ls /home/tk421/Development/quickshell/services`
Expected: `SystemStats.qml` only. If a `qmldir` exists, add the line below to it instead of creating one.

- [ ] **Step 2: Create `services/Audio.qml`**

```qml
pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false

    signal changed()

    // Ignore the initial readings and sink switches; only real changes count.
    property bool ready: false
    property var lastSink: null

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    onSinkChanged: {
        lastSink = sink
        ready = false
        settle.restart()
    }

    Timer {
        id: settle
        interval: 300
        running: true
        onTriggered: root.ready = true
    }

    onVolumeChanged: if (ready) changed()
    onMutedChanged: if (ready) changed()
}
```

- [ ] **Step 3: Create `services/qmldir`**

```
singleton Audio Audio.qml
SystemStats SystemStats.qml
```

- [ ] **Step 4: Verify it loads**

Run: `cd /home/tk421/Development/quickshell && timeout 5 quickshell -p . 2>&1 | head -20`
Expected: no `Audio` or qmldir errors in the output.

### Task 2: Theme tokens and VolumeFlyout

**Files:**
- Modify: `theme/Theme.qml`
- Create: `theme/qmldir`
- Create: `flyouts/VolumeFlyout.qml`

**Interfaces:**
- Consumes: `Audio.volume`, `Audio.muted`, `Audio.changed()`.
- Produces: `VolumeFlyout` window item; `Theme.background`, `Theme.border`, `Theme.text`, `Theme.fontFamily`, `Theme.iconFont`.

- [ ] **Step 1: Replace `theme/Theme.qml`**

```qml
pragma Singleton
import QtQuick

QtObject {
    id: root

    readonly property color background: "#CC111418"
    readonly property color border: "#39414D"
    readonly property color text: "#E8E6E3"
    readonly property color muted: "#858B95"
    readonly property string fontFamily: "Geist"
    readonly property string iconFont: "Symbols Nerd Font Mono"
}
```

- [ ] **Step 2: Create `theme/qmldir`**

```
singleton Theme Theme.qml
```

- [ ] **Step 3: Create `flyouts/VolumeFlyout.qml`**

```qml
import Quickshell
import Quickshell.Wayland
import QtQuick

import "../services"
import "../theme"

PanelWindow {
    id: flyout

    property bool shown: false

    anchors.bottom: true
    margins.bottom: 60

    implicitWidth: 260
    implicitHeight: 56
    visible: shown || card.opacity > 0
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "tk421-flyout"
    exclusionMode: ExclusionMode.Ignore

    // Empty input region: clicks pass through to windows below.
    mask: Region {}

    function icon() {
        if (Audio.muted || Audio.volume <= 0) return "󰖁"
        if (Audio.volume < 0.34) return "󰕿"
        if (Audio.volume < 0.67) return "󰖀"
        return "󰕾"
    }

    Connections {
        target: Audio
        function onChanged() {
            flyout.shown = true
            hideTimer.restart()
        }
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: flyout.shown = false
    }

    Rectangle {
        id: card

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: flyout.shown ? 0 : 8
        width: parent.width
        height: parent.height
        radius: 14
        color: Theme.background
        border.width: 1
        border.color: Theme.border
        opacity: flyout.shown ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 150 } }
        Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        Row {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            Text {
                text: flyout.icon()
                color: Audio.muted ? Theme.muted : Theme.text
                font.family: Theme.iconFont
                font.pixelSize: 20
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                width: parent.width - 20 - 12 * 2 - 40
                height: 6
                radius: 3
                color: Theme.border
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, Audio.volume))
                    height: parent.height
                    radius: 3
                    color: Audio.muted ? Theme.muted : Theme.text
                }
            }

            Text {
                width: 40
                horizontalAlignment: Text.AlignRight
                text: Audio.muted ? "MUTE" : Math.round(Audio.volume * 100) + "%"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
```

- [ ] **Step 4: Verify it parses**

Run: `cd /home/tk421/Development/quickshell && timeout 5 quickshell -p . 2>&1 | head -20`
Expected: no QML errors (the flyout is not instantiated yet).

### Task 3: Wire into shell and test manually

**Files:**
- Modify: `shell.qml`

- [ ] **Step 1: Edit `shell.qml`**

```qml
import Quickshell
import QtQuick
import "bar"
import "flyouts"
import "services"

ShellRoot {
    SystemStats {
        id: systemStats
    }

    Bar {}
    VolumeFlyout {}
}
```

- [ ] **Step 2: Start Quickshell in the background**

Run: `cd /home/tk421/Development/quickshell && quickshell -p . > /tmp/qs-flyout.log 2>&1 &`
Expected: bar visible, log has no errors, no flyout on startup (Review Focus: first reading).

- [ ] **Step 3: Volume up/down**

Run: `wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ ; sleep 0.5 ; wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-`
Expected: card shows at bottom center with correct %, hides ~1.5s after the last change.

- [ ] **Step 4: Mute toggle**

Run: `wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ; sleep 2 ; wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle`
Expected: muted icon and "MUTE" label, then restored.

- [ ] **Step 5: Rapid changes**

Run: `for i in 1 2 3 4 5; do wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%+; sleep 0.3; done; for i in 1 2 3 4 5; do wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%-; sleep 0.3; done`
Expected: card stays visible without flicker, hides ~1.5s after the last change.

- [ ] **Step 6: Over-100% clamp**

Run: `wpctl set-volume @DEFAULT_AUDIO_SINK@ 1.2 ; sleep 2 ; wpctl set-volume @DEFAULT_AUDIO_SINK@ <original>`
Expected: bar fills to the end without overflowing the card. Restore the original volume afterward (read it first with `wpctl get-volume @DEFAULT_AUDIO_SINK@`).

- [ ] **Step 7: Stop Quickshell and check the log**

Run: `pkill -f "quickshell -p" ; cat /tmp/qs-flyout.log`
Expected: no errors or warnings about Audio, Theme or VolumeFlyout.

- [ ] **Step 8: Commit (only if the user has asked for commits)**

```bash
git add shell.qml services theme flyouts docs
git commit -m "feat(flyouts): add volume flyout"
```
