import QtQuick

import "../components"
import "../services"
import "../theme"

// Volume of the default output: the speaker glyph mutes (or unmutes), the percentage opens the sound panel, the wheel changes
// the volume. The island shows its own volume HUD for every change (services/Audio.qml).
Item {
    id: item

    readonly property var c: Theme.imperial
    readonly property bool dim: Sound.outMuted || Sound.outVolume <= 0
    readonly property bool panelOpen: Dropdown.current === "sound"

    implicitWidth: row.implicitWidth
    implicitHeight: 22

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => Sound.step("out", event.angleDelta.y > 0 ? 5 : -5)
    }

    Row {
        id: row

        // Mute button.
        Item {
            width: 24
            height: 22

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: item.c.surfaceAlt
                opacity: muteArea.containsMouse ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 140 }
                }
            }

            Icon {
                anchors.centerIn: parent
                name: Sound.outGlyph
                size: Theme.iconSize.bar
                color: muteArea.containsMouse ? item.c.text : item.dim ? "#6D727B" : "#B5BAC3"

                Behavior on color {
                    ColorAnimation { duration: 140 }
                }
            }

            MouseArea {
                id: muteArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Sound.toggleMute("out")
            }
        }

        // Level: opens the sound panel.
        Item {
            width: Math.max(34, level.implicitWidth + 10)
            height: 22

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: item.c.surfaceAlt
                opacity: levelArea.containsMouse || item.panelOpen ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 140 }
                }
            }

            Text {
                id: level

                anchors.centerIn: parent
                anchors.verticalCenterOffset: 1      // Orbitron's digits sit ~1px high at this size
                text: Sound.outText
                textFormat: Text.PlainText
                color: item.dim ? "#6D727B" : item.c.text
                renderType: Text.CurveRendering
                font.family: Theme.displayFont
                font.pixelSize: 10
                font.weight: Font.Medium
                font.letterSpacing: 0.4
            }

            MouseArea {
                id: levelArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Dropdown.toggle("sound")
            }
        }
    }
}
