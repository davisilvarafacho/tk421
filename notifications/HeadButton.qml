import QtQuick

import "../components"
import "../theme"

// A header button: optional icon plus a sentence-case label, the bar's hover chip. `lit` lights it.
Rectangle {
    id: hb

    property string label: ""
    property string icon: ""
    property bool lit: false

    signal clicked()

    width: hbRow.implicitWidth + 20
    height: 28
    radius: 8
    color: hbArea.containsMouse ? Theme.imperial.surfaceAlt : "transparent"

    Behavior on color { ColorAnimation { duration: 140 } }

    Row {
        id: hbRow

        anchors.centerIn: parent
        spacing: 6

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: hb.icon !== ""
            name: hb.icon !== "" ? hb.icon : "close"
            size: Theme.iconSize.panel
            color: hb.lit || hbArea.containsMouse ? Theme.imperial.text : Theme.imperial.muted
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: hb.label
            color: hb.lit || hbArea.containsMouse ? Theme.imperial.text : Theme.imperial.muted
            renderType: Text.CurveRendering
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }
    }

    MouseArea {
        id: hbArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: hb.enabled
        onClicked: hb.clicked()
    }
}
