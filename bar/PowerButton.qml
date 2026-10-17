import QtQuick

import "../services"
import "../theme"

// Power button of the toolbar: opens the power dropdown.
Item {
    id: button

    readonly property var c: Theme.imperial
    readonly property bool lit: area.containsMouse || Dropdown.current === "power"

    implicitWidth: 24
    implicitHeight: 22

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
        anchors.centerIn: parent
        text: ""      // Font Awesome power-off
        color: button.lit ? button.c.text : "#B5BAC3"
        renderType: Text.CurveRendering
        font.family: Theme.iconFont
        font.pixelSize: 14

        Behavior on color {
            ColorAnimation { duration: 140 }
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Dropdown.toggle("power")
    }
}
