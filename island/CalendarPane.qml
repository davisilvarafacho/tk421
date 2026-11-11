import QtQuick

import "../components"
import "../services"
import "../theme"

// Month grid of the island's calendar tab. Sunday-first (Brazil). Days with events carry a small dot.
Item {
    id: root

    required property date today
    property date viewDate: today
    property date selected: today

    signal picked(date day)
    signal viewed(date month)

    readonly property var c: Theme.imperial
    readonly property color hoverFill: Qt.rgba(1, 1, 1, 0.07)
    readonly property color selectFill: Qt.rgba(1, 1, 1, 0.14)
    readonly property var weekdays: ["S", "M", "T", "W", "T", "F", "S"]
    readonly property date gridStart: {
        const first = new Date(viewDate.getFullYear(), viewDate.getMonth(), 1)
        return new Date(first.getFullYear(), first.getMonth(), 1 - first.getDay())
    }
    readonly property bool onCurrentMonth: viewDate.getFullYear() === today.getFullYear()
                                           && viewDate.getMonth() === today.getMonth()

    // Month change: the grid slides in from the side it came from.
    readonly property int monthIndex: viewDate.getFullYear() * 12 + viewDate.getMonth()
    property int lastMonthIndex: monthIndex
    property int slideFrom: 0
    property real wheelAcc: 0

    onMonthIndexChanged: {
        slideFrom = monthIndex > lastMonthIndex ? 18 : -18
        lastMonthIndex = monthIndex
        slide.restart()
    }

    implicitWidth: 308
    implicitHeight: 318

    // Mouse wheel over the calendar flips months (WheelHandler never fires in this shell).
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            root.wheelAcc += wheel.angleDelta.y
            if (Math.abs(root.wheelAcc) >= 120) {
                const step = root.wheelAcc < 0 ? 1 : -1
                root.wheelAcc = 0
                root.viewed(new Date(root.viewDate.getFullYear(), root.viewDate.getMonth() + step, 1))
            }
        }
    }

    component NavButton: Rectangle {
        property string glyph
        property color hover
        property color ink
        signal clicked()

        width: 32
        height: 32
        radius: 16
        color: area.containsMouse ? hover : "transparent"

        Behavior on color { ColorAnimation { duration: 120 } }

        Icon {
            anchors.centerIn: parent
            name: parent.glyph
            size: Theme.iconSize.panel
            color: parent.ink
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    // Header: month and year, "Today" shortcut, previous/next.
    Item {
        id: head
        width: parent.width
        height: 36

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Text {
                renderType: Text.CurveRendering
                text: Qt.locale("en_US").toString(root.viewDate, "MMMM")
                color: root.c.text
                font.family: Theme.fontFamily
                font.pixelSize: 19
                font.weight: Font.DemiBold
            }

            Text {
                renderType: Text.CurveRendering
                text: Qt.locale("en_US").toString(root.viewDate, "yyyy")
                color: root.c.muted
                font.family: Theme.fontFamily
                font.pixelSize: 19
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Rectangle {
                visible: !root.onCurrentMonth
                width: todayLabel.implicitWidth + 22
                height: 28
                radius: 14
                color: todayArea.containsMouse ? root.selectFill : root.hoverFill

                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    id: todayLabel
                    renderType: Text.CurveRendering
                    anchors.centerIn: parent
                    text: "Today"
                    color: root.c.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: todayArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.viewed(root.today)
                        root.picked(root.today)
                    }
                }
            }

            Item { width: 6; height: 1; visible: !root.onCurrentMonth }

            NavButton {
                glyph: "chevron_left"
                hover: root.hoverFill
                ink: root.c.text
                onClicked: root.viewed(new Date(root.viewDate.getFullYear(), root.viewDate.getMonth() - 1, 1))
            }

            NavButton {
                glyph: "chevron_right"
                hover: root.hoverFill
                ink: root.c.text
                onClicked: root.viewed(new Date(root.viewDate.getFullYear(), root.viewDate.getMonth() + 1, 1))
            }
        }
    }

    Item {
        id: monthHolder

        anchors.top: head.bottom
        anchors.topMargin: 8
        width: parent.width
        height: parent.height - head.height - 8

        ParallelAnimation {
            id: slide

            NumberAnimation { target: monthHolder; property: "x"; from: root.slideFrom; to: 0; duration: 320; easing.type: Easing.OutCubic }
            NumberAnimation { target: monthHolder; property: "opacity"; from: 0.2; to: 1; duration: 260 }
        }

        Row {
            id: dows

            Repeater {
                model: root.weekdays

                delegate: Item {
                    required property string modelData

                    width: 44
                    height: 24

                    Text {
                        renderType: Text.CurveRendering
                        anchors.centerIn: parent
                        text: parent.modelData
                        color: root.c.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Medium
                    }
                }
            }
        }

        // The current week gets a soft band behind it.
        Rectangle {
            visible: root.onCurrentMonth
            y: grid.y + Math.floor((root.today.getDate() - 1 + new Date(root.today.getFullYear(), root.today.getMonth(), 1).getDay()) / 7) * 42
            width: parent.width
            height: 42
            radius: 14
            color: Qt.rgba(1, 1, 1, 0.04)
        }

        Grid {
            id: grid
            anchors.top: dows.bottom
            columns: 7

            Repeater {
                model: 42

                delegate: Item {
                    id: cell

                    required property int index

                    readonly property date day: new Date(root.gridStart.getFullYear(), root.gridStart.getMonth(),
                                                         root.gridStart.getDate() + index)
                    readonly property bool outside: day.getMonth() !== root.viewDate.getMonth()
                    readonly property bool isToday: day.toDateString() === root.today.toDateString()
                    readonly property bool isSelected: day.toDateString() === root.selected.toDateString()

                    width: 44
                    height: 42

                    Rectangle {
                        y: 1
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 36
                        height: 36
                        radius: 12
                        color: cell.isToday ? root.c.text
                             : cell.isSelected ? root.selectFill
                             : dayArea.containsMouse ? root.hoverFill : "transparent"

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            renderType: Text.CurveRendering
                            anchors.centerIn: parent
                            text: cell.day.getDate()
                            color: cell.isToday ? "#000000" : cell.outside ? "#5C5B60"
                                 : cell.index % 7 === 0 || cell.index % 7 === 6 ? "#A9A7A4" : root.c.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.weight: cell.isToday ? Font.DemiBold : Font.Normal
                        }
                    }

                    // One dot per event, up to three.
                    Row {
                        readonly property int count: Math.min(3, Agenda.eventsOn(cell.day).length)

                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height - 4
                        spacing: 3
                        opacity: cell.outside ? 0.5 : 1

                        Repeater {
                            model: parent.count

                            delegate: Rectangle {
                                width: 4
                                height: 4
                                radius: 2
                                color: "#8AA4D6"
                            }
                        }
                    }

                    MouseArea {
                        id: dayArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.picked(cell.day)
                    }
                }
            }
        }
    }
}
