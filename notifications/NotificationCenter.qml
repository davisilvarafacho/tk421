import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

import "../components"
import "../services"
import "../theme"

// The comms log: a translucent drawer that slides in from the right edge, below the bar. Opened by the bell,
// IPC `notifications toggleCenter` or SUPER+N. Prototype: prototypes/notifications/index.html
PanelWindow {
    id: win

    readonly property var c: Theme.imperial
    readonly property bool opened: Notifications.centerOpen
    readonly property real drawerWidth: 360
    readonly property real rightGap: 8      // the drawer floats this far from the right and bottom screen edges
    readonly property real bottomGap: 8

    property double now: Date.now()

    anchors {
        top: true
        right: true
        bottom: true
    }
    margins.top: 40
    implicitWidth: drawerWidth + rightGap
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    // Stay mapped while the slide-out plays.
    visible: opened || panel.x < win.width

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "tk421-notifications"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Only the drawer takes input; the rest of the window is click-through.
    mask: Region { item: panel }

    component Ease: NumberAnimation {
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
    }

    onOpenedChanged: now = Date.now()

    // A click outside closes it. Held while a screenshot is being taken (Dropdown.held), so SUPER+S can capture it.
    HyprlandFocusGrab {
        windows: [win]
        active: win.opened && !Dropdown.held
        onCleared: Notifications.closeByGrab()
    }

    Shortcut {
        sequence: "Escape"
        enabled: win.opened
        onActivated: Notifications.setCenterOpen(false)
    }

    // Relative times ("4M") stay fresh while it is open.
    Timer {
        interval: 30000
        repeat: true
        running: win.opened
        onTriggered: win.now = Date.now()
    }

    // A floating card: the window reaches the right screen edge so the slide starts off-screen, the card keeps `rightGap` and
    // `bottomGap` from the right and bottom edges. The fill is translucent; Hyprland blurs what is behind it (layer rule in hypr/hyprland.lua).
    Rectangle {
        id: panel

        x: win.opened ? 0 : win.width
        y: 0
        width: win.drawerWidth
        height: win.height - win.bottomGap
        radius: 20
        color: Qt.alpha(win.c.surface, 0.72)
        border.width: 1
        border.color: win.c.border
        clip: true

        Behavior on x { Ease { duration: win.opened ? 520 : 340 } }

        Item {
            id: content

            x: 1
            y: 1
            width: panel.width - 2
            height: panel.height - 2
            opacity: win.opened ? 1 : 0

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: win.opened ? 140 : 0 }
                    NumberAnimation { duration: win.opened ? 320 : 140 }
                }
            }

            // Header: title, unread count, Do Not Disturb, purge.
            Item {
                id: header

                x: 16
                width: parent.width - 32
                height: 48

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 1
                    spacing: 8

                    Text {
                        text: "COMMS LOG"
                        color: win.c.text
                        renderType: Text.CurveRendering
                        font.family: Theme.displayFont
                        font.pixelSize: 11
                        font.letterSpacing: 2.2
                    }

                    Text {
                        anchors.baseline: parent.children[0].baseline
                        visible: Notifications.unreadCount > 0
                        text: Notifications.unreadCount + " UNREAD"
                        color: win.c.muted
                        renderType: Text.CurveRendering
                        font.family: Theme.displayFont
                        font.pixelSize: 9
                        font.letterSpacing: 1.6
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    // Do Not Disturb.
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 8
                        color: Notifications.dnd ? win.c.accentDim
                            : dndArea.containsMouse ? Qt.rgba(0.91, 0.9, 0.89, 0.06) : "transparent"

                        Behavior on color { ColorAnimation { duration: 140 } }

                        Icon {
                            anchors.centerIn: parent
                            name: "notifications_paused"
                            color: Notifications.dnd || dndArea.containsMouse ? win.c.text : win.c.muted
                            size: Theme.iconSize.panel
                        }

                        MouseArea {
                            id: dndArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Notifications.setDnd(!Notifications.dnd)
                        }
                    }

                    ActionButton {
                        text: "Purge"
                        enabled: Notifications.history.length > 0
                        opacity: enabled ? 1 : 0.3
                        onClicked: Notifications.clear()
                    }
                }
            }

            // Do Not Disturb strip.
            Item {
                id: strip

                x: 16
                y: header.height
                width: header.width
                height: Notifications.dnd ? 30 : 0
                opacity: Notifications.dnd ? 1 : 0
                clip: true

                Behavior on height { Ease { duration: 300 } }
                Behavior on opacity { NumberAnimation { duration: 200 } }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 5
                        height: 5
                        radius: 2.5
                        color: win.c.accent
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 1
                        text: "COMMS SILENCED"
                        color: win.c.text
                        renderType: Text.CurveRendering
                        font.family: Theme.displayFont
                        font.pixelSize: 9
                        font.letterSpacing: 1.6
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "· critical still gets through"
                        color: win.c.muted
                        renderType: Text.CurveRendering
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }
            }

            ListView {
                id: list

                anchors.top: strip.bottom
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                width: parent.width
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                visible: count > 0

                model: ScriptModel {
                    values: Notifications.history
                    objectProp: "uid"
                }

                delegate: NotificationItem {
                    now: win.now
                }

                add: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 320 }
                        NumberAnimation { property: "y"; from: -10; duration: 460; easing.type: Easing.OutCubic }
                    }
                }

                remove: Transition {
                    NumberAnimation { property: "opacity"; to: 0; duration: 160 }
                }

                displaced: Transition {
                    NumberAnimation { property: "y"; duration: 300; easing.type: Easing.OutCubic }
                }
            }

            // Empty state.
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.3
                spacing: 8
                visible: list.count === 0

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "notifications_paused"
                    color: win.c.muted
                    size: Theme.iconSize.hero
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "NO TRANSMISSIONS"
                    color: win.c.text
                    renderType: Text.CurveRendering
                    font.family: Theme.displayFont
                    font.pixelSize: 10
                    font.letterSpacing: 2
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "All channels clear."
                    color: win.c.muted
                    renderType: Text.CurveRendering
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }
            }
        }
    }
}
