import QtQuick

import "../services"
import "../theme"

// Network item of the toolbar: Ethernet, Wi-Fi or "no connection" glyph. Opens the network dropdown.
Item {
    id: button

    readonly property var c: Theme.imperial
    readonly property bool lit: area.containsMouse || Dropdown.current === "net"

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
        // Material Design glyphs from the Symbols Nerd Font: ethernet, ethernet-off, wifi, wifi-off.
        text: Net.mode === "eth" ? "󰈀" : Net.mode === "wifi" ? "󰖩" : Net.hasWifi ? "󰖪" : "󰈁"
        color: button.lit ? button.c.text : Net.connected ? "#B5BAC3" : "#6D727B"
        renderType: Text.CurveRendering
        font.family: Theme.iconFont
        font.pixelSize: 15

        Behavior on color {
            ColorAnimation { duration: 140 }
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Dropdown.toggle("net")
    }
}
