import QtQuick

import "../components"
import "../theme"

// One option of the island's tab switcher: icon and label, with an optional "something is playing" dot.
Item {
    id: seg

    property string glyph      // an icon name from theme/icons.js
    property string label
    property bool active: false
    property bool live: false
    signal clicked()

    readonly property color ink: active || segArea.containsMouse ? Theme.imperial.text : Theme.imperial.muted

    width: segRow.implicitWidth + 28
    height: 28

    Row {
        id: segRow

        anchors.centerIn: parent
        spacing: 7

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: seg.glyph
            size: Theme.iconSize.bar
            color: seg.ink

            Behavior on color { ColorAnimation { duration: 140 } }
        }

        Text {
            renderType: Text.CurveRendering
            anchors.verticalCenter: parent.verticalCenter
            text: seg.label
            color: seg.ink
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold

            Behavior on color { ColorAnimation { duration: 140 } }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: seg.live ? 5 : 0
            height: 5
            radius: 2.5
            color: "#8AA4D6"
            opacity: seg.live ? 1 : 0

            Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
    }

    MouseArea {
        id: segArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: seg.clicked()
    }
}
