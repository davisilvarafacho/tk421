import QtQuick

import "../dropdown/soundlogic.js" as Logic
import "../services"
import "../theme"

// Microphone of the default input, three states: on, muted (struck through, red) and not recognised (dimmed, with a "?").
// Click mutes or unmutes; with no microphone it opens the sound panel instead, and so does a right-click.
Item {
    id: item

    readonly property var c: Theme.imperial
    readonly property string state_: Sound.micState

    implicitWidth: 24
    implicitHeight: 22

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: item.c.surfaceAlt
        opacity: area.containsMouse ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 140 }
        }
    }

    Text {
        anchors.centerIn: parent
        text: Logic.micGlyph(item.state_)
        color: item.state_ === "muted" ? item.c.dangerText : item.state_ === "missing" ? "#6D727B"
            : area.containsMouse ? item.c.text : "#B5BAC3"
        renderType: Text.CurveRendering
        font.family: Theme.iconFont
        font.pixelSize: 14

        Behavior on color {
            ColorAnimation { duration: 140 }
        }
    }

    // Not recognised: a small question mark.
    Text {
        visible: item.state_ === "missing"
        x: parent.width - width - 2
        y: 0
        text: "?"
        color: item.c.muted
        renderType: Text.CurveRendering
        font.family: Theme.displayFont
        font.pixelSize: 8
        font.weight: Font.Bold
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton || item.state_ === "missing")
                Dropdown.toggle("sound")
            else
                Sound.toggleMute("in")
        }
    }
}
