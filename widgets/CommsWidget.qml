import QtQuick

import "../components"
import "../services"
import "../theme"
import "logic.js" as Logic

// The three newest notifications (services/Notifications.qml). Read-only: the comms log (SUPER+N) is where they
// are answered or dismissed. Titles and bodies are the apps' own: plain text, one line each.
WidgetPanel {
    id: w

    property double now: Date.now()
    readonly property var latest: Notifications.history.slice(0, 3)

    label: "Comms"
    aside: Notifications.dnd ? "silenced"
        : Notifications.unreadCount > 0 ? Notifications.unreadCount + " unread" : "all read"

    Text {
        visible: w.latest.length === 0
        text: "No notifications."
        color: Theme.imperial.muted
        renderType: Text.CurveRendering
        font.family: Theme.fontFamily
        font.pixelSize: 13
    }

    Repeater {
        model: w.latest

        delegate: Item {
            id: row

            required property var modelData
            required property int index

            width: w.width - 40
            height: 48

            Rectangle {
                visible: row.index > 0
                width: parent.width
                height: 1
                color: Qt.rgba(1, 1, 1, 0.05)
            }

            Rectangle {
                x: 0
                y: 10
                width: 28
                height: 28
                radius: 8
                color: Theme.imperial.surfaceAlt

                AppTile {
                    anchors.centerIn: parent
                    size: 16
                    appIcon: row.modelData.appIcon
                    desktopEntry: row.modelData.desktopEntry
                    asset: row.modelData.iconAsset
                    critical: row.modelData.critical
                }
            }

            Text {
                id: age

                anchors.right: parent.right
                y: 10
                text: Logic.age(row.modelData.timestamp, w.now)
                color: Theme.imperial.faint
                renderType: Text.CurveRendering
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }

            Column {
                x: 40
                y: 8
                width: age.x - 40 - 12

                Text {
                    width: parent.width
                    text: row.modelData.summary
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    color: row.modelData.critical ? Theme.imperial.dangerText : Theme.imperial.text
                    renderType: Text.CurveRendering
                    font.family: Theme.fontFamily
                    font.weight: Font.Medium
                    font.pixelSize: 13
                }

                Text {
                    width: parent.width
                    visible: text !== ""
                    text: String(row.modelData.body).replace(/\s+/g, " ").trim()
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    color: Theme.imperial.muted
                    renderType: Text.CurveRendering
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }
            }
        }
    }
}
