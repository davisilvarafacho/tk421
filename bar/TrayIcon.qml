import Quickshell
import Quickshell.Services.SystemTray
import QtQuick

import "../services"
import "../theme"

// One tray app in the capsule. Left-click activates it, middle-click is its secondary action, right-click opens its
// own menu in the dropdown, the wheel is forwarded to the app (volume in a player, for example).
Item {
    id: icon

    required property var modelData

    readonly property var c: Theme.imperial
    readonly property var item: modelData
    readonly property bool attention: item?.status === Status.NeedsAttention
    readonly property bool menuOpen: Dropdown.current === "menu" && Dropdown.menuItem === item
    readonly property string name: Tray.nameOf(item)

    property bool tipOn: false

    implicitWidth: 24
    implicitHeight: 22

    // A new app pops in.
    Component.onCompleted: pop.start()

    ParallelAnimation {
        id: pop

        NumberAnimation { target: icon; property: "opacity"; from: 0; to: 1; duration: 300 }
        NumberAnimation {
            target: icon
            property: "scale"
            from: 0.55
            to: 1
            duration: 300
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
        }
    }

    function openMenu() {
        if (!item || !item.hasMenu)
            return
        Dropdown.openMenu(item, icon.mapToItem(null, icon.width / 2, 0).x)
    }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: icon.c.surfaceAlt
        opacity: area.containsMouse || icon.menuOpen ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 140 }
        }
    }

    Image {
        anchors.centerIn: parent
        width: 16
        height: 16
        source: icon.item?.icon ?? ""
        sourceSize: Qt.size(32, 32)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
    }

    // The app asks for attention.
    Rectangle {
        visible: icon.attention
        x: parent.width - width
        y: 0
        width: 10          // 6 px dot plus its 2 px ring
        height: 10
        radius: 5
        color: icon.c.accent
        border.width: 2
        border.color: icon.c.surface
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onContainsMouseChanged: {
            if (!containsMouse)
                icon.tipOn = false
        }

        onClicked: mouse => {
            if (!icon.item)
                return
            if (mouse.button === Qt.RightButton) {
                icon.openMenu()
            } else if (mouse.button === Qt.MiddleButton) {
                icon.item.secondaryActivate()
            } else if (icon.item.onlyMenu && icon.item.hasMenu) {
                icon.openMenu()
            } else {
                Tray.activateItem(icon.item)
            }
        }

        onWheel: wheel => {
            if (!icon.item)
                return
            if (wheel.angleDelta.y !== 0)
                icon.item.scroll(wheel.angleDelta.y, false)
            if (wheel.angleDelta.x !== 0)
                icon.item.scroll(wheel.angleDelta.x, true)
        }
    }

    Timer {
        interval: 500
        running: area.containsMouse && Dropdown.current === ""
        onTriggered: icon.tipOn = true
    }

    // Tooltip: the app's name, after half a second of hover.
    PopupWindow {
        visible: icon.tipOn && icon.name !== "" && Dropdown.current === ""
        anchor.item: icon
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.top: 6
        implicitWidth: tip.implicitWidth
        implicitHeight: tip.implicitHeight
        color: "transparent"

        Rectangle {
            id: tip

            implicitWidth: label.implicitWidth + 16
            implicitHeight: label.implicitHeight + 8
            radius: 8
            color: icon.c.surface
            border.width: 1
            border.color: icon.c.border

            Text {
                id: label

                anchors.centerIn: parent
                text: icon.name
                textFormat: Text.PlainText
                color: icon.c.text
                renderType: Text.CurveRendering
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
        }
    }
}
