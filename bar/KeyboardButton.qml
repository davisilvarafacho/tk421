import QtQuick

import "../components"
import "../services"
import "../theme"

// Keyboard button of the toolbar, beside the Claude usage chip: opens the keyboard dropdown (dropdown/KeyboardPanel.qml).
// Dimmed while the keyboard is not answering. State: services/Keyboard.qml.
Item {
    id: item

    readonly property var c: Theme.imperial
    readonly property bool panelOpen: Dropdown.current === "keyboard"

    implicitWidth: 24
    implicitHeight: 22

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: item.c.surfaceAlt
        opacity: area.containsMouse || item.panelOpen ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 140 }
        }
    }

    Icon {
        anchors.centerIn: parent
        name: "keyboard"
        size: Theme.iconSize.bar
        color: area.containsMouse || item.panelOpen ? item.c.text : (Keyboard.online ? "#B5BAC3" : "#6D727B")

        Behavior on color {
            ColorAnimation { duration: 140 }
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Dropdown.toggle("keyboard")
    }
}
