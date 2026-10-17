
import QtQuick

import "../theme"

Row {
    id: indicator

    property string label: ""
    property real value: 0

    spacing: 5
    height: 22

    Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 1      // Orbitron's digits sit ~1px high at this size
        text: indicator.label
        color: "#B5BAC3"
        renderType: Text.CurveRendering
        font.family: Theme.displayFont
        font.pixelSize: 10
        font.weight: Font.Medium
        font.letterSpacing: 0.4
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 1      // Orbitron's digits sit ~1px high at this size
        text: Math.round(indicator.value) + "%"
        color: "#E8E6E3"
        renderType: Text.CurveRendering
        font.family: Theme.displayFont
        font.pixelSize: 10
        font.weight: Font.Medium
        font.letterSpacing: 0.4
    }
}
