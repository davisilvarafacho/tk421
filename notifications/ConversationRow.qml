import QtQuick

import "../components"
import "../services"
import "../theme"
import "logic.js" as Logic

// One conversation of the comms log (prototype: prototypes/notifications/comms.html). `modelData` is a group from
// Logic.conversations: notifications with the same app and title, newest first. Layout: an optional section label,
// then icon, title and time on one line, the texts underneath (oldest to newest, the newest three unless expanded).
// Hover swaps the time for the app's first action and a dismiss button; dragging the row to the right dismisses it.
Item {
    id: row

    readonly property var c: Theme.imperial

    required property var modelData
    required property int index

    property double now: Date.now()
    property bool expanded: false

    signal expandRequested()

    readonly property var entries: modelData?.entries ?? []
    readonly property var head: entries[0] ?? null
    readonly property bool critical: modelData?.critical ?? false
    readonly property bool unread: entries.some(e => e.unread)        // live: markRead does not regroup
    // Texts oldest to newest; a notification without text adds no line.
    readonly property var lines: entries.slice().reverse().filter(e => (e?.body ?? "") !== "")
    readonly property var shown: expanded ? lines : lines.slice(-3)
    readonly property var action: head && head.actions.length > 0 ? head.actions[0] : null

    width: ListView.view.width
    height: sectionRow.height + card.height

    function dismissAll() {
        entries.slice().forEach(e => Notifications.dismiss(e))
    }

    Item {
        id: sectionRow

        width: parent.width
        height: row.modelData?.newSection ? (row.index === 0 ? 22 : 34) : 0
        visible: height > 0

        Text {
            x: 44
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            text: row.modelData?.section ?? ""
            textFormat: Text.PlainText
            color: row.c.faint
            renderType: Text.CurveRendering
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }
    }

    Rectangle {
        id: card

        y: sectionRow.height
        width: parent.width
        height: content.height + 20
        radius: 14
        color: hover.hovered || drag.drag.active ? row.c.rowHover : "transparent"
        opacity: 1 - Math.min(x / 240, 0.7)

        Behavior on color { ColorAnimation { duration: 120 } }

        HoverHandler {
            id: hover
        }

        NumberAnimation {
            id: back

            target: card
            property: "x"
            to: 0
            duration: 260
            easing.type: Easing.OutCubic
        }

        SequentialAnimation {
            id: away

            NumberAnimation { target: card; property: "x"; to: card.width * 1.1; duration: 220; easing.type: Easing.InCubic }
            ScriptAction { script: row.dismissAll() }
        }

        // Drag sideways to dismiss. Buttons inside sit above this area and keep their clicks.
        MouseArea {
            id: drag

            anchors.fill: parent
            drag.target: card
            drag.axis: Drag.XAxis
            drag.minimumX: 0
            drag.maximumX: card.width
            drag.threshold: 6
            onReleased: card.x > 90 ? away.start() : back.start()
        }

        AppTile {
            x: 12
            y: 10 + 2
            size: 16
            appIcon: row.head?.appIcon ?? ""
            desktopEntry: row.head?.desktopEntry ?? ""
            asset: row.head?.iconAsset ?? ""
            critical: row.critical
        }

        Column {
            id: content

            x: 12 + 20 + 12
            y: 10
            width: parent.width - x - 12

            Item {
                width: parent.width
                height: 20

                Text {
                    width: (hover.hovered ? tools.x : time.x) - 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.head?.summary ?? ""
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: row.critical ? row.c.dangerText : row.unread ? row.c.text : row.c.muted
                    renderType: Text.CurveRendering
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.weight: row.unread || row.critical ? Font.Medium : Font.Normal
                }

                Text {
                    id: time

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !hover.hovered
                    text: Logic.relativeTime(row.head?.timestamp ?? row.now, row.now).toLowerCase()
                    color: row.c.faint
                    renderType: Text.CurveRendering
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.features: { "tnum": 1 }
                }

                // While hovered the time gives way to the app's first action and dismiss.
                Row {
                    id: tools

                    anchors.right: parent.right
                    anchors.rightMargin: -6
                    anchors.verticalCenter: parent.verticalCenter
                    visible: hover.hovered
                    spacing: 2

                    SmallButton {
                        visible: row.action !== null
                        label: row.action?.text ?? ""
                        onClicked: Notifications.invoke(row.head, 0)
                    }

                    SmallButton {
                        icon: "close"
                        onClicked: away.start()
                    }
                }
            }

            Text {
                visible: row.lines.length > row.shown.length
                height: visible ? 20 : 0
                verticalAlignment: Text.AlignVCenter
                text: (row.lines.length - row.shown.length) + " earlier"
                color: earlierArea.containsMouse ? row.c.text : row.c.faint
                renderType: Text.CurveRendering
                font.family: Theme.fontFamily
                font.pixelSize: 11

                MouseArea {
                    id: earlierArea

                    anchors.fill: parent
                    anchors.margins: -2
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: row.expandRequested()
                }
            }

            Repeater {
                model: row.shown

                delegate: Text {
                    required property var modelData
                    required property int index

                    width: content.width
                    text: modelData?.body ?? ""
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    maximumLineCount: row.expanded ? 6 : 3
                    // The newest line reads first; older ones and read conversations step back.
                    color: row.unread && index === row.shown.length - 1 ? row.c.muted : row.c.faint
                    renderType: Text.CurveRendering
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    lineHeight: 18
                    lineHeightMode: Text.FixedHeight
                }
            }
        }
    }
}
