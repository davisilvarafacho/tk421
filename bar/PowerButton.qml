import QtQuick

import "../components"
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

    Icon {
        anchors.centerIn: parent
        name: "power_settings_new"
        size: Theme.iconSize.bar
        color: button.lit ? button.c.text : "#B5BAC3"

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
