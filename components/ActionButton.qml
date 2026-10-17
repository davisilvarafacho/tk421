import QtQuick

import "../theme"

// Quiet text button with an Orbitron label. `primary` adds a thin accent outline; `danger` makes that outline red.
Rectangle {
    id: button

    readonly property var c: Theme.imperial

    property string text: ""
    property bool primary: false
    property bool danger: false

    signal clicked()

    implicitWidth: label.implicitWidth + 20
    implicitHeight: 26
    radius: 8

    color: !area.containsMouse ? "transparent"
        : primary ? (danger ? Qt.rgba(0.631, 0.302, 0.333, 0.18) : c.accentDim)
        : Qt.rgba(0.91, 0.9, 0.89, 0.06)
    border.width: 1
    border.color: primary ? (danger ? c.danger : c.accent) : "transparent"

    Behavior on color {
        ColorAnimation { duration: 140 }
    }

    Text {
        id: label

        anchors.centerIn: parent
        anchors.verticalCenterOffset: 1      // Orbitron's digits sit ~1px high at this size
        text: button.text
        textFormat: Text.PlainText
        color: button.primary ? (button.danger ? button.c.dangerText : button.c.text)
            : (area.containsMouse ? button.c.text : button.c.muted)
        renderType: Text.CurveRendering
        font.family: Theme.displayFont
        font.pixelSize: 9
        font.letterSpacing: 1.6
        font.capitalization: Font.AllUppercase

        Behavior on color {
            ColorAnimation { duration: 140 }
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
