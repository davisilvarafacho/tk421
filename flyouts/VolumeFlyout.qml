import Quickshell
import Quickshell.Wayland
import QtQuick

import "../services"
import "../theme"

PanelWindow {
    id: flyout

    property bool shown: false

    anchors.bottom: true
    margins.bottom: 60

    implicitWidth: 260
    implicitHeight: 56
    visible: shown || card.opacity > 0
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "tk421-flyout"
    exclusionMode: ExclusionMode.Ignore

    // Empty input region: clicks pass through to windows below.
    mask: Region {}

    function icon() {
        if (Audio.muted || Audio.volume <= 0) return "󰖁"
        if (Audio.volume < 0.34) return "󰕿"
        if (Audio.volume < 0.67) return "󰖀"
        return "󰕾"
    }

    Connections {
        target: Audio
        function onChanged() {
            flyout.shown = true
            hideTimer.restart()
        }
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: flyout.shown = false
    }

    Rectangle {
        id: card

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: flyout.shown ? 0 : 8
        width: parent.width
        height: parent.height
        radius: 14
        color: Theme.background
        border.width: 1
        border.color: Theme.border
        opacity: flyout.shown ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 150 } }
        Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        Row {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            Text {
                width: 20
                text: flyout.icon()
                color: Audio.muted ? Theme.muted : Theme.text
                font.family: Theme.iconFont
                font.pixelSize: 20
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                width: parent.width - 20 - 12 * 2 - 40
                height: 6
                radius: 3
                color: Theme.border
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, Audio.volume))
                    height: parent.height
                    radius: 3
                    color: Audio.muted ? Theme.muted : Theme.text
                }
            }

            Text {
                width: 40
                horizontalAlignment: Text.AlignRight
                text: Audio.muted ? "MUTE" : Math.round(Audio.volume * 100) + "%"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
