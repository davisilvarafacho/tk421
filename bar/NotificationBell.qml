import QtQuick

import "../notifications/logic.js" as Logic
import "../services"
import "../theme"

// Bell of the toolbar: glyph, unread count, and a ring that pulses when something arrives.
Item {
    id: bell

    readonly property var c: Theme.imperial
    readonly property string badge: Notifications.centerOpen || Notifications.settling
        ? "" : Logic.badgeText(Notifications.unreadCount)
    readonly property bool lit: area.containsMouse || Notifications.centerOpen

    implicitWidth: 10 + glyph.implicitWidth + (badge !== "" ? 5 + count.implicitWidth : 0)
    implicitHeight: 22

    Behavior on implicitWidth {
        NumberAnimation { duration: 200 }
    }

    onBadgeChanged: {
        if (badge !== "")
            roll.restart()
    }

    Connections {
        target: Notifications

        function onPinged() {
            ping.restart()
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: bell.c.surfaceAlt
        opacity: bell.lit ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 140 }
        }
    }

    // One accent ring when a notification arrives.
    Rectangle {
        id: ring

        anchors.fill: parent
        anchors.margins: -1
        radius: 9
        color: "transparent"
        border.width: 1
        border.color: bell.c.accent
        opacity: 0
    }

    ParallelAnimation {
        id: ping

        NumberAnimation { target: ring; property: "opacity"; from: 0.9; to: 0; duration: 900 }
        NumberAnimation {
            target: ring
            property: "scale"
            from: 1
            to: 1.6
            duration: 900
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
        }
    }

    Text {
        id: glyph

        x: 5
        anchors.verticalCenter: parent.verticalCenter
        // Font Awesome bell / bell-slash from the Symbols Nerd Font.
        text: Notifications.dnd ? "" : ""
        color: bell.lit ? bell.c.text : "#B5BAC3"
        renderType: Text.CurveRendering
        font.family: Theme.iconFont
        font.pixelSize: 14

        Behavior on color {
            ColorAnimation { duration: 140 }
        }
    }

    Text {
        id: count

        property real rise: 0
        property real pop: 1

        x: 5 + glyph.implicitWidth + 5
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 1 + rise      // Orbitron's digits sit ~1px high at this size
        opacity: (bell.badge !== "" ? 1 : 0) * pop
        text: bell.badge
        textFormat: Text.PlainText
        color: Notifications.dnd ? bell.c.muted : bell.c.text
        renderType: Text.CurveRendering
        font.family: Theme.displayFont
        font.pixelSize: 10
        font.weight: Font.Medium
        font.letterSpacing: 0.4
    }

    // The new digit rises in.
    ParallelAnimation {
        id: roll

        NumberAnimation {
            target: count
            property: "rise"
            from: 6
            to: 0
            duration: 280
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
        }
        NumberAnimation { target: count; property: "pop"; from: 0; to: 1; duration: 280 }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Notifications.toggleCenter()
    }
}
