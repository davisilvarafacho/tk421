import QtQuick

import "../logic.js" as L

// 3. BLAST DOORS: the old wallpaper is cut into nine slats that part from the centre like the picker's own door, middle slats first.
// Reference: FX.doors in prototypes/wallpaper/index.html. All slats share one decoded texture.
Item {
    id: fx

    property url fromSource
    property url toSource
    property real progress: 0
    property int decodeWidth: 2560

    readonly property int rows: 9
    readonly property real rh: height / rows
    readonly property real lag: 0.3
    readonly property real arrive: L.easeOutCubic(progress)

    // The new wallpaper waits behind the slats, dim at first.
    Cover {
        anchors.fill: parent
        source: fx.toSource
        decodeWidth: fx.decodeWidth
        scale: 1 + 0.04 * (1 - fx.arrive)
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.45 * (1 - fx.arrive)
    }

    Repeater {
        model: fx.rows

        Item {
            id: row

            required property int index
            readonly property real d: Math.abs(index - (fx.rows - 1) / 2) / ((fx.rows - 1) / 2)
            readonly property real e: L.easeInOutQuart(L.clamp((fx.progress - d * fx.lag) / (1 - fx.lag)))

            y: index * fx.rh
            width: fx.width
            height: fx.rh + 1

            Repeater {
                model: 2

                Item {
                    id: half

                    required property int index         // 0 = left half, 1 = right half
                    readonly property real dir: index === 0 ? -1 : 1

                    x: index * fx.width / 2 + dir * (fx.width / 2) * 1.005 * row.e
                    width: fx.width / 2
                    height: row.height
                    clip: true
                    visible: row.e < 1

                    // Each slat shows its own slice of the full-screen image.
                    Cover {
                        x: -half.index * fx.width / 2
                        y: -row.y
                        width: fx.width
                        height: fx.height
                        source: fx.fromSource
                        decodeWidth: fx.decodeWidth
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.07)
                    }

                    Rectangle {
                        y: parent.height - 1
                        width: parent.width
                        height: 1
                        color: Qt.rgba(0, 0, 0, 0.6)
                    }
                }
            }
        }
    }
}
