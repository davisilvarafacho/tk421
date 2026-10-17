import QtQuick

// One leaf of the blast door. It slides out of the bay and is hidden by its jamb; the opening is slow to start and slow to stop.
Item {
    id: leaf

    property int side: -1               // -1 = left leaf, 1 = right leaf
    property bool open: false
    property real u: 1
    property real bayWidth: 1280

    readonly property real closedX: side < 0 ? 0 : bayWidth / 2

    width: bayWidth / 2
    height: parent ? parent.height : 0
    x: closedX + (open ? side * width * 1.01 : 0)
    z: 5

    Behavior on x {
        SequentialAnimation {
            PauseAnimation { duration: leaf.open ? 260 : 0 }

            NumberAnimation {
                duration: leaf.open ? 820 : 520
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.65, 0, 0.2, 1, 1, 1]
            }
        }
    }

    Grooves {
        anchors.fill: parent
        u: leaf.u
        color: "#18181d"
    }

    // Sunken panel.
    Rectangle {
        x: 46 * leaf.u
        y: 40 * leaf.u
        width: parent.width - 92 * leaf.u
        height: parent.height - 80 * leaf.u
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.06)
    }

    // Seam strip at the edge that meets the other leaf, heavier than the grooves.
    Rectangle {
        x: leaf.side < 0 ? parent.width - width : 0
        width: 16 * leaf.u
        height: parent.height
        border.width: 1
        border.color: "black"
        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop { position: 0; color: "#0b0b0d" }
            GradientStop { position: 0.45; color: "#202026" }
            GradientStop { position: 1; color: "#0b0b0d" }
        }
    }
}
