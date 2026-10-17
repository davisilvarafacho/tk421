import Quickshell
import QtQuick

import "../services"
import "../theme"

// Capsule with the icons of the apps that keep one in the bar, left of the toolbar capsule. Hidden when there are none.
// More than three active apps, and every passive one, sit behind the chevron (dropdown "tray").
Rectangle {
    id: tray

    readonly property var c: Theme.imperial

    visible: Tray.any
    implicitWidth: row.implicitWidth + 12
    implicitHeight: 28
    radius: 14

    color: c.surface
    border.width: 1
    border.color: c.border

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 2

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

            Text {
                anchors.centerIn: parent
                text: ""      // Font Awesome chevron-down
                color: chevronArea.containsMouse || Dropdown.current === "tray" ? tray.c.text : "#B5BAC3"
                renderType: Text.CurveRendering
                font.family: Theme.iconFont
                font.pixelSize: 10
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
                border.color: tray.c.surface
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
