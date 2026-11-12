import Quickshell
import QtQuick

import "../components"
import "../services"
import "../theme"

// Power menu. It hangs from the toolbar pill like the comms log (DropdownHost docks it: pill width, opaque ink, no top
// edge), in the same language: Orbitron only for the title, Geist in sentence case, quiet rows with a hover fill.
// Lock and Suspend run at once; Log out, Restart and Power off ask first (Power.confirming), and the question cancels
// itself after 5 s (Power.qml). A click elsewhere on the asking row or Esc cancels it too.
Item {
    id: panel

    readonly property var c: Theme.imperial

    implicitHeight: column.y + column.implicitHeight + 10

    // Header: title and the user it acts on.
    Item {
        id: header

        x: 22
        y: 16
        width: parent.width - 44
        height: 28

        Text {
            id: title

            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 1
            text: "POWER"
            color: panel.c.text
            renderType: Text.CurveRendering
            font.family: Theme.displayFont
            font.pixelSize: 11
            font.letterSpacing: 2.2
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: Quickshell.env("USER") ?? ""
            textFormat: Text.PlainText
            color: panel.c.faint
            renderType: Text.CurveRendering
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }
    }

    Column {
        id: column

        x: 10
        y: header.y + header.height + 10
        width: parent.width - 20

        Repeater {
            model: Power.actions

            delegate: Item {
                id: row

                required property var modelData

                readonly property bool asking: Power.confirming === modelData.id
                readonly property real yOff: modelData.gap ? 8 : 0
                property real progress: 1

                width: column.width
                height: 40 + yOff

                NumberAnimation {
                    target: row
                    property: "progress"
                    from: 1
                    to: 0
                    duration: 5000
                    running: row.asking
                }

                Rectangle {
                    id: chip

                    y: row.yOff
                    width: parent.width
                    height: 40
                    radius: 14
                    color: row.asking ? Qt.alpha(panel.c.danger, 0.14)
                        : area.containsMouse ? panel.c.rowHover : "transparent"

                    Behavior on color { ColorAnimation { duration: 120 } }

                    // The question drains along the bottom of the row over its 5 s.
                    Rectangle {
                        visible: row.asking
                        x: 14
                        y: parent.height - 1
                        width: (parent.width - 28) * row.progress
                        height: 1
                        color: panel.c.danger
                    }
                }

                MouseArea {
                    id: area

                    anchors.fill: chip
                    hoverEnabled: true
                    cursorShape: row.asking ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: {
                        if (row.asking)
                            Power.cancel()
                        else if (row.modelData.confirm)
                            Power.ask(row.modelData.id)
                        else
                            Power.run(row.modelData.id)
                    }
                }

                Icon {
                    x: 12
                    y: row.yOff + (40 - height) / 2
                    name: row.modelData.glyph
                    size: Theme.iconSize.panel
                    color: row.asking ? panel.c.dangerText : area.containsMouse ? panel.c.text : panel.c.muted

                    Behavior on color { ColorAnimation { duration: 140 } }
                }

                Text {
                    x: 12 + 16 + 12
                    y: row.yOff + (40 - height) / 2
                    text: row.asking ? row.modelData.label + "?" : row.modelData.label
                    textFormat: Text.PlainText
                    color: row.asking ? panel.c.dangerText : panel.c.text
                    renderType: Text.CurveRendering
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                }

                Text {
                    visible: !row.asking && row.modelData.hint !== ""
                    x: row.width - 14 - implicitWidth
                    y: row.yOff + (40 - height) / 2
                    text: row.modelData.hint
                    textFormat: Text.PlainText
                    color: panel.c.faint
                    renderType: Text.CurveRendering
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }

                // Confirm: the one solid control in the panel, only while asking.
                Rectangle {
                    id: confirm

                    visible: row.asking
                    x: row.width - 8 - width
                    y: row.yOff + (40 - height) / 2
                    width: confirmText.implicitWidth + 20
                    height: 26
                    radius: 8
                    color: confirmArea.containsMouse ? panel.c.danger : Qt.alpha(panel.c.danger, 0.55)

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        id: confirmText

                        anchors.centerIn: parent
                        text: "Confirm"
                        color: panel.c.text
                        renderType: Text.CurveRendering
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: confirmArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Power.confirm()
                    }
                }
            }
        }
    }
}
