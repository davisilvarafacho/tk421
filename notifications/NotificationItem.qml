import QtQuick

import "../components"
import "../services"
import "../theme"
import "logic.js" as Logic

// One row of the comms log: an optional day label, then the notification. `modelData` is a NotificationEntry.
// Layout: a header line (small icon, app name, time), then the title and the text across the full width.
Item {
    id: item

    readonly property var c: Theme.imperial

    required property var modelData
    required property int index

    property double now: Date.now()

    readonly property var entry: modelData
    readonly property bool critical: entry?.critical ?? false
    readonly property string day: Logic.dayLabel(entry?.timestamp ?? now, now)
    readonly property bool newDay: index === 0 || Logic.dayLabel(Notifications.history[index - 1]?.timestamp ?? 0, now) !== day
    // A title that only repeats the app name ("Claude Code" from Claude Code) is dropped: the text becomes the title line.
    readonly property bool repeatsApp: (entry?.summary ?? "").toLowerCase() === (entry?.label ?? "").toLowerCase()

    width: ListView.view.width
    height: dayRow.height + card.height

    Item {
        id: dayRow

        width: parent.width
        height: item.newDay ? 28 : 0
        visible: item.newDay

        Text {
            x: 16
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            text: item.day
            textFormat: Text.PlainText
            color: item.c.muted
            renderType: Text.CurveRendering
            font.family: Theme.displayFont
            font.pixelSize: 9
            font.letterSpacing: 1.8
            font.capitalization: Font.AllUppercase
        }
    }

    Rectangle {
        id: card

        y: dayRow.height
        width: parent.width
        height: content.height + 22
        color: hover.hovered ? Qt.rgba(0.91, 0.9, 0.89, 0.035) : "transparent"

        Behavior on color { ColorAnimation { duration: 120 } }

        HoverHandler {
            id: hover
        }

        // A click on the text marks it read.
        MouseArea {
            anchors.fill: parent
            onClicked: Notifications.markRead(item.entry)
        }

        // Unread dot, in the left margin level with the header.
        Rectangle {
            visible: item.entry?.unread ?? false
            x: 6
            y: 11 + 8 - 2.5
            width: 5
            height: 5
            radius: 2.5
            color: item.c.accent
        }

        Column {
            id: content

            x: 16
            y: 11
            width: parent.width - 32

            // Header: icon, app name, time. On hover the time gives way to the dismiss button.
            Item {
                id: header

                width: parent.width
                height: 16

                AppTile {
                    id: tile

                    anchors.verticalCenter: parent.verticalCenter
                    size: 16
                    appIcon: item.entry?.appIcon ?? ""
                    desktopEntry: item.entry?.desktopEntry ?? ""
                    asset: item.entry?.iconAsset ?? ""
                    critical: item.critical
                }

                Text {
                    x: tile.width + 8
                    width: stamp.x - x - 8
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 1      // Orbitron's digits sit ~1px high at this size
                    text: item.entry?.label ?? ""
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: item.critical ? item.c.dangerText : item.c.muted
                    renderType: Text.CurveRendering
                    font.family: Theme.displayFont
                    font.pixelSize: 9
                    font.letterSpacing: 1.6
                    font.capitalization: Font.AllUppercase
                }

                Row {
                    id: stamp

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    opacity: hover.hovered ? 0 : 1

                    Behavior on opacity { NumberAnimation { duration: 140 } }

                    Text {
                        visible: item.entry?.low ?? false
                        anchors.verticalCenter: parent.verticalCenter
                        text: "ROUTINE"
                        color: item.c.muted
                        opacity: 0.8
                        renderType: Text.CurveRendering
                        font.family: Theme.displayFont
                        font.pixelSize: 8
                        font.letterSpacing: 1.4
                    }

                    Text {
                        text: Logic.relativeTime(item.entry?.timestamp ?? item.now, item.now)
                        color: item.critical ? item.c.dangerText : item.c.muted
                        renderType: Text.CurveRendering
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }

                // Dismiss: only while hovered.
                Item {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 20
                    opacity: hover.hovered ? 1 : 0

                    Behavior on opacity { NumberAnimation { duration: 140 } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        color: xArea.containsMouse ? item.c.text : item.c.muted
                        renderType: Text.CurveRendering
                        font.family: Theme.iconFont
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: xArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifications.dismiss(item.entry)
                    }
                }
            }

            Item {
                width: 1
                height: 4
            }

            Text {
                width: parent.width
                height: 20
                visible: !item.repeatsApp
                text: item.entry?.summary ?? ""
                textFormat: Text.PlainText
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                color: item.critical ? item.c.dangerText : item.c.text
                renderType: Text.CurveRendering
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.Medium
            }

            // The title only repeated the app name: the text takes the title's place.
            Text {
                width: parent.width
                visible: item.repeatsApp
                text: item.entry?.body ?? ""
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: 2
                color: item.critical ? item.c.dangerText : item.c.text
                renderType: Text.CurveRendering
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.Medium
            }

            Text {
                width: parent.width
                visible: !item.repeatsApp && text !== ""
                text: item.entry?.body ?? ""
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: 2
                color: item.c.muted
                renderType: Text.CurveRendering
                font.family: Theme.fontFamily
                font.pixelSize: 12
                lineHeight: 16
                lineHeightMode: Text.FixedHeight
            }

            Row {
                visible: (item.entry?.actions.length ?? 0) > 0
                topPadding: 8
                spacing: 4
                x: -10

                Repeater {
                    model: item.entry?.actions ?? []

                    delegate: ActionButton {
                        required property var modelData
                        required property int index

                        text: modelData.text
                        primary: index === 0
                        danger: index === 0 && item.critical
                        onClicked: Notifications.invoke(item.entry, index)
                    }
                }
            }
        }
    }
}
