import Quickshell
import QtQuick

import "../components"
import "../services"
import "../theme"
import "soundlogic.js" as Logic

// Quick sound panel: volume of the default output and input, and the devices to switch the default to.
// (The full sound manager, with enabling and disabling devices, is a later step.) State: services/Sound.qml.
// Segmented power-cell gauge, framed icons and status words (prototype: prototypes/sound-flyout/index.html).
Item {
    id: panel

    readonly property var c: Theme.imperial
    readonly property color accentText: "#8EA6D4"      // the accent tinted for small text (~7:1 on the surface)
    readonly property color cellOff: "#26252A"
    readonly property color cellMuted: "#4A494E"
    readonly property int cells: 22

    readonly property real bodyHeight: Math.min(column.implicitHeight, 440)

    implicitHeight: 48 + bodyHeight + 8

    Text {
        x: 16
        y: 2 + (46 - height) / 2
        text: "Sound"
        color: panel.c.text
        renderType: Text.CurveRendering
        font.family: Theme.displayFont
        font.pixelSize: 11
        font.letterSpacing: 2.2
        font.capitalization: Font.AllUppercase
    }

    // Section label, a hairline that runs to the status word on the right edge.
    component Section: Item {
        id: section

        property string label: ""
        property string status: ""
        property color statusColor: panel.c.muted

        width: column.width
        height: 28

        Text {
            id: sectionLabel

            x: 16
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: section.height > 30 ? 9 : 3
            text: section.label
            color: panel.c.muted
            renderType: Text.CurveRendering
            font.family: Theme.displayFont
            font.pixelSize: 9
            font.letterSpacing: 1.8
            font.capitalization: Font.AllUppercase
        }

        Text {
            id: sectionStatus

            x: parent.width - 16 - implicitWidth
            anchors.verticalCenter: sectionLabel.verticalCenter
            text: section.status
            color: section.statusColor
            renderType: Text.CurveRendering
            font.family: Theme.displayFont
            font.pixelSize: 9
            font.letterSpacing: 1.5
            font.capitalization: Font.AllUppercase
        }

        Rectangle {
            x: 16 + sectionLabel.implicitWidth + 10
            anchors.verticalCenter: sectionLabel.verticalCenter
            width: sectionStatus.x - 10 - x
            height: 1
            color: panel.c.border
            opacity: 0.7
        }
    }

    // Framed mute button, a segmented gauge you can drag (hover previews the level), and the readout.
    component VolumeRow: Item {
        id: vr

        property string kind: "out"
        property real value: 0
        property bool muted: false
        property string glyph: ""

        width: column.width
        height: 40

        Rectangle {
            id: muteButton

            x: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            height: 26
            radius: 3
            color: "transparent"
            border.width: 1
            border.color: vr.muted ? panel.c.danger : (muteArea.containsMouse ? panel.c.muted : panel.c.border)

            Icon {
                anchors.centerIn: parent
                name: vr.glyph
                size: Theme.iconSize.panel
                color: vr.muted ? panel.c.dangerText : (muteArea.containsMouse ? panel.c.text : panel.c.muted)
                gapColor: panel.c.surface
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
            id: gauge

            readonly property int lit: Math.round(Math.max(0, Math.min(1, vr.value)) * panel.cells)
            readonly property int ghost: gaugeArea.containsMouse && !gaugeArea.pressed
                ? Math.round(Math.max(0, Math.min(1, gaugeArea.mouseX / width)) * panel.cells) : 0
            readonly property real step: width / panel.cells

            x: 16 + 26 + 12
            width: parent.width - x - 12 - 46 - 16
            height: parent.height

            Repeater {
                model: panel.cells

                delegate: Rectangle {
                    id: cell

                    required property int index
                    readonly property bool on: index < gauge.lit
                    readonly property bool lead: on && index === gauge.lit - 1

                    // Pixel-snapped so every cell stays crisp.
                    x: Math.round(index * gauge.step)
                    width: Math.round((index + 1) * gauge.step) - x - 2
                    anchors.verticalCenter: parent.verticalCenter
                    height: 12
                    radius: 1
                    color: on ? (vr.muted ? panel.cellMuted : (lead ? panel.c.accent : panel.c.text))
                        : (index < gauge.ghost ? Qt.rgba(0.91, 0.9, 0.89, 0.28) : panel.cellOff)
                }
            }

            MouseArea {
                id: gaugeArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => Sound.setVolume(vr.kind, mouse.x / width)
                onPositionChanged: mouse => {
                    if (pressed)
                        Sound.setVolume(vr.kind, mouse.x / width)
                }
            }
        }

        Text {
            x: parent.width - 16 - implicitWidth
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 1
            textFormat: Text.RichText
            text: vr.muted ? "MUTE"
                : Math.round(Math.max(0, Math.min(1, vr.value)) * 100)
                    + "<span style=\"font-size:9px; color:" + panel.c.muted + "\">%</span>"
            color: vr.muted ? panel.c.dangerText : panel.c.text
            renderType: Text.CurveRendering
            font.family: Theme.displayFont
            font.pixelSize: vr.muted ? 11 : 13
            font.letterSpacing: vr.muted ? 1.5 : 0
            font.weight: Font.Medium
        }
    }

    // Framed icon, name, and an ACTIVE word on the current device.
    component DeviceRow: Item {
        id: dr

        required property var modelData
        property string kind: "out"

        width: column.width
        height: 48

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.91, 0.9, 0.89, 0.035)
            opacity: area.containsMouse ? 1 : 0

            Behavior on opacity {
                NumberAnimation { duration: 120 }
            }
        }

        Rectangle {
            id: frame

            x: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 30
            height: 30
            radius: 3
            color: dr.modelData.current ? panel.c.accentDim : "transparent"
            border.width: 1
            border.color: dr.modelData.current ? panel.c.accent : (area.containsMouse ? panel.c.muted : panel.c.border)

            Icon {
                anchors.centerIn: parent
                name: dr.modelData.glyph
                size: Theme.iconSize.panel
                color: dr.modelData.current || area.containsMouse ? panel.c.text : panel.c.muted
            }
        }

        Column {
            x: 16 + 30 + 12
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - 16 - (dr.modelData.current ? activeTag.implicitWidth + 12 : 0)

            Text {
                width: parent.width
                text: dr.modelData.name
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: panel.c.text
                renderType: Text.CurveRendering
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.Medium
            }

            Text {
                width: parent.width
                visible: dr.modelData.sub !== ""
                text: dr.modelData.sub
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: panel.c.muted
                renderType: Text.CurveRendering
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
        }

        Text {
            id: activeTag

            visible: dr.modelData.current
            x: parent.width - 16 - implicitWidth
            anchors.verticalCenter: parent.verticalCenter
            text: "Active"
            color: panel.accentText
            renderType: Text.CurveRendering
            font.family: Theme.displayFont
            font.pixelSize: 9
            font.letterSpacing: 1.6
            font.capitalization: Font.AllUppercase
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
        y: 48
        width: parent.width
        height: panel.bodyHeight
        contentHeight: column.implicitHeight
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: column

            width: parent.width

            Section {
                label: "Output"
                status: Sound.outMuted ? "Muted"
                    : Sound.outputs.length + (Sound.outputs.length === 1 ? " device" : " devices")
                statusColor: Sound.outMuted ? panel.c.dangerText : panel.c.muted
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

            Section {
                height: 40
                label: "Input"
                status: Sound.micState === "on" ? "Live" : Sound.micState === "muted" ? "Muted" : "No signal"
                statusColor: Sound.micState === "on" ? panel.accentText
                    : Sound.micState === "muted" ? panel.c.dangerText : panel.c.muted
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
                x: 16
                topPadding: 2
                bottomPadding: 10
                text: "No input device recognised."
                color: panel.c.muted
                opacity: 0.75
                renderType: Text.CurveRendering
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }

            Item { width: 1; height: 6 }
        }
    }
}
