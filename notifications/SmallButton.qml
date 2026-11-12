import QtQuick

import "../components"
import "../theme"

// A 22 px text or icon button with the bar's hover chip.
Rectangle {
    id: btn

    property string label: ""
    property string icon: ""

    signal clicked()

    width: icon !== "" ? 22 : labelText.implicitWidth + 16
    height: 22
    radius: 7
    color: area.containsMouse ? Theme.imperial.surfaceAlt : "transparent"

    Text {
        id: labelText

        anchors.centerIn: parent
        visible: btn.icon === ""
        text: btn.label
        textFormat: Text.PlainText
        color: area.containsMouse ? Theme.imperial.text : Theme.imperial.muted
        renderType: Text.CurveRendering
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }

    Icon {
        anchors.centerIn: parent
        visible: btn.icon !== ""
        name: btn.icon !== "" ? btn.icon : "close"
        size: Theme.iconSize.panel
        color: area.containsMouse ? Theme.imperial.text : Theme.imperial.muted
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
