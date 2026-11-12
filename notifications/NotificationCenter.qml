import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

import "../components"
import "../services"
import "../theme"
import "logic.js" as Logic

// The comms log. It has no frame of its own: it hangs from the toolbar pill, exactly as wide, in the same opaque ink, so
// the pill seems to grow down into it (the pill squares its bottom corners while `Notifications.docked`). One entry per
// conversation (ConversationRow). Opened by the bell, IPC `notifications toggleCenter` or SUPER+N.
// Prototype: prototypes/notifications/comms.html
PanelWindow {
    id: win

    readonly property var c: Theme.imperial
    readonly property bool opened: Notifications.centerOpen
    readonly property real bottomGap: 8
    readonly property var groups: Logic.conversations(Notifications.history, now)

    property double now: Date.now()
    property var expandedKeys: []

    // The pill spans y 4..34; the log starts on its bottom hairline row and covers it.
    anchors {
        top: true
        right: true
        bottom: true
    }
    margins.top: 33
    margins.right: 30
    implicitWidth: Math.round(Notifications.dockWidth)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    // Stay mapped while the close animation plays.
    visible: opened || sheet.height > 0

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "tk421-notifications"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Only the log takes input; the rest of the window is click-through.
    mask: Region { item: sheet }

    Binding {
        target: Notifications
        property: "docked"
        value: win.visible
    }

    component Ease: NumberAnimation {
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
    }

    onOpenedChanged: {
        now = Date.now()
        if (!opened)
            expandedKeys = []
    }

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

    // Relative times ("4m") stay fresh while it is open.
    Timer {
        interval: 30000
        repeat: true
        running: win.opened
        onTriggered: win.now = Date.now()
    }

    Item {
        id: sheet

        // Height follows the content, capped by the screen.
        readonly property real full: Math.min(win.height - win.bottomGap,
            body.y + (list.count > 0 ? list.contentHeight : empty.height) + 12)

        width: win.width
        height: win.opened ? full : 0
        clip: true

        Behavior on height { Ease { duration: win.opened ? 520 : 340 } }

        // The hairline on the sides and bottom (no top edge: the pill is there), then the ink inside it.
        Rectangle {
            anchors.fill: parent
            color: win.c.hairline
            bottomLeftRadius: 22
            bottomRightRadius: 22
        }

        Rectangle {
            x: 1
            width: parent.width - 2
            height: parent.height - 1
            color: win.c.ink
            bottomLeftRadius: 21
            bottomRightRadius: 21
        }

        Item {
            id: content

            width: parent.width
            height: sheet.full
            opacity: win.opened ? 1 : 0

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: win.opened ? 140 : 0 }
                    NumberAnimation { duration: win.opened ? 320 : 140 }
                }
            }

            // Header: title, silence, purge.
            Item {
                id: header

                x: 22
                y: 16
                width: parent.width - 22 - 16
                height: 28

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 1
                    text: "COMMS LOG"
                    color: win.c.text
                    renderType: Text.CurveRendering
                    font.family: Theme.displayFont
                    font.pixelSize: 11
                    font.letterSpacing: 2.2
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    HeadButton {
                        icon: "notifications_paused"
                        label: "Silence"
                        lit: Notifications.dnd
                        onClicked: Notifications.setDnd(!Notifications.dnd)
                    }

                    HeadButton {
                        label: "Purge"
                        enabled: Notifications.history.length > 0
                        opacity: enabled ? 1 : 0.35
                        onClicked: Notifications.clear()
                    }
                }
            }

            Text {
                id: silenced

                x: 22
                y: header.y + header.height + 8
                width: parent.width - 44
                height: Notifications.dnd ? implicitHeight : 0
                visible: Notifications.dnd
                text: "Comms silenced. Critical alerts still come through."
                color: win.c.muted
                wrapMode: Text.Wrap
                renderType: Text.CurveRendering
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }

            Item {
                id: body

                x: 10
                y: silenced.y + silenced.height + (Notifications.dnd ? 10 : 2)
                width: parent.width - 20
                height: sheet.full - y - 12

                ListView {
                    id: list

                    anchors.fill: parent
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    visible: count > 0

                    model: ScriptModel {
                        values: win.groups
                        objectProp: "key"
                    }

                    delegate: ConversationRow {
                        now: win.now
                        expanded: win.expandedKeys.indexOf(modelData.key) >= 0
                        onExpandRequested: win.expandedKeys = win.expandedKeys.concat([modelData.key])
                    }

                    add: Transition {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 260 }
                    }

                    remove: Transition {
                        NumberAnimation { property: "opacity"; to: 0; duration: 140 }
                    }

                    displaced: Transition {
                        NumberAnimation { property: "y"; duration: 280; easing.type: Easing.OutCubic }
                    }
                }

                Column {
                    id: empty

                    x: 12
                    y: 14
                    height: 60
                    spacing: 2
                    visible: list.count === 0

                    Text {
                        text: "No transmissions."
                        color: win.c.text
                        renderType: Text.CurveRendering
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                    }

                    Text {
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
}
