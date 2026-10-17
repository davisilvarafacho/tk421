import QtQuick

import "../services"
import "../theme"

Item {
    id: root

    required property date selected
    required property date today

    readonly property var c: Theme.imperial
    readonly property bool isToday: selected.toDateString() === today.toDateString()
    readonly property var list: Agenda.eventsOn(selected)

    implicitWidth: 327
    implicitHeight: 300

    // Header
    Item {
        id: head
        width: parent.width
        height: 32

        Text {
            renderType: Text.CurveRendering
            text: root.isToday ? "TODAY" : Qt.locale("en_US").toString(root.selected, "ddd, d MMM").toUpperCase()
            color: root.c.text
            font.family: Theme.displayFont
            font.pixelSize: 12
            font.weight: Font.Medium
            font.letterSpacing: 2.2
        }

        Text {
            renderType: Text.CurveRendering
            anchors.right: parent.right
            text: Agenda.status === "stale" || Agenda.status === "error" ? "Offline"
                : root.list.length === 0 ? ""
                : root.list.length + (root.list.length === 1 ? " event" : " events")
            color: root.c.muted
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }
    }

    ListView {
        id: events

        anchors.top: head.bottom
        anchors.topMargin: 4
        anchors.bottom: parent.bottom
        width: parent.width
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.list

        delegate: Item {
            required property var modelData

            width: events.width
            height: 44

            Text {
                renderType: Text.CurveRendering
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.allday ? "All day" : modelData.time
                color: root.c.muted
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 50
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Row {
                    spacing: 8
                    width: parent.width

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 6
                        height: 6
                        radius: 3
                        color: modelData.allday ? "transparent" : root.c.accent
                        border.width: modelData.allday ? 1 : 0
                        border.color: root.c.muted
                    }

                    Text {
                        renderType: Text.CurveRendering
                        width: parent.width - 14
                        text: modelData.title
                        textFormat: Text.PlainText
                        color: root.c.text
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.Medium
                    }
                }

                Text {
                    renderType: Text.CurveRendering
                    width: parent.width
                    text: modelData.sub
                    textFormat: Text.PlainText
                    color: root.c.muted
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }
            }
        }
    }

    // Edge fade: hints that the list continues below.
    Rectangle {
        anchors.left: events.left
        anchors.right: events.right
        anchors.bottom: events.bottom
        height: 28
        visible: events.contentHeight > events.height && !events.atYEnd

        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: root.c.surface }
        }
    }

    // Empty state: dimmed icon and label, centred in the space under the header.
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: events.verticalCenter
        visible: root.list.length === 0
        spacing: 10
        opacity: 0.45

        Text {
            renderType: Text.CurveRendering
            anchors.horizontalCenter: parent.horizontalCenter
            text: "󰃭"    // nf-md-calendar
            color: root.c.muted
            font.family: Theme.iconFont
            font.pixelSize: 34
        }

        Text {
            renderType: Text.CurveRendering
            anchors.horizontalCenter: parent.horizontalCenter
            text: Agenda.status === "unconfigured" ? "calendar not set up..." : "no events..."
            color: root.c.muted
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }
    }
}
