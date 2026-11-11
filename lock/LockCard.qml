import QtQuick
import QtQuick.Layouts

import "../components"
import "../services"
import "../theme"

Rectangle {
    id: card

    required property var session
    property alias input: login.input

    // 0 hidden, 1 badge, 2 badge widened, 3 fully open
    property int stage: 0
    property bool padlockOpen: false
    property bool closing: false     // direction: opening is slower than closing
    readonly property real badge: 64
    readonly property var c: Theme.imperial
    readonly property bool showSystem: (parent?.width ?? 0) >= 1400

    signal closed()

    function open() {
        closing = false
        closeAnim.stop()
        padlockOpen = false
        stage = 0
        openAnim.restart()
    }

    function close() {
        closing = true
        openAnim.stop()
        closeAnim.restart()
    }

    width: stage >= 2 ? content.implicitWidth : badge
    height: stage >= 3 ? content.implicitHeight : badge
    radius: 2
    color: Qt.rgba(12 / 255, 11 / 255, 13 / 255, 0.94)
    border.width: 1
    border.color: c.border
    clip: true
    opacity: stage >= 1 ? 1 : 0
    scale: stage >= 1 ? 1 : 0.8

    Behavior on width { NumberAnimation { duration: card.closing ? 165 : 510; easing.type: Easing.OutExpo } }
    Behavior on height { NumberAnimation { duration: card.closing ? 165 : 510; easing.type: Easing.OutExpo } }
    Behavior on opacity { NumberAnimation { duration: card.closing ? 170 : 375; easing.type: Easing.OutExpo } }
    Behavior on scale { NumberAnimation { duration: card.closing ? 180 : 410; easing.type: Easing.OutExpo } }

    SequentialAnimation {
        id: openAnim
        PropertyAction { target: card; property: "stage"; value: 1 }
        PauseAnimation { duration: 375 }
        PropertyAction { target: card; property: "stage"; value: 2 }
        PauseAnimation { duration: 375 }
        PropertyAction { target: card; property: "stage"; value: 3 }
        PauseAnimation { duration: 510 }
        ScriptAction { script: card.input.forceActiveFocus() }
    }

    SequentialAnimation {
        id: closeAnim
        PropertyAction { target: card; property: "stage"; value: 2 }
        PauseAnimation { duration: 130 }
        PropertyAction { target: card; property: "stage"; value: 1 }
        PauseAnimation { duration: 150 }
        PropertyAction { target: card; property: "padlockOpen"; value: true }
        PauseAnimation { duration: 322 }
        PropertyAction { target: card; property: "stage"; value: 0 }
        PauseAnimation { duration: 180 }
        ScriptAction { script: card.closed() }
    }

    // Collapsed badge: padlock + status LED.
    Item {
        anchors.centerIn: parent
        width: card.badge
        height: card.badge
        opacity: card.stage >= 3 ? 0 : 1

        Behavior on opacity { NumberAnimation { duration: card.closing ? 170 : 250 } }

        Icon {
            anchors.centerIn: parent
            name: card.padlockOpen ? "lock_open" : "lock"
            color: card.c.text
            size: Theme.iconSize.hero
        }

        Rectangle {
            x: parent.width - 14
            y: 9
            width: 5
            height: 5
            color: card.padlockOpen ? card.c.accent : card.c.danger
        }
    }

    ColumnLayout {
        id: content

        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        spacing: 0
        opacity: card.stage >= 3 ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: card.closing ? 150 : 440 } }

        RowLayout {
            Layout.topMargin: 44
            spacing: 0

            MediaPane {
                visible: Media.present
                Layout.preferredWidth: 400
                Layout.fillHeight: true
            }

            Rectangle {
                visible: Media.present
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                Layout.bottomMargin: 4
                color: card.c.border
            }

            LoginPane {
                id: login
                session: card.session
                Layout.preferredWidth: 660
                Layout.fillHeight: true
            }

            Rectangle {
                visible: card.showSystem
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                Layout.bottomMargin: 4
                color: card.c.border
            }

            SystemPane {
                visible: card.showSystem
                session: card.session
                Layout.preferredWidth: 380
                Layout.fillHeight: true
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 18
            Layout.preferredHeight: 44
            color: "transparent"

            Rectangle {
                width: parent.width
                height: 1
                color: card.c.border
            }

            Rectangle {
                id: led
                anchors.left: parent.left
                anchors.leftMargin: 24
                anchors.verticalCenter: parent.verticalCenter
                width: 6
                height: 6
                color: card.session.status === "authorized" ? card.c.accent
                     : card.session.status === "verifying" ? card.c.muted
                     : card.c.danger

                SequentialAnimation on opacity {
                    running: card.session.status === "verifying"
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.25; duration: 350 }
                    NumberAnimation { to: 1; duration: 350 }
                }
            }

            Text {
                anchors.left: led.right
                anchors.leftMargin: 9
                anchors.verticalCenter: parent.verticalCenter
                text: ({ locked: "Locked", verifying: "Verifying", denied: "Denied", authorized: "Authorized" })[card.session.status]
                color: card.c.text
                font.family: Theme.displayFont
                font.pixelSize: 11
                font.weight: Font.Medium
                font.letterSpacing: 2.2
                font.capitalization: Font.AllUppercase
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 24
                anchors.verticalCenter: parent.verticalCenter
                text: "tk421"
                color: card.c.muted
                font.family: Theme.displayFont
                font.pixelSize: 11
                font.weight: Font.Medium
                font.letterSpacing: 2.2
                font.capitalization: Font.AllUppercase
            }
        }
    }

    // Targeting-frame corners.
    Item {
        anchors.fill: parent
        anchors.margins: 8
        anchors.bottomMargin: 52
        opacity: card.stage >= 3 ? 0.85 : 0

        Behavior on opacity { NumberAnimation { duration: card.closing ? 220 : 510 } }

        Repeater {
            model: 4

            delegate: Item {
                required property int index
                readonly property bool atRight: index % 2 === 1
                readonly property bool atBottom: index >= 2

                width: 12
                height: 12
                x: atRight ? parent.width - 12 : 0
                y: atBottom ? parent.height - 12 : 0

                Rectangle { width: 12; height: 1; y: parent.atBottom ? 11 : 0; color: card.c.accent }
                Rectangle { width: 1; height: 12; x: parent.atRight ? 11 : 0; color: card.c.accent }
            }
        }
    }
}
