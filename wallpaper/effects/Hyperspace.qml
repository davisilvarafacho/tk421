import QtQuick
import QtQuick.Effects

import "../logic.js" as L

// 2. HYPERSPACE: stars streak out of the centre while the old wallpaper stretches, white flash, the new one drops out of lightspeed.
// Reference: FX.hyperspace in prototypes/wallpaper/index.html.
Item {
    id: fx

    property url fromSource
    property url toSource
    property real progress: 0
    property int decodeWidth: 2560

    readonly property real split: 0.46
    readonly property real cx: width / 2
    readonly property real cy: height / 2
    readonly property real maxR: Math.hypot(cx, cy)
    readonly property real v: L.clamp((progress - split) / (1 - split))
    // Speed accelerates to the jump and decelerates out of it; `dist` is the distance travelled so far.
    readonly property real speed: progress < split ? L.easeInCubic(progress / split) : Math.pow(2, -9 * v)
    readonly property real dist: progress < split ? 0.1125 * Math.pow(progress / split, 4) : 0.1125 + 0.0794 * (1 - Math.pow(2, -9 * v))
    readonly property real stretch: L.easeInCubic(L.clamp(progress / split))
    readonly property real settle: L.easeOutExpo(v)

    property var stars: makeStars(400)

    function makeStars(n) {
        const out = []
        for (let i = 0; i < n; i++)
            out.push({ a: Math.random() * Math.PI * 2, d: 0.015 + Math.random() * 0.5, z: 0.25 + Math.random() * 0.75 })
        return out
    }

    // The old wallpaper zooms and blurs toward the jump.
    Cover {
        anchors.fill: parent
        source: fx.fromSource
        decodeWidth: fx.decodeWidth
        visible: fx.progress < fx.split + 0.04
        scale: 1 + 0.14 * fx.stretch
        layer.enabled: visible && fx.stretch > 0.02
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 32
            blur: fx.stretch * 0.075
            brightness: 0.35 * fx.stretch
        }
    }

    // The new wallpaper drops out of lightspeed.
    Cover {
        anchors.fill: parent
        source: fx.toSource
        decodeWidth: fx.decodeWidth
        visible: fx.progress >= fx.split
        scale: 1 + 0.22 * (1 - fx.settle)
        layer.enabled: visible && fx.settle < 0.98
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 32
            blur: 0.19 * (1 - fx.settle)
            brightness: 0.3 * (1 - fx.settle)
        }
    }

    Repeater {
        model: fx.stars

        Rectangle {
            required property var modelData

            readonly property real out: modelData.d * fx.maxR * (1 + fx.dist * 14 * modelData.z)
            readonly property real tail: out / (1 + fx.speed * 4.2 * modelData.z)

            visible: out < fx.maxR * 1.05 && out - tail > 0.5
            x: fx.cx + Math.cos(modelData.a) * tail
            y: fx.cy + Math.sin(modelData.a) * tail - height / 2
            width: out - tail
            height: 0.6 + modelData.z * 1.6
            radius: height / 2
            transformOrigin: Item.Left
            rotation: modelData.a * 180 / Math.PI
            color: Qt.rgba(0.91, 0.93, 0.94, L.clamp(0.25 + fx.speed * 0.75) * (0.4 + modelData.z * 0.6))
        }
    }

    // The jump itself.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.96, 0.965, 0.97, 1)
        opacity: 0.92 * Math.max(0, 1 - Math.abs(fx.progress - fx.split) / 0.09)
        visible: opacity > 0.01
    }
}
