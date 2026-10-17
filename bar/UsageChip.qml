import QtQuick

import "../services"
import "../usage"
import "../theme"

// Toolbar item: spark, the 5 h session limit as a percentage, and a thin meter. Click opens the
// card (usage/UsageCard.qml). Prototype: prototypes/claude-usage/index.html
Item {
    id: chip

    readonly property var c: Theme.imperial
    readonly property bool off: ClaudeUsage.status !== "ok"
    readonly property bool lit: area.containsMouse || ClaudeUsage.open

    implicitWidth: 8 + 14 + 8 + 26 + 8 + 38 + 8
    implicitHeight: 22

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: chip.c.surfaceAlt
        opacity: chip.lit ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 140 } }
    }

    Image {
        x: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 14
        height: 14
        source: Qt.resolvedUrl("../assets/claude-spark.svg")
        sourceSize: Qt.size(28, 28)
        opacity: chip.off ? 0.5 : 1

        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    Text {
        x: 8 + 14 + 8
        width: 26
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 1     // Orbitron digits sit ~1px high at this size
        text: chip.off ? "--" : ClaudeUsage.sessionPercent + "%"
        color: chip.off ? chip.c.muted : chip.c.text
        font.family: Theme.displayFont
        font.pixelSize: 10
        font.weight: Font.Medium
        font.letterSpacing: 0.4
        renderType: Text.CurveRendering
    }

    Meter {
        x: 8 + 14 + 8 + 26 + 8
        width: 38
        anchors.verticalCenter: parent.verticalCenter
        value: chip.off ? 0 : ClaudeUsage.sessionPercent
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        onClicked: ClaudeUsage.open = !ClaudeUsage.open
    }
}
