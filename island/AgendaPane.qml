import QtQuick

import "../components"
import "../services"
import "../theme"

// Events of the selected day, beside the month grid. All-day events are chips on top; timed events hang on a
// timeline. On today, past events dim and the next one is marked with how long is left.
Item {
    id: root

    required property date selected
    required property date today

    readonly property var c: Theme.imperial
    readonly property color dot: "#8AA4D6"
    readonly property bool isToday: selected.toDateString() === today.toDateString()
    readonly property var list: Agenda.eventsOn(selected)
    readonly property bool offline: Agenda.status === "stale" || Agenda.status === "error"

    readonly property int nowMinutes: today.getHours() * 60 + today.getMinutes()
    readonly property int firstTimed: list.findIndex(e => !e.allday)
    readonly property int lastTimed: list.length - 1 - list.slice().reverse().findIndex(e => !e.allday)
    // The first timed event still ahead of us (today only), -1 otherwise.
    readonly property int nextIndex: isToday ? list.findIndex(e => !e.allday && minutesOf(e) > nowMinutes) : -1

    implicitWidth: 327
    implicitHeight: 318

    function minutesOf(e) {
        const p = String(e.time).split(":")
        return parseInt(p[0]) * 60 + parseInt(p[1])
    }

    function until(e) {
        const m = minutesOf(e) - nowMinutes
        if (m < 60)
            return "in " + m + " min"
        const h = Math.floor(m / 60)
        return "in " + h + " h" + (m % 60 > 0 ? " " + (m % 60) + " min" : "")
    }

    // Header: the day, then the date and how many events it holds.
    Item {
        id: head
        width: parent.width
        height: 50

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                renderType: Text.CurveRendering
                text: root.isToday ? "Today" : Qt.locale("en_US").toString(root.selected, "dddd")
                color: root.c.text
                font.family: Theme.fontFamily
                font.pixelSize: 19
                font.weight: Font.DemiBold
            }

            Text {
                renderType: Text.CurveRendering
                text: Qt.locale("en_US").toString(root.selected, "d MMMM")
                      + (root.list.length === 0 ? ""
                         : "  ·  " + root.list.length + (root.list.length === 1 ? " event" : " events"))
                color: root.c.muted
                font.family: Theme.fontFamily
                font.pixelSize: 13
            }
        }

        Rectangle {
            visible: root.offline
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: offlineLabel.implicitWidth + 20
            height: 24
            radius: 12
            color: Qt.rgba(1, 1, 1, 0.07)

            Text {
                id: offlineLabel
                renderType: Text.CurveRendering
                anchors.centerIn: parent
                text: "Offline"
                color: root.c.muted
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
            }
        }
    }

    ListView {
        id: events

        anchors.top: head.bottom
        anchors.topMargin: 10
        anchors.bottom: parent.bottom
        width: parent.width
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.list

        delegate: Item {
            id: row

            required property var modelData
            required property int index

            readonly property bool allday: modelData.allday
            readonly property bool past: root.isToday && !allday && root.minutesOf(modelData) <= root.nowMinutes
            readonly property bool next: index === root.nextIndex
            readonly property bool gapBelow: allday && index + 1 < root.list.length && !root.list[index + 1].allday

            width: events.width
            height: allday ? (gapBelow ? 52 : 46) : 64

            // All-day: a chip.
            Rectangle {
                visible: row.allday
                y: 0
                width: parent.width
                height: 40
                radius: 12
                color: Qt.rgba(1, 1, 1, chipHover.hovered ? 0.1 : 0.07)

                Behavior on color { ColorAnimation { duration: 120 } }

                HoverHandler { id: chipHover }

                Icon {
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    name: "calendar_today"
                    size: Theme.iconSize.panel
                    color: root.c.muted
                }

                Text {
                    id: chipSub
                    renderType: Text.CurveRendering
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    visible: text !== "" && text !== row.modelData.calendar
                    width: Math.min(implicitWidth, parent.width * 0.4)
                    text: row.modelData.sub
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: root.c.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }

                Text {
                    renderType: Text.CurveRendering
                    x: 40
                    anchors.verticalCenter: parent.verticalCenter
                    width: (chipSub.visible ? chipSub.x : parent.width - 14) - x - 8
                    text: row.modelData.title
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: root.c.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.Medium
                }
            }

            // Timed: time, a node on the timeline, title and details.
            Item {
                visible: !row.allday
                anchors.fill: parent
                opacity: row.past ? 0.5 : 1

                Rectangle {
                    y: 2
                    width: parent.width
                    height: parent.height - 4
                    radius: 12
                    color: Qt.rgba(1, 1, 1, rowHover.hovered ? 0.06 : 0)

                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                HoverHandler { id: rowHover }

                // Timeline: a hairline through the nodes, trimmed at the first and last event.
                Rectangle {
                    x: 76
                    y: row.index === root.firstTimed ? parent.height / 2 : 0
                    width: 1
                    height: row.index === root.firstTimed && row.index === root.lastTimed ? 0
                          : row.index === root.firstTimed ? parent.height / 2
                          : row.index === root.lastTimed ? parent.height / 2
                          : parent.height
                    color: Qt.rgba(1, 1, 1, 0.14)
                }

                Text {
                    renderType: Text.CurveRendering
                    x: 12
                    width: 52
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.time
                    color: row.next ? root.c.text : root.c.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }

                // Node: filled blue for the next event, a ring for the others.
                Rectangle {
                    x: 76 - width / 2 + 0.5
                    anchors.verticalCenter: parent.verticalCenter
                    width: row.next ? 11 : 9
                    height: width
                    radius: width / 2
                    color: row.next ? root.dot : "#000000"
                    border.width: row.next ? 0 : 1.5
                    border.color: root.c.muted
                }

                Column {
                    x: 98
                    width: parent.width - x - 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Row {
                        width: parent.width
                        spacing: 8

                        Text {
                            renderType: Text.CurveRendering
                            width: parent.width - (untilPill.visible ? untilPill.width + 8 : 0)
                            text: row.modelData.title
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: root.c.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }

                        Rectangle {
                            id: untilPill
                            visible: row.next
                            anchors.verticalCenter: parent.verticalCenter
                            width: untilLabel.implicitWidth + 14
                            height: 20
                            radius: 10
                            color: Qt.rgba(0.54, 0.64, 0.84, 0.18)

                            Text {
                                id: untilLabel
                                renderType: Text.CurveRendering
                                anchors.centerIn: parent
                                text: row.next ? root.until(row.modelData) : ""
                                color: root.dot
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    Text {
                        renderType: Text.CurveRendering
                        width: parent.width
                        text: row.modelData.sub
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: root.c.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                }
            }
        }
    }

    // Edge fade: hints that the list continues below.
    Rectangle {
        anchors.left: events.left
        anchors.right: events.right
        anchors.bottom: events.bottom
        height: 32
        visible: events.contentHeight > events.height && !events.atYEnd

        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: root.c.ink }
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
