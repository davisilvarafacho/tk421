
import QtQuick
import QtQuick.Controls
import Quickshell

PanelWindow {
    id: panel

    property real volume: 0.5
    property bool muted: false

    anchors {
        top: true
        right: true
    }

    implicitWidth: 300
    implicitHeight: 150

    color: "transparent"

    Rectangle {
        anchors.fill: parent
        anchors.margins: 8

        radius: 12
        color: "#E6111418"
        border.width: 1
        border.color: "#39414D"

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            Text {
                text: "AUDIO CONTROL"
                color: "#858B95"
                font.family: "Geist"
                font.pixelSize: 10
                font.letterSpacing: 1.2
            }

            Row {
                width: parent.width
                spacing: 10

                Text {
                    text: panel.muted ? "MUTED" :
                          Math.round(panel.volume * 100) + "%"
                    color: "#E8E6E3"
                    font.family: "Geist"
                    font.pixelSize: 12
                    anchors.verticalCenter: parent.verticalCenter
                }

                Slider {
                    id: volumeSlider
                    width: parent.width - 65
                    from: 0
                    to: 1
                    value: panel.volume

                    onMoved: {
                        panel.volume = value
                    }
                }
            }

            Button {
                text: panel.muted ? "Unmute" : "Mute"
                onClicked: panel.muted = !panel.muted
            }
        }
    }
}
