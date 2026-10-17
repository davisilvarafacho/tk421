import QtQuick

import "../services"
import "../theme"

// Bluetooth item of the toolbar: the glyph and the number of connected devices. Hidden when there is no adapter.
Item {
    id: button

    readonly property var c: Theme.imperial
    readonly property bool lit: area.containsMouse || Dropdown.current === "bt"
    readonly property string count: Bt.connectedCount > 0 ? String(Bt.connectedCount) : ""

    visible: Bt.available
    implicitWidth: 10 + glyph.implicitWidth + (count !== "" ? 5 + countText.implicitWidth : 0)
    implicitHeight: 22

    Behavior on implicitWidth {
        NumberAnimation { duration: 200 }
    }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: button.c.surfaceAlt
        opacity: button.lit ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 140 }
        }
    }

    Text {
        id: glyph

        x: 5
        anchors.verticalCenter: parent.verticalCenter
        text: ""      // Font Awesome bluetooth
        color: button.lit ? button.c.text : Bt.powered ? "#B5BAC3" : "#6D727B"
        renderType: Text.CurveRendering
        font.family: Theme.iconFont
        font.pixelSize: 14

        Behavior on color {
            ColorAnimation { duration: 140 }
        }
    }

    Text {
        id: countText

        x: 5 + glyph.implicitWidth + 5
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 1      // Orbitron's digits sit ~1px high at this size
        opacity: button.count !== "" ? 1 : 0
        text: button.count
        textFormat: Text.PlainText
        color: button.c.text
        renderType: Text.CurveRendering
        font.family: Theme.displayFont
        font.pixelSize: 10
        font.weight: Font.Medium
        font.letterSpacing: 0.4
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Dropdown.toggle("bt")
    }
}
