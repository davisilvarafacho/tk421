import Quickshell
import QtQuick

import "../components"
import "../services"
import "../theme"
import "soundlogic.js" as Logic

// Quick sound panel: volume of the default output and input, and the devices to switch the default to.
// (The full sound manager, with enabling and disabling devices, is a later step.) State: services/Sound.qml.
// It hangs from the toolbar pill in the comms log language: Orbitron only for the title, Geist sentence case, a slim
// slider per direction, quiet device rows with a hover fill and a check on the device in use.
Item {
    id: panel

    readonly property var c: Theme.imperial

    readonly property real bodyHeight: Math.min(column.implicitHeight, 460)

    implicitHeight: body.y + bodyHeight + 10

    PanelHeader {
        x: 22
        y: 16
        width: parent.width - 44
        title: "Sound"
    }

    // Mute button, a slider you can drag (hover previews the level) and the readout.
    component VolumeRow: Item {
        id: vr

        property string kind: "out"
        property real value: 0
        property bool muted: false
        property string glyph: ""

        readonly property real level: Math.max(0, Math.min(1, value))

        width: column.width
        height: 40

        Rectangle {
            x: 4
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            radius: 9
            color: muteArea.containsMouse ? Theme.imperial.surfaceAlt : "transparent"

            Behavior on color { ColorAnimation { duration: 120 } }

            Icon {
                anchors.centerIn: parent
                name: vr.glyph
                size: Theme.iconSize.panel
                color: muteArea.containsMouse ? Theme.imperial.text : Theme.imperial.muted
            }

            MouseArea {
                id: muteArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Sound.toggleMute(vr.kind)
            }
        }

        Item {
            id: slider

            readonly property real ghost: sliderArea.containsMouse && !sliderArea.pressed
                ? Math.max(0, Math.min(1, sliderArea.mouseX / width)) : 0

            x: 40
            width: parent.width - x - 12 - 52
            height: parent.height

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 4
                radius: 2
                color: Theme.imperial.surfaceAlt
            }

            // Hover preview, under the fill.
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(parent.width * slider.ghost)
                height: 4
                radius: 2
                color: Qt.rgba(0.91, 0.9, 0.89, 0.22)
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(parent.width * vr.level)
                height: 4
                radius: 2
                color: vr.muted ? Theme.imperial.faint : Theme.imperial.text
            }

            MouseArea {
                id: sliderArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => Sound.setVolume(vr.kind, mouse.x / width)
                onPositionChanged: mouse => {
                    if (pressed)
                        Sound.setVolume(vr.kind, mouse.x / width)
                }
                // WheelHandler never fires in a Quickshell window here: the wheel is read by MouseArea (5% a notch).
                onWheel: wheel => Sound.setVolume(vr.kind, Math.max(0, Math.min(1, vr.level + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
            }
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: vr.muted ? "Muted" : Math.round(vr.level * 100) + "%"
            color: vr.muted ? Theme.imperial.dangerText : Theme.imperial.text
            renderType: Text.CurveRendering
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.features: { "tnum": 1 }
        }
    }

    // Icon, name and detail; the device in use is in full white with a check.
    component DeviceRow: Item {
        id: dr

        required property var modelData
        property string kind: "out"

        width: column.width
        height: 44

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: area.containsMouse ? Theme.imperial.rowHover : "transparent"

            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Icon {
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            name: dr.modelData.glyph
            size: Theme.iconSize.panel
            color: dr.modelData.current || area.containsMouse ? Theme.imperial.text : Theme.imperial.muted
        }

        Column {
            x: 40
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - 12 - (dr.modelData.current ? 16 + 12 : 0)

            Text {
                width: parent.width
                text: dr.modelData.name
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: dr.modelData.current || area.containsMouse ? Theme.imperial.text : Theme.imperial.muted
                renderType: Text.CurveRendering
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: dr.modelData.current ? Font.Medium : Font.Normal
            }

            Text {
                width: parent.width
                visible: dr.modelData.sub !== ""
                text: dr.modelData.sub
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Theme.imperial.faint
                renderType: Text.CurveRendering
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
        }

        Icon {
            visible: dr.modelData.current
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            name: "check"
            size: Theme.iconSize.panel
            color: Theme.imperial.text
        }

        MouseArea {
            id: area

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Sound.use(dr.kind, dr.modelData.id)
        }
    }

    Flickable {
        id: body

        x: 10
        y: 16 + 28 + 2
        width: parent.width - 20
        height: panel.bodyHeight
        contentHeight: column.implicitHeight
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: column

            width: parent.width

            PanelSection {
                width: column.width
                label: "Output"
                status: Sound.outputs.length + (Sound.outputs.length === 1 ? " device" : " devices")
            }

            VolumeRow {
                kind: "out"
                value: Sound.outVolume
                muted: Sound.outMuted
                glyph: Sound.outGlyph
            }

            Repeater {
                model: Sound.outputs

                delegate: DeviceRow { kind: "out" }
            }

            PanelSection {
                width: column.width
                implicitHeight: 38
                label: "Input"
                status: Sound.micState === "on" ? "Live" : Sound.micState === "muted" ? "" : "None"
                statusColor: Sound.micState === "on" ? panel.c.muted : panel.c.faint
            }

            VolumeRow {
                visible: Sound.hasSource
                height: visible ? 40 : 0
                kind: "in"
                value: Sound.inVolume
                muted: Sound.inMuted
                glyph: Logic.micGlyph(Sound.micState)
            }

            Repeater {
                model: Sound.inputs

                delegate: DeviceRow { kind: "in" }
            }

            Text {
                visible: Sound.inputs.length === 0
                x: 40
                topPadding: 4
                bottomPadding: 8
                text: "No input device."
                color: panel.c.muted
                renderType: Text.CurveRendering
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
        }
    }
}
