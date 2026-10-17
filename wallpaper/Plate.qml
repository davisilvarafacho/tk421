import QtQuick

import "../services"
import "logic.js" as Logic

// One wallpaper in the bay. Position, scale and opacity follow its distance from the selection; only the nearest plates keep their
// image decoded. An image that cannot be decoded drops out of the bay.
Item {
    id: plate

    required property int index
    required property string modelData       // absolute path
    property real u: 1
    property int selected: 0
    property int count: 1
    property bool revealed: false            // false while the door is shut; true: the plates fade in from the centre outwards
    property color steel: "#B9B6B2"
    property color steelText: "#F2F0ED"
    property color edge: "#3F3E44"

    readonly property int off: Logic.offset(index, selected, count)
    readonly property var place: Logic.slot(off)
    readonly property bool current: off === 0
    property real fadeIn: revealed ? 1 : 0
    property real slotScale: place.scale

    width: 400 * u
    height: 225 * u
    x: parent.width / 2 - width / 2 + place.x * u
    y: parent.height / 2 - height / 2
    scale: slotScale * (0.92 + 0.08 * fadeIn)
    opacity: place.opacity * fadeIn
    z: 10 - Math.abs(off)
    visible: opacity > 0.01

    Behavior on x { Ease { duration: 560 } }
    Behavior on slotScale { Ease { duration: 560 } }

    Behavior on fadeIn {
        SequentialAnimation {
            PauseAnimation { duration: plate.revealed ? Math.abs(plate.off) * 70 + 460 : 0 }
            NumberAnimation { duration: 420 }
        }
    }

    Image {
        anchors.fill: parent
        source: Logic.isNear(plate.off) ? Logic.fileUrl(plate.modelData) : ""
        sourceSize.width: 480
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true

        onStatusChanged: {
            if (status === Image.Error)
                Wallpaper.drop(plate.modelData)
        }
    }

    // Plates that are not selected are dimmed.
    Rectangle {
        anchors.fill: parent
        color: "#050505"
        opacity: plate.current ? 0 : 0.38

        Behavior on opacity { NumberAnimation { duration: 420 } }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: 1
        border.color: plate.current ? plate.steel : plate.edge

        Behavior on border.color { ColorAnimation { duration: 200 } }
    }

    // Corner brackets on the selected plate.
    Item {
        anchors.fill: parent
        opacity: plate.current ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 260 } }

        Repeater {
            model: 4

            Item {
                id: corner

                required property int index
                readonly property bool atLeft: index % 2 === 0
                readonly property bool atTop: index < 2

                x: atLeft ? -9 * plate.u : plate.width + 9 * plate.u - width
                y: atTop ? -9 * plate.u : plate.height + 9 * plate.u - height
                width: 14 * plate.u
                height: width

                Rectangle {
                    y: corner.atTop ? 0 : corner.height - 1
                    width: corner.width
                    height: 1
                    color: plate.steelText
                }

                Rectangle {
                    x: corner.atLeft ? 0 : corner.width - 1
                    width: 1
                    height: corner.height
                    color: plate.steelText
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Wallpaper.select(plate.index)
    }
}
