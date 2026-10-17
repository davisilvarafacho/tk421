import QtQuick

import "../services"
import "../theme"

// Media tab of the island card: art, title, artist, progress and transport controls of the active player.
// Prototype: prototypes/island-media-tab/index.html
Item {
    id: root

    readonly property var c: Theme.imperial

    implicitWidth: 692
    implicitHeight: 300

    function fmt(seconds) {
        const s = Math.max(0, Math.floor(seconds))
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0")
    }

    component Transport: Rectangle {
        property string glyph
        property bool primary: false
        signal clicked()

        width: primary ? 52 : 40
        height: 40
        radius: 8
        color: primary ? root.c.text : "transparent"
        border.width: 1
        border.color: primary ? root.c.text : (area.containsMouse ? root.c.accent : root.c.border)

        Text {
            renderType: Text.CurveRendering
            anchors.centerIn: parent
            text: parent.glyph
            color: parent.primary ? root.c.bg : root.c.text
            font.family: Theme.iconFont
            font.pixelSize: 18
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    Item {
        anchors.fill: parent
        visible: Media.present

        Rectangle {
            id: art

            y: 32
            width: 236
            height: 236
            radius: 12
            color: root.c.surfaceAlt
            border.width: 1
            border.color: root.c.border
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
                    font.family: Theme.fontFamily
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                }

                Text {
                    renderType: Text.CurveRendering
                    width: parent.width
                    text: Media.artist + (Media.source ? " · " + Media.source : "")
                    textFormat: Text.PlainText
                    color: root.c.muted
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                }
            }

            // Progress and controls hang from the bottom edge, level with the art.
            Column {
                id: bottom

                anchors.bottom: parent.bottom
                width: parent.width
                spacing: 8

                Rectangle {
                    width: parent.width
                    height: 3
                    color: root.c.border

                    Rectangle {
                        height: parent.height
                        width: Media.length > 0 ? parent.width * Math.min(1, Media.position / Media.length) : 0
                        color: root.c.accent
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

                Item { width: 1; height: 10 }

                Row {
                    spacing: 8

                    Transport { glyph: "󰒮"; onClicked: Media.previous() }
                    Transport { glyph: Media.playing ? "󰏤" : "󰐊"; primary: true; onClicked: Media.toggle() }
                    Transport { glyph: "󰒭"; onClicked: Media.next() }
                }
            }
        }
    }

    // Empty state: dimmed icon and label, centred (same as the agenda's).
    Column {
        anchors.centerIn: parent
        visible: !Media.present
        spacing: 10
        opacity: 0.45

        Text {
            renderType: Text.CurveRendering
            anchors.horizontalCenter: parent.horizontalCenter
            text: "󰎆"
            color: root.c.muted
            font.family: Theme.iconFont
            font.pixelSize: 34
        }

        Text {
            renderType: Text.CurveRendering
            anchors.horizontalCenter: parent.horizontalCenter
            text: "no media..."
            color: root.c.muted
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }
    }
}
