import QtQuick

import "../components"
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

    Icon {
        anchors.centerIn: parent
        // eth and "no network, no Wi-Fi" (dimmed by the colour below) share lan; Wi-Fi present but down is wifi_off.
        name: Net.mode === "eth" ? "lan" : Net.mode === "wifi" ? "wifi" : Net.hasWifi ? "wifi_off" : "lan"
        size: Theme.iconSize.bar
        color: button.lit ? button.c.text : Net.connected ? "#B5BAC3" : "#6D727B"

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
