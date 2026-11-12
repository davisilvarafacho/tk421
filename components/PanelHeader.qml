import QtQuick

import "../theme"

// Header of a panel that hangs from the toolbar pill (comms log language): the Orbitron title on the left, an
// optional plain detail on the right. Sits at x 22, y 16, 28 px high; place it with those values.
Item {
    id: header

    property string title: ""
    property string detail: ""
    property color detailColor: Theme.imperial.faint

    height: 28

    Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 1
        text: header.title.toUpperCase()
        color: Theme.imperial.text
        renderType: Text.CurveRendering
        font.family: Theme.displayFont
        font.pixelSize: 11
        font.letterSpacing: 2.2
    }

    Text {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: header.detail !== ""
        text: header.detail
        textFormat: Text.PlainText
        color: header.detailColor
        renderType: Text.CurveRendering
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }
}
