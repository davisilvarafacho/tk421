import QtQuick

import "../components"
import "../services"
import "../theme"

// Media tab of the island card: art, title, artist, progress and transport controls of the active player.
Item {
    id: root

    readonly property var c: Theme.imperial

    implicitWidth: 764
    implicitHeight: 318

    function fmt(seconds) {
        const s = Math.max(0, Math.floor(seconds))
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0")
    }

    // A round transport button. The item is as wide as its disc and 60 px tall, so a Row spaces the discs evenly
    // and every disc sits on the same centre line.
    component Transport: Item {
        id: button

        property string glyph
        property bool primary: false
        signal clicked()

        width: primary ? 60 : 46
        height: 60

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: button.width
            height: width
            radius: width / 2
            color: button.primary ? (area.containsMouse ? "#FFFFFF" : root.c.text)
                                  : (area.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07))
            scale: area.pressed ? 0.94 : 1

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on scale { NumberAnimation { duration: 90 } }

            Icon {
                anchors.centerIn: parent
                name: button.glyph
                size: button.primary ? 26 : 20
                color: button.primary ? "#000000" : root.c.text
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: button.clicked()
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: Media.present

        Rectangle {
            id: art

            y: 15
            width: 288
            height: 288
            radius: 20
            color: root.c.surfaceAlt
            clip: true
            opacity: Media.playing ? 1 : 0.55      // paused reads as paused

            Behavior on opacity { NumberAnimation { duration: 240 } }

            Image {
                id: artImage
                anchors.fill: parent
                anchors.margins: 1
                source: Media.art
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }

            Text {
                renderType: Text.CurveRendering
                anchors.centerIn: parent
                visible: artImage.status !== Image.Ready
                text: "󰎆"
                color: root.c.border
                font.family: Theme.iconFont
                font.pixelSize: 64
            }
        }

        Item {
            id: info

            x: art.width + 36
            y: art.y
            width: parent.width - x
            height: art.height

            Column {
                width: parent.width
                spacing: 6

                Text {
                    renderType: Text.CurveRendering
                    width: parent.width
                    text: Media.title
                    textFormat: Text.PlainText
                    color: root.c.text
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    font.family: Theme.displayFont
                    font.pixelSize: 20
                    font.weight: Font.Medium
                    font.letterSpacing: 0.6
                }

                Text {
                    renderType: Text.CurveRendering
                    width: parent.width
                    text: Media.artist + (Media.source ? "  ·  " + Media.source : "")
                    textFormat: Text.PlainText
                    color: root.c.muted
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                }
            }

            // Progress and controls hang from the bottom edge, level with the art.
            Column {
                anchors.bottom: parent.bottom
                width: parent.width
                spacing: 8

                Rectangle {
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Qt.rgba(1, 1, 1, 0.14)

                    Rectangle {
                        height: parent.height
                        radius: 2
                        width: Media.length > 0 ? parent.width * Math.min(1, Media.position / Media.length) : 0
                        color: root.c.text
                    }
                }

                Item {
                    width: parent.width
                    height: timeLeft.implicitHeight

                    Text {
                        id: timeLeft
                        renderType: Text.CurveRendering
                        text: root.fmt(Media.position)
                        color: root.c.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    Text {
                        renderType: Text.CurveRendering
                        anchors.right: parent.right
                        text: Media.length > 0 ? root.fmt(Media.length) : ""
                        color: root.c.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                }

                Item { width: 1; height: 8 }

                // Centred under the progress bar: the Row sits in a plain Item, so it can be centred with anchors.
                Item {
                    width: parent.width
                    height: 60

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 14

                        Transport { glyph: "skip_previous"; onClicked: Media.previous() }
                        Transport { glyph: Media.playing ? "pause" : "play_arrow"; primary: true; onClicked: Media.toggle() }
                        Transport { glyph: "skip_next"; onClicked: Media.next() }
                    }
                }
            }
        }
    }

    // Empty state: dimmed icon and label, centred (same as the calendar's).
    Column {
        anchors.centerIn: parent
        visible: !Media.present
        spacing: 10
        opacity: 0.45

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: "music_note"
            size: 34
            color: root.c.muted
        }

        Text {
            renderType: Text.CurveRendering
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Nothing playing"
            color: root.c.muted
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }
    }
}
