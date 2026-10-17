import QtQuick
import QtQuick.Shapes

import "../services"
import "../theme"
import "logic.js" as Logic

// The transition effect as one button: click it, or scroll the mouse wheel over it, to change the effect. The name slides in the
// direction of the change. Changing the effect does not touch the desktop: it applies to the next wallpaper change.
Item {
    id: btn

    property real u: 1
    property color steel: "#B9B6B2"
    property color steelText: "#F2F0ED"
    property color edge: "#3F3E44"

    readonly property string effect: Wallpaper.effect
    property string label: Logic.LABELS[effect] || ""
    property string previous: effect
    property real wheelAcc: 0

    width: 236 * u
    height: 28 * u

    onEffectChanged: {
        swap.dir = Logic.effectDirection(previous, effect)
        previous = effect
        swap.restart()
    }

    SequentialAnimation {
        id: swap

        property int dir: 1

        ParallelAnimation {
            NumberAnimation { target: name; property: "opacity"; to: 0; duration: 80 }
            NumberAnimation { target: name; property: "shift"; to: -swap.dir * 7 * btn.u; duration: 80 }
        }

        ScriptAction {
            script: {
                btn.label = Logic.LABELS[btn.effect] || ""
                name.shift = swap.dir * 7 * btn.u
            }
        }

        ParallelAnimation {
            NumberAnimation { target: name; property: "opacity"; to: 1; duration: 180 }
            NumberAnimation { target: name; property: "shift"; to: 0; duration: 220; easing.type: Easing.OutCubic }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: 1
        border.color: mouse.containsMouse ? btn.steel : btn.edge

        Behavior on border.color { ColorAnimation { duration: 160 } }
    }

    Item {
        id: slot

        x: 14 * btn.u
        width: btn.width - 54 * btn.u
        height: btn.height
        clip: true

        Text {
            id: name

            property real shift: 0

            y: (slot.height - height) / 2 + shift
            text: btn.label
            color: btn.steelText
            textFormat: Text.PlainText
            font.family: Theme.displayFont
            font.pixelSize: 12 * btn.u
            font.weight: Font.Medium
            font.letterSpacing: 2.6 * btn.u
            renderType: Text.CurveRendering
        }
    }

    // Two chevrons: the button turns both ways.
    Repeater {
        model: 2

        Shape {
            id: chev

            required property int index
            readonly property real w: 12 * btn.u
            readonly property real h: 6 * btn.u

            x: btn.width - 26 * btn.u
            y: (index === 0 ? 5 : 17) * btn.u
            width: w
            height: h
            layer.enabled: true
            layer.samples: 4

            ShapePath {
                strokeColor: mouse.containsMouse ? btn.steelText : btn.steel
                strokeWidth: 1.2
                fillColor: "transparent"
                joinStyle: ShapePath.MiterJoin

                PathPolyline {
                    path: chev.index === 0
                        ? [Qt.point(0, chev.h), Qt.point(chev.w / 2, 0), Qt.point(chev.w, chev.h)]
                        : [Qt.point(0, 0), Qt.point(chev.w / 2, chev.h), Qt.point(chev.w, 0)]
                }
            }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Wallpaper.cycleEffect(1)

        // Scroll down for the next effect, up for the previous. (MouseArea, not WheelHandler: the handler never fires here.)
        onWheel: wheel => {
            const r = Logic.wheelStep(btn.wheelAcc, wheel.angleDelta.y)
            btn.wheelAcc = r.acc
            for (let i = 0; i < Math.abs(r.steps); i++)
                Wallpaper.cycleEffect(r.steps > 0 ? 1 : -1)
        }
    }
}
