import QtQuick

import "../theme"

// A key cap and what it does, in the launcher footer.
Row {
    id: kh

    property string key: ""
    property string label: ""

    spacing: 7

    Rectangle {
        width: Math.max(20, keyText.implicitWidth + 10)
        height: 20
        radius: 6
        color: Theme.imperial.surfaceAlt

        Text {
            id: keyText

            anchors.centerIn: parent
            text: kh.key
            color: Theme.imperial.muted
            font.family: Theme.fontFamily
            font.pixelSize: 11
            renderType: Text.CurveRendering
        }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: kh.label
        textFormat: Text.PlainText
        color: Theme.imperial.faint
        font.family: Theme.fontFamily
        font.pixelSize: 12
        renderType: Text.CurveRendering
    }
}
