import QtQuick

import "../theme"
import "logic.js" as Logic

// The one bold element: a large thin Orbitron clock straight on the wallpaper (no card), a 60-tick second ruler
// that fills as the minute passes, and the date with the ISO week.
Item {
    id: clock

    property double now: Date.now()
    readonly property var date: new Date(now)

    implicitHeight: col.implicitHeight + 22

    Column {
        id: col

        x: 2
        y: 6
        width: parent.width

        Row {
            Text {
                id: hours

                text: Logic.pad(clock.date.getHours())
                color: Theme.imperial.text
                renderType: Text.CurveRendering
                font.family: Theme.displayFont
                font.weight: Font.Light
                font.pixelSize: 132
            }

            Text {
                text: ":"
                color: Theme.imperial.faint
                renderType: Text.CurveRendering
                font: hours.font
            }

            Text {
                text: Logic.pad(clock.date.getMinutes())
                color: Theme.imperial.text
                renderType: Text.CurveRendering
                font: hours.font
            }
        }

        Item {
            width: 1
            height: 8
        }

        // 60 ticks, every fifth one taller; the current second is the tallest and brightest.
        Item {
            id: ruler

            readonly property int second: clock.date.getSeconds()

            width: 396
            height: 14

            Repeater {
                model: 60

                delegate: Rectangle {
                    required property int index

                    readonly property bool major: index % 5 === 0
                    readonly property bool current: index === ruler.second

                    x: Math.round(index * (ruler.width - 1) / 59)
                    anchors.bottom: parent.bottom
                    width: 1
                    height: current ? 14 : major ? 10 : 6
                    color: current ? Theme.imperial.text
                        : index < ruler.second ? "#6D6B6E"
                        : major ? "#3D3D45" : "#2C2C33"
                }
            }
        }

        Item {
            width: 1
            height: 14
        }

        Row {
            spacing: 14

            Text {
                id: dateText

                text: Logic.dateLine(clock.date)
                color: Theme.imperial.text
                renderType: Text.CurveRendering
                font.family: Theme.fontFamily
                font.pixelSize: 17
            }

            Text {
                anchors.baseline: dateText.baseline
                text: "WEEK " + Logic.isoWeek(clock.date)
                color: Theme.imperial.faint
                renderType: Text.CurveRendering
                font.family: Theme.displayFont
                font.pixelSize: 10
                font.letterSpacing: 2.2
            }
        }
    }
}
