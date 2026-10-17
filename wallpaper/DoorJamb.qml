import QtQuick

// The jamb the leaves retract into: it keeps the door readable as a door once it is open.
Item {
    id: jamb

    property int side: -1
    property bool open: false
    property real u: 1

    width: 58 * u
    height: parent ? parent.height : 0
    z: 7

    Grooves {
        anchors.fill: parent
        u: jamb.u
        color: "#121216"
    }

    Rectangle {
        x: jamb.side < 0 ? parent.width - 1 : 0
        width: 1
        height: parent.height
        color: "#2A2A31"
    }

    // Status lamp: lit once the door is open.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 16 * jamb.u
        width: 14 * jamb.u
        height: 3 * jamb.u
        color: jamb.open ? "#F2F0ED" : "#2A2A31"

        Behavior on color {
            SequentialAnimation {
                PauseAnimation { duration: jamb.open ? 520 : 0 }
                ColorAnimation { duration: 240 }
            }
        }
    }
}
