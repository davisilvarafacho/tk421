import QtQuick

import "../theme"

// A section label inside a docked panel's row column (comms log language): plain Geist in the faint grey, aligned with
// the rows' text column (x 40 inside the column), with an optional status on the right. No rule, no caps.
Item {
    id: section

    property string label: ""
    property string status: ""
    property color statusColor: Theme.imperial.faint

    implicitHeight: 30

    Text {
        x: 40
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        text: section.label
        textFormat: Text.PlainText
        color: Theme.imperial.faint
        renderType: Text.CurveRendering
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        visible: section.status !== ""
        text: section.status
        textFormat: Text.PlainText
        color: section.statusColor
        renderType: Text.CurveRendering
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }
}
