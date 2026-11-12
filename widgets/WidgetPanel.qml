import QtQuick

import "../theme"

// The quiet ink panel every desktop widget sits in: the shell's 20 px radius, opaque black, faint hairline.
// A small Orbitron label top-left, an optional Geist note top-right, content below (a Column).
Rectangle {
    id: panel

    property string label: ""
    property string aside: ""
    default property alias content: body.data

    implicitHeight: body.y + body.implicitHeight + 20
    radius: 20
    color: Theme.imperial.ink
    border.width: 1
    border.color: Theme.imperial.hairline

    Text {
        x: 20
        y: 19
        text: panel.label
        color: Theme.imperial.muted
        renderType: Text.CurveRendering
        font.family: Theme.displayFont
        font.pixelSize: 10
        font.letterSpacing: 2.2
        font.capitalization: Font.AllUppercase
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 20
        y: 18
        text: panel.aside
        textFormat: Text.PlainText
        color: Theme.imperial.faint
        renderType: Text.CurveRendering
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }

    Column {
        id: body

        x: 20
        y: 43
        width: panel.width - 40
    }
}
