import QtQuick

import "../../theme"
import "../logic.js" as L

// 4. TACTICAL SCAN: a scan line sweeps left to right; the new wallpaper is already there behind it.
// Reference: FX.scan in prototypes/wallpaper/index.html.
Item {
    id: fx

    property url fromSource
    property url toSource
    property real progress: 0
    property int decodeWidth: 2560

    readonly property real lineX: width * L.easeInOutCubic(progress)
    readonly property bool sweeping: progress > 0 && progress < 1

    Cover {
        anchors.fill: parent
        source: fx.fromSource
        decodeWidth: fx.decodeWidth
    }

    Item {
        width: Math.max(0, fx.lineX)
        height: parent.height
        clip: true

        Cover {
            width: fx.width
            height: fx.height
            source: fx.toSource
            decodeWidth: fx.decodeWidth
        }
    }

    // Trail behind the line.
    Rectangle {
        visible: fx.sweeping
        width: Math.min(150, fx.lineX)
        x: fx.lineX - width
        height: parent.height
        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop { position: 0; color: Qt.rgba(0.93, 0.94, 0.93, 0) }
            GradientStop { position: 1; color: Qt.rgba(0.93, 0.94, 0.93, 0.16) }
        }
    }

    // The line, its ticks and the readout.
    Rectangle {
        visible: fx.sweeping
        x: Math.round(fx.lineX) - 1
        width: 1.5
        height: parent.height
        color: Qt.rgba(0.96, 0.965, 0.97, 0.95)
    }

    Repeater {
        model: Math.ceil(fx.height / 24)

        Rectangle {
            required property int index

            visible: fx.sweeping
            x: Math.round(fx.lineX) + 1
            y: index * 24
            width: index % 4 === 0 ? 14 : 7
            height: 1
            color: Qt.rgba(0.96, 0.965, 0.97, 0.85)
        }
    }

    Text {
        visible: fx.sweeping
        x: Math.round(fx.lineX) + 22
        y: 44
        text: "X " + String(Math.round(fx.lineX)).padStart(4, "0")
        color: Qt.rgba(0.96, 0.965, 0.97, 0.9)
        font.family: Theme.displayFont
        font.pixelSize: 11
        font.weight: Font.Medium
        font.letterSpacing: 1.6
        renderType: Text.CurveRendering
    }
}
