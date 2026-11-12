import QtQuick

import "../services"
import "../theme"
import "logic.js" as Logic

// Today and tomorrow from services/Agenda.qml. Finished events dim, the next one gets a bright edge mark and
// an "in N min" note. Titles come from calendar invites (strangers can send them): plain text only.
WidgetPanel {
    id: w

    property double now: Date.now()
    readonly property var days: Logic.agendaDays(Agenda.events, now, 3)   // 3 per day keeps the right column on screen
    readonly property int week: Logic.weekCount(Agenda.events, now)

    label: "Agenda"
    aside: Agenda.status === "unconfigured" ? "not set up"
        : Agenda.status === "error" ? "sync failed"
        : week === 0 ? "" : week === 1 ? "1 event this week" : week + " events this week"

    Text {
        visible: w.days.length === 0
        width: parent.width
        text: "Nothing on the calendar today or tomorrow."
        color: Theme.imperial.muted
        renderType: Text.CurveRendering
        font.family: Theme.fontFamily
        font.pixelSize: 13
    }

    Repeater {
        model: w.days

        delegate: Column {
            id: day

            required property var modelData
            required property int index

            width: w.width - 40
            topPadding: index > 0 ? 16 : 0

            Text {
                text: day.modelData.label
                color: Theme.imperial.faint
                renderType: Text.CurveRendering
                font.family: Theme.fontFamily
                font.pixelSize: 11
                bottomPadding: 2
            }

            Repeater {
                model: day.modelData.rows

                delegate: Item {
                    id: row

                    required property var modelData

                    readonly property bool done: modelData.state === "done"
                    readonly property bool next: modelData.state === "next"
                    readonly property bool hasNote: next && modelData.note !== ""

                    width: day.width
                    height: (hasNote ? 34 : 18) + 12

                    // The next event's mark sits on the panel's left edge.
                    Rectangle {
                        visible: row.next
                        x: -20
                        y: 7
                        width: 2
                        height: parent.height - 14
                        radius: 1
                        color: Theme.imperial.text
                    }

                    Text {
                        y: 8
                        width: 74
                        text: row.modelData.time
                        textFormat: Text.PlainText
                        color: row.done ? Theme.imperial.faint : Theme.imperial.muted
                        renderType: Text.CurveRendering
                        font.family: Theme.displayFont
                        font.pixelSize: 11
                        font.letterSpacing: 0.4
                    }

                    Column {
                        x: 86
                        y: 6
                        width: parent.width - 86

                        Text {
                            width: parent.width
                            text: row.modelData.title
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: row.done ? Theme.imperial.faint : Theme.imperial.text
                            renderType: Text.CurveRendering
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                        }

                        Text {
                            visible: row.hasNote
                            width: parent.width
                            text: row.modelData.note
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: Theme.imperial.faint
                            renderType: Text.CurveRendering
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }
    }
}
