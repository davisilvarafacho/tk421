import QtQuick

// The ribbed steel of the door: a flat base crossed by horizontal grooves (a dark line over a light one).
Rectangle {
    id: g

    property real u: 1
    readonly property real pitch: 36 * u

    Rectangle {
        width: parent.width
        height: 1
        color: Qt.rgba(1, 1, 1, 0.045)
    }

    Repeater {
        model: g.pitch > 0 ? Math.ceil(g.height / g.pitch) : 0

        Item {
            required property int index

            y: index * g.pitch
            width: g.width
            height: g.pitch

            Rectangle {
                y: 33 * g.u
                width: parent.width
                height: 2 * g.u
                color: Qt.rgba(0, 0, 0, 0.6)
            }

            Rectangle {
                y: 35 * g.u
                width: parent.width
                height: g.u
                color: Qt.rgba(1, 1, 1, 0.05)
            }
        }
    }
}
