import Quickshell
import Quickshell.Io
import QtQuick

import "../components"
import "../services"
import "../theme"
import "logic.js" as Logic

// Audio: a cava spectrum (48 bands, raw ascii output of `cava -p widgets/cava.conf`, read line by line) above the
// default output and input with their volume (services/Sound.qml). Read-only: the sound dropdown changes them.
// cava only runs while `running` (the widgets are on screen).
WidgetPanel {
    id: w

    property bool running: false
    readonly property int bands: 48
    property var levels: Array(bands).fill(0)
    readonly property bool idle: levels.every(v => v < 0.01)

    readonly property var output: Sound.outputs.find(o => o.current) ?? null
    readonly property var input: Sound.inputs.find(o => o.current) ?? null

    label: "Audio"
    aside: "cava · " + bands + " bands"

    onRunningChanged: if (!running) levels = Array(bands).fill(0)

    Process {
        running: w.running
        command: ["cava", "-p", Quickshell.shellPath("widgets/cava.conf")]
        stdout: SplitParser {
            onRead: line => w.levels = Logic.parseFrame(line, w.bands, 1000)
        }
    }

    component VolumeRow: Item {
        id: r

        property string icon: ""
        property string name: ""
        property real volume: 0
        property bool muted: false

        width: parent.width
        height: 30

        Icon {
            y: 4
            name: r.icon
            size: Theme.iconSize.panel
            color: r.muted ? Theme.imperial.faint : "#B5BAC3"
        }

        Text {
            x: 32
            y: 2
            width: parent.width - 32 - 50
            text: r.name
            textFormat: Text.PlainText      // device names come from PipeWire
            elide: Text.ElideRight
            color: Theme.imperial.muted
            renderType: Text.CurveRendering
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }

        Rectangle {
            x: 32
            y: 21
            width: parent.width - 32 - 50
            height: 3
            radius: 1.5
            color: "#1F1F25"

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, r.volume))
                height: parent.height
                radius: 1.5
                color: r.muted ? "#4A494D" : "#B9B6B2"

                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }
        }

        Text {
            anchors.right: parent.right
            y: 8
            text: Math.round(r.volume * 100) + "%"
            color: r.muted ? Theme.imperial.faint : Theme.imperial.text
            renderType: Text.CurveRendering
            font.family: Theme.displayFont
            font.weight: Font.Medium
            font.pixelSize: 12
        }
    }

    // The spectrum: bars grow from the bottom, faint while nothing plays.
    Row {
        id: spectrum

        width: parent.width
        height: 64
        spacing: 2
        opacity: w.idle ? 0.25 : 0.9

        Behavior on opacity { NumberAnimation { duration: 300 } }

        Repeater {
            model: w.bands

            delegate: Item {
                required property int index

                width: (spectrum.width - (w.bands - 1) * spectrum.spacing) / w.bands
                height: spectrum.height

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Math.max(1, parent.height * w.levels[index])
                    radius: 1
                    color: "#B9B6B2"
                }
            }
        }
    }

    Item { width: 1; height: 12 }

    VolumeRow {
        icon: Sound.outGlyph
        name: (w.output?.name ?? "No output") + (Sound.outMuted ? " · muted" : "")
        volume: Sound.outVolume
        muted: Sound.outMuted
    }

    Item { width: 1; height: 6 }

    VolumeRow {
        icon: Sound.inMuted ? "mic_muted" : "mic"
        name: Sound.hasSource ? (w.input?.name ?? "Microphone") + (Sound.inMuted ? " · muted" : "") : "No microphone"
        volume: Sound.hasSource ? Sound.inVolume : 0
        muted: Sound.inMuted || !Sound.hasSource
    }
}
