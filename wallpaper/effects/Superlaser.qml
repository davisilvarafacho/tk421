import QtQuick
import QtQuick.Effects

import "../logic.js" as L

// 1. SUPERLASER (default): eight beams converge on the centre, flash, a ring of light opens the new wallpaper from the centre.
// Reference: FX.laser in prototypes/wallpaper/index.html.
Item {
    id: fx

    property url fromSource
    property url toSource
    property real progress: 0
    property int decodeWidth: 2560

    readonly property real charge: 0.22
    readonly property real cx: width / 2
    readonly property real cy: height / 2
    readonly property real chargeT: L.clamp(progress / charge)
    readonly property real expand: L.clamp((progress - charge) / (1 - charge))
    readonly property real maxR: Math.hypot(cx, cy) * 1.02
    readonly property real radius: maxR * L.easeOutQuart(expand)
    readonly property real fade: Math.pow(1 - expand, 0.7)

    // A ring centred on (cx, cy) with radius `r` and stroke `w`. (Inline components cannot see ids of the enclosing file, so the
    // centre is passed in.)
    component Ring: Rectangle {
        property real cx: 0
        property real cy: 0
        property real r: 0
        property real w: 1

        x: cx - (r + w / 2)
        y: cy - (r + w / 2)
        width: 2 * (r + w / 2)
        height: width
        radius: width / 2
        color: "transparent"
        border.width: w
    }

    Cover {
        anchors.fill: parent
        source: fx.fromSource
        decodeWidth: fx.decodeWidth
    }

    // The old wallpaper dips while the ring passes.
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.4 * Math.sin(Math.PI * Math.min(1, fx.expand * 1.3))
    }

    // The new wallpaper, revealed through a growing circle.
    Item {
        anchors.fill: parent
        visible: fx.progress >= fx.charge
        layer.enabled: visible
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: circle
        }

        Cover {
            anchors.fill: parent
            source: fx.toSource
            decodeWidth: fx.decodeWidth
            scale: 1 + 0.05 * (1 - L.easeOutCubic(fx.expand))
        }
    }

    Item {
        id: circle

        anchors.fill: parent
        visible: false
        layer.enabled: true

        Rectangle {
            x: fx.cx - fx.radius
            y: fx.cy - fx.radius
            width: fx.radius * 2
            height: width
            radius: fx.radius
            color: "white"
        }
    }

    // Light ring on the edge, and a fainter wider one standing in for the glow.
    Ring {
        cx: fx.cx
        cy: fx.cy
        visible: fx.progress >= fx.charge && fx.expand < 1
        r: fx.radius
        w: 1.5 + 3.5 * (1 - fx.expand)
        border.color: Qt.rgba(0.94, 0.96, 0.95, fx.fade)
    }

    Ring {
        cx: fx.cx
        cy: fx.cy
        visible: fx.progress >= fx.charge && fx.expand < 1
        r: fx.radius
        w: 10 + 14 * (1 - fx.expand)
        border.color: Qt.rgba(0.94, 0.96, 0.95, 0.12 * fx.fade)
    }

    // Charge: eight beams converge on the centre.
    Repeater {
        model: 8

        Item {
            id: beam

            required property int index
            readonly property real rs: Math.min(fx.width, fx.height) * 0.55
            readonly property real head: rs * (1 - L.easeInCubic(fx.chargeT))
            readonly property real tail: Math.min(rs, head + rs * 0.3)

            x: fx.cx
            y: fx.cy
            rotation: index * 45 + 22.5
            visible: fx.progress < fx.charge

            Rectangle {
                x: beam.head
                y: -0.75
                width: beam.tail - beam.head
                height: 1.5
                color: Qt.rgba(0.93, 0.94, 0.93, 0.85)
            }
        }
    }

    // The core grows during the charge, then flashes out as the ring leaves.
    Item {
        id: core

        readonly property real size: fx.progress < fx.charge ? 4 + 46 * fx.chargeT * fx.chargeT : 260

        anchors.centerIn: parent
        width: size * 3
        height: width
        opacity: fx.progress < fx.charge ? 0.3 + 0.7 * fx.chargeT : L.clamp(1 - fx.expand * 3.2)
        visible: opacity > 0.01
        layer.enabled: visible
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 64
            blur: 1.0
        }

        Rectangle {
            anchors.centerIn: parent
            width: core.size * 2
            height: width
            radius: core.size
            color: "white"
        }
    }
}
