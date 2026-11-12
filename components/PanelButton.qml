import QtQuick

import "../theme"

// Text button of the docked panels (comms log language): Geist, sentence case, no outline. Quiet by default (muted text,
// the hover chip on hover); `primary` gives it the chip fill at rest; `danger` turns it red for destructive confirms.
Rectangle {
    id: button

    readonly property var c: Theme.imperial

    property string text: ""
    property bool primary: false
    property bool danger: false

    signal clicked()

    implicitWidth: label.implicitWidth + 20
    implicitHeight: 28
    radius: 8
    opacity: enabled ? 1 : 0.35

    color: danger ? (area.containsMouse ? c.danger : Qt.alpha(c.danger, 0.55))
        : primary ? (area.containsMouse ? "#24242C" : c.surfaceAlt)
        : (area.containsMouse ? c.surfaceAlt : "transparent")

    Behavior on color { ColorAnimation { duration: 120 } }

    Text {
        id: label

        anchors.centerIn: parent
        text: button.text
        textFormat: Text.PlainText
        color: button.primary || button.danger || area.containsMouse ? button.c.text : button.c.muted
        renderType: Text.CurveRendering
        font.family: Theme.fontFamily
        font.pixelSize: 12
        font.weight: button.primary || button.danger ? Font.Medium : Font.Normal
    }

    MouseArea {
        id: area

        anchors.fill: parent
        enabled: button.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
