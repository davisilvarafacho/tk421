import Quickshell
import QtQuick

import "../components"
import "../services"
import "../theme"

// Power menu. Lock and Suspend run at once; Log out, Restart and Power off ask first (Power.confirming), and the
// question cancels itself after 5 s (Power.qml). Prototype: prototypes/toolbar/index.html.
Item {
    id: panel

    readonly property var c: Theme.imperial

    implicitHeight: 48 + column.implicitHeight + 8

    Text {
        id: title

        x: 16
        y: 2 + (46 - height) / 2
        text: "Power"
        color: panel.c.text
        renderType: Text.CurveRendering
        font.family: Theme.displayFont
        font.pixelSize: 11
        font.letterSpacing: 2.2
        font.capitalization: Font.AllUppercase
    }

    Text {
        x: title.x + title.implicitWidth + 8
        y: title.y
        height: title.height
        verticalAlignment: Text.AlignVCenter
        text: Quickshell.env("USER") ?? ""
        textFormat: Text.PlainText
        color: panel.c.muted
        renderType: Text.CurveRendering
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }

    Column {
        id: column

        y: 48
        width: parent.width

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
                    y: row.yOff
                    width: parent.width
                    height: 40
                    color: Qt.rgba(0.91, 0.9, 0.89, 0.035)
                    opacity: area.containsMouse && !row.asking ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: 120 }
                    }
                }

                MouseArea {
                    id: area

                    y: row.yOff
                    width: parent.width
                    height: 40
                    enabled: !row.asking
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: row.modelData.confirm ? Power.ask(row.modelData.id) : Power.run(row.modelData.id)
                }

                Text {
                    x: 16
                    y: row.yOff + (40 - height) / 2
                    text: row.modelData.glyph
                    color: row.asking ? panel.c.dangerText : area.containsMouse ? panel.c.text : panel.c.muted
                    renderType: Text.CurveRendering
                    font.family: Theme.iconFont
                    font.pixelSize: 15

                    Behavior on color {
                        ColorAnimation { duration: 140 }
                    }
                }

                Text {
                    x: 46
                    y: row.yOff + (40 - height) / 2
                    text: row.asking ? row.modelData.label + "?" : row.modelData.label
                    textFormat: Text.PlainText
                    color: row.asking ? panel.c.dangerText : panel.c.text
                    renderType: Text.CurveRendering
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }

                Text {
                    visible: !row.asking && row.modelData.hint !== ""
                    x: row.width - 16 - implicitWidth
                    y: row.yOff + (40 - height) / 2 + 1
                    text: row.modelData.hint
                    textFormat: Text.PlainText
                    color: panel.c.muted
                    renderType: Text.CurveRendering
                    font.family: Theme.displayFont
                    font.pixelSize: 9
                    font.letterSpacing: 1.4
                    font.capitalization: Font.AllUppercase
                }

                // A click anywhere on the asking row cancels it (the Confirm button sits above this). Esc and the 5 s do too.
                MouseArea {
                    y: row.yOff
                    width: parent.width
                    height: 40
                    enabled: row.asking
                    cursorShape: Qt.ArrowCursor
                    onClicked: Power.cancel()
                }

                // The question: confirm, and a hairline that drains over the 5 s.
                Row {
                    visible: row.asking
                    x: row.width - 16 - width
                    y: row.yOff + (40 - height) / 2
                    spacing: 4

                    ActionButton {
                        text: "Confirm"
                        primary: true
                        danger: true
                        implicitHeight: 24
                        onClicked: Power.confirm()
                    }
                }

                Rectangle {
                    visible: row.asking
                    x: 16
                    y: row.yOff + 39
                    width: (row.width - 32) * row.progress
                    height: 1
                    color: panel.c.danger
                    opacity: 0.8
                }
            }
        }
    }
}
