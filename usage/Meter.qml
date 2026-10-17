import QtQuick

import "../theme"

// Thin track with a tick every 25%. Steel fill, near-white from 80% on (no hue, see the launcher decision).
Item {
    id: meter

    property real value: 0              // 0..100
    property int trackHeight: 3
    readonly property bool hot: value >= 80

    implicitHeight: trackHeight

    Rectangle {
        id: track

        anchors.fill: parent
        radius: height / 2
        color: "#26252b"
        clip: true

        Rectangle {
            height: parent.height
            width: parent.width * Math.max(0, Math.min(100, meter.value)) / 100
            radius: height / 2
            color: meter.hot ? "#f2f0ed" : "#b9b6b2"

            Behavior on width {
                NumberAnimation {
                    duration: 700
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
                }
            }

            Behavior on color { ColorAnimation { duration: 300 } }
        }

        Repeater {
            model: [0.25, 0.5, 0.75]

            Rectangle {
                required property real modelData

                x: track.width * modelData
                width: 1
                height: parent.height
                color: Theme.imperial.surface
                opacity: 0.9
            }
        }
    }
}
