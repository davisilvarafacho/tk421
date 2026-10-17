import QtQuick

import "../services"
import "../theme"

Item {
    id: root

    required property date today
    property date viewDate: today
    property date selected: today

    signal picked(date day)
    signal viewed(date month)

    readonly property var c: Theme.imperial
    readonly property var weekdays: ["S", "M", "T", "W", "T", "F", "S"]   // Sunday-first (Brazil)
    readonly property date gridStart: {
        const first = new Date(viewDate.getFullYear(), viewDate.getMonth(), 1)
        return new Date(first.getFullYear(), first.getMonth(), 1 - first.getDay())
    }
    readonly property bool onCurrentMonth: viewDate.getFullYear() === today.getFullYear()
                                           && viewDate.getMonth() === today.getMonth()

    implicitWidth: 308
    implicitHeight: 278

    component NavButton: Rectangle {
        property string glyph
        signal clicked()

        width: 28
        height: 28
        radius: 8
        color: area.containsMouse ? root.c.surfaceAlt : "transparent"
        border.width: 1
        border.color: area.containsMouse ? root.c.border : "transparent"

        Text {
            renderType: Text.CurveRendering
            anchors.centerIn: parent
            text: parent.glyph
            color: root.c.text
            font.family: Theme.iconFont
            font.pixelSize: 14
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    // Header: month, "Today" shortcut, previous/next.
    Item {
        id: head
        width: parent.width
        height: 32

        Text {
            renderType: Text.CurveRendering
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.locale("en_US").toString(root.viewDate, "MMMM yyyy").toUpperCase()
            color: root.c.text
            font.family: Theme.displayFont
            font.pixelSize: 12
            font.weight: Font.Medium
            font.letterSpacing: 2.2
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Rectangle {
                visible: !root.onCurrentMonth
                width: todayLabel.implicitWidth + 20
                height: 28
                radius: 8
                color: "transparent"
                border.width: 1
                border.color: todayArea.containsMouse ? root.c.accent : root.c.border

                Text {
                    renderType: Text.CurveRendering
                    id: todayLabel
                    anchors.centerIn: parent
                    text: "TODAY"
                    color: todayArea.containsMouse ? root.c.text : root.c.muted
                    font.family: Theme.displayFont
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    font.letterSpacing: 1.7
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
                glyph: "󰅁"
                onClicked: root.viewed(new Date(root.viewDate.getFullYear(), root.viewDate.getMonth() - 1, 1))
            }

            NavButton {
                glyph: "󰅂"
                onClicked: root.viewed(new Date(root.viewDate.getFullYear(), root.viewDate.getMonth() + 1, 1))
            }
        }
    }

    Row {
        id: dows
        anchors.top: head.bottom
        anchors.topMargin: 6

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
                    font.family: Theme.displayFont
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    font.letterSpacing: 1.2
                }
            }
        }
    }

    Grid {
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
                height: 36

                Rectangle {
                    anchors.centerIn: parent
                    width: 32
                    height: 32
                    radius: 16
                    color: cell.isToday ? root.c.text : (dayArea.containsMouse ? root.c.surfaceAlt : "transparent")
                    border.width: cell.isSelected && !cell.isToday ? 1 : 0
                    border.color: root.c.accent

                    Text {
                        renderType: Text.CurveRendering
                        anchors.centerIn: parent
                        text: cell.day.getDate()
                        color: cell.isToday ? root.c.bg : (cell.outside ? root.c.muted : root.c.text)
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: cell.isToday ? Font.DemiBold : Font.Normal
                    }
                }

                Rectangle {
                    visible: Agenda.hasEvents(cell.day)
                    x: (parent.width - width) / 2
                    y: parent.height - height
                    width: 4
                    height: 4
                    radius: 2
                    color: root.c.accent
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
