import QtQuick
import QtQuick.Effects

import "../components"
import "../services"
import "../theme"
import "logic.js" as Logic

// The current MPRIS player (services/Media.qml): grey cover, title, artist, transport and progress.
// The transport row is the only part of the desktop widgets that takes clicks (`controls`, the window's mask).
WidgetPanel {
    id: w

    readonly property alias controls: controls

    label: "Now playing"

    component Transport: Rectangle {
        id: b

        property string icon: ""
        signal clicked()

        width: 30
        height: 26
        radius: 8
        color: area.containsMouse ? Theme.imperial.surfaceAlt : "transparent"

        Behavior on color { ColorAnimation { duration: 140 } }

        Icon {
            anchors.centerIn: parent
            name: b.icon
            size: Theme.iconSize.panel
            color: area.containsMouse ? Theme.imperial.text : "#B5BAC3"
        }

        MouseArea {
            id: area

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: b.clicked()
        }
    }

    Item {
        width: parent.width
        height: 76

        Rectangle {
            id: cover

            width: 76
            height: 76
            radius: 10
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0; color: "#3A3A40" }
                GradientStop { position: 1; color: "#121215" }
            }

            Image {
                id: art

                anchors.fill: parent
                source: Media.art
                sourceSize: Qt.size(152, 152)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
            }

            // Grey and rounded, like the prototype: one colour-free desktop.
            MultiEffect {
                anchors.fill: parent
                source: art
                visible: art.status === Image.Ready
                saturation: -1
                maskEnabled: true
                maskSource: coverMask
            }

            Item {
                id: coverMask

                anchors.fill: parent
                layer.enabled: true
                visible: false

                Rectangle {
                    anchors.fill: parent
                    radius: 10
                }
            }
        }

        Column {
            x: 92
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 92

            Text {
                width: parent.width
                text: Media.title !== "" ? Media.title : "Unknown track"
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Theme.imperial.text
                renderType: Text.CurveRendering
                font.family: Theme.fontFamily
                font.weight: Font.Medium
                font.pixelSize: 15
            }

            Text {
                width: parent.width
                topPadding: 3
                text: Media.artist
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Theme.imperial.muted
                renderType: Text.CurveRendering
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }

            Item { width: 1; height: 10 }

            Item {
                width: parent.width
                height: 26

                Row {
                    id: controls

                    x: -6
                    spacing: 4

                    Transport {
                        icon: "skip_previous"
                        onClicked: Media.previous()
                    }

                    Transport {
                        icon: Media.playing ? "pause" : "play_arrow"
                        onClicked: Media.toggle()
                    }

                    Transport {
                        icon: "skip_next"
                        onClicked: Media.next()
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, parent.width - controls.width - 12)
                    text: Media.source
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

    Item { width: 1; height: 14 }

    Item {
        width: parent.width
        height: 12
        visible: Media.length > 0

        Text {
            id: posText

            anchors.verticalCenter: parent.verticalCenter
            text: Logic.clock(Media.position)
            color: Theme.imperial.faint
            renderType: Text.CurveRendering
            font.family: Theme.displayFont
            font.pixelSize: 10
        }

        Text {
            id: lenText

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: Logic.clock(Media.length)
            color: Theme.imperial.faint
            renderType: Text.CurveRendering
            font.family: Theme.displayFont
            font.pixelSize: 10
        }

        Rectangle {
            anchors.left: posText.right
            anchors.leftMargin: 10
            anchors.right: lenText.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            height: 3
            radius: 1.5
            color: "#1F1F25"

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, Media.position / Math.max(1, Media.length)))
                height: parent.height
                radius: 1.5
                color: "#B9B6B2"
            }
        }
    }
}
