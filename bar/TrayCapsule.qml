import Quickshell
import QtQuick

import "../components"
import "../services"
import "../theme"

// Capsule with the icons of the apps that keep one in the bar, left of the toolbar capsule. Hidden when there are none.
// Every app is shown (services/Tray.qml); the chevron and its "tray" dropdown only appear if overflowItems is ever non-empty.
BarPill {
    id: tray

    readonly property var c: Theme.imperial

    visible: Tray.any
    implicitWidth: row.implicitWidth + 22     // the icon cells add ~5 px, so the glyphs sit ~16 px in, like the left text

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: ScriptModel {
                values: Tray.visibleItems
            }

            delegate: TrayIcon {}
        }

        // Chevron: the apps that do not fit, and the passive ones.
        Item {
            visible: Tray.overflowItems.length > 0
            width: 24
            height: 22

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: tray.c.surfaceAlt
                opacity: chevronArea.containsMouse || Dropdown.current === "tray" ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 140 }
                }
            }

            Icon {
                anchors.centerIn: parent
                name: "expand_more"
                size: Theme.iconSize.panel
                color: chevronArea.containsMouse || Dropdown.current === "tray" ? tray.c.text : "#B5BAC3"
            }

            Rectangle {
                visible: Tray.overflowAttention
                x: parent.width - width
                y: 0
                width: 10          // 6 px dot plus its 2 px ring
                height: 10
                radius: 5
                color: tray.c.accent
                border.width: 2
                border.color: tray.c.ink       // ring cut out of the pill's black
            }

            MouseArea {
                id: chevronArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Dropdown.toggle("tray")
            }
        }
    }
}
