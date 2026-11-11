import QtQuick
import QtQuick.Layouts
import Quickshell

import "../components"
import "../theme"

ColumnLayout {
    id: root

    required property var session
    property alias input: field

    readonly property var c: Theme.imperial

    spacing: 0

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Item { Layout.fillHeight: true }

    Text {
        Layout.alignment: Qt.AlignHCenter
        text: Qt.formatTime(clock.date, "HH:mm")
        color: root.c.text
        font.family: Theme.displayFont
        font.pixelSize: 88
        font.weight: Font.Medium
        font.letterSpacing: 1.5
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 14
        text: Qt.locale("en_US").toString(clock.date, "dddd • d MMM").toUpperCase()
        color: root.c.muted
        font.family: Theme.displayFont
        font.pixelSize: 11
        font.weight: Font.Medium
        font.letterSpacing: 2.4
    }

    Rectangle {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 32
        Layout.preferredWidth: 84
        Layout.preferredHeight: 84
        radius: 2
        color: root.c.surfaceAlt
        border.width: 1
        border.color: root.c.border

        Image {
            anchors.centerIn: parent
            width: 62
            height: 62
            source: Qt.resolvedUrl("../assets/helmet.svg")
            sourceSize: Qt.size(124, 124)
            smooth: true
        }
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 12
        text: "TK-421"
        color: root.c.text
        font.family: Theme.displayFont
        font.pixelSize: 13
        font.weight: Font.Medium
        font.letterSpacing: 2.3
    }

    Rectangle {
        id: box

        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 26
        Layout.preferredWidth: 380
        Layout.preferredHeight: 50
        radius: 2
        color: root.c.surfaceAlt
        border.width: 1
        border.color: root.session.status === "denied" ? root.c.danger
                    : field.activeFocus ? root.c.accent : root.c.border

        transform: Translate { id: shift }

        SequentialAnimation {
            id: shake
            NumberAnimation { target: shift; property: "x"; to: -9; duration: 70 }
            NumberAnimation { target: shift; property: "x"; to: 8; duration: 80 }
            NumberAnimation { target: shift; property: "x"; to: -5; duration: 80 }
            NumberAnimation { target: shift; property: "x"; to: 3; duration: 70 }
            NumberAnimation { target: shift; property: "x"; to: 0; duration: 60 }
        }

        Icon {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            name: "lock"
            color: root.c.muted
            size: Theme.iconSize.panel
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 44
            anchors.verticalCenter: parent.verticalCenter
            visible: field.text.length === 0
            text: "Password"
            color: root.c.muted
            font.family: Theme.fontFamily
            font.pixelSize: 16
        }

        TextInput {
            id: field

            anchors.left: parent.left
            anchors.right: go.left
            anchors.leftMargin: 44
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter

            enabled: root.session.status !== "verifying" && root.session.status !== "authorized"
            echoMode: TextInput.Password
            passwordCharacter: "•"
            color: root.c.text
            selectionColor: root.c.accentDim
            selectedTextColor: root.c.text
            font.family: Theme.fontFamily
            font.pixelSize: 16
            clip: true


            onAccepted: root.session.submit(text)
            onTextChanged: root.session.clearError()
        }

        Rectangle {
            id: go

            anchors.right: parent.right
            anchors.rightMargin: 7
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            height: 36
            radius: 2
            color: goArea.containsMouse ? "#FFFFFF" : root.c.text
            visible: field.text.length > 0

            Icon {
                anchors.centerIn: parent
                name: root.session.status === "verifying" ? "refresh" : "arrow_forward"
                color: root.c.bg
                size: Theme.iconSize.panel
            }

            MouseArea {
                id: goArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.session.submit(field.text)
            }
        }
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 12
        Layout.preferredHeight: 20
        text: root.session.message
        color: root.session.messageIsError ? root.c.dangerText : root.c.muted
        font.family: Theme.fontFamily
        font.pixelSize: 14
    }

    Item { Layout.fillHeight: true }

    Connections {
        target: root.session

        function onStatusChanged() {
            if (root.session.status === "denied") {
                field.text = ""
                shake.restart()
                field.forceActiveFocus()
            }
        }
    }
}
