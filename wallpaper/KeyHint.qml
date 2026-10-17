import QtQuick

import "../theme"

// Key caps plus what they do, for the sill.
Row {
    id: hint

    property var caps: []
    property string label: ""
    property real u: 1

    spacing: 8 * u

    Repeater {
        model: hint.caps

        Rectangle {
            id: capBox

            required property string modelData

            width: Math.max(22 * hint.u, cap.implicitWidth + 10 * hint.u)
            height: 22 * hint.u
            color: "transparent"
            border.width: 1
            border.color: Theme.imperial.border

            Text {
                id: cap

                anchors.centerIn: parent
                text: capBox.modelData
                color: Theme.imperial.text
                textFormat: Text.PlainText
                font.family: Theme.fontFamily
                font.pixelSize: 11 * hint.u
                renderType: Text.CurveRendering
            }
        }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: hint.label
        color: Theme.imperial.muted
        font.family: Theme.displayFont
        font.pixelSize: 11 * hint.u
        font.weight: Font.Medium
        font.letterSpacing: 1.8 * hint.u
        renderType: Text.CurveRendering
    }
}
