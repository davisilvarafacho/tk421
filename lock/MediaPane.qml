import QtQuick
import QtQuick.Layouts

import "../components"
import "../services"
import "../theme"

ColumnLayout {
    id: root

    readonly property var c: Theme.imperial

    function fmt(seconds) {
        const s = Math.max(0, Math.floor(seconds))
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0")
    }

    component Btn: Rectangle {
        id: btn

        property string glyph
        property bool primary: false
        property bool enabledControl: true
        signal clicked()

        implicitWidth: primary ? 52 : 40
        implicitHeight: 40
        radius: 2
        color: primary ? root.c.text : "transparent"
        border.width: 1
        border.color: primary ? root.c.text : (area.containsMouse ? root.c.accent : root.c.border)
        opacity: enabledControl ? 1 : 0.4

        Icon {
            anchors.centerIn: parent
            name: btn.glyph
            color: btn.primary ? root.c.bg : root.c.text
            size: 18
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            enabled: btn.enabledControl
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    spacing: 0

    Item { Layout.fillHeight: true }

    Rectangle {
        Layout.leftMargin: 48
        Layout.rightMargin: 44
        Layout.fillWidth: true
        Layout.preferredHeight: 308
        radius: 2
        color: root.c.surfaceAlt
        border.width: 1
        border.color: root.c.border
        clip: true

        Image {
            id: art
            anchors.fill: parent
            anchors.margins: 1
            source: Media.art
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
        }

        Icon {
            anchors.centerIn: parent
            visible: art.status !== Image.Ready
            name: "music_note"
            color: root.c.border
            size: 72
        }
    }

    RowLayout {
        Layout.leftMargin: 48
        Layout.rightMargin: 44
        Layout.topMargin: 18
        Layout.fillWidth: true
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            Text {
                Layout.fillWidth: true
                text: Media.title
                textFormat: Text.PlainText
                color: root.c.text
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: 17
                font.weight: Font.DemiBold
            }

            Text {
                Layout.fillWidth: true
                text: Media.artist
                textFormat: Text.PlainText
                color: root.c.muted
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: 14
            }
        }

        Text {
            text: Media.source.toUpperCase()
            textFormat: Text.PlainText
            color: root.c.muted
            font.family: Theme.displayFont
            font.pixelSize: 11
            font.weight: Font.Medium
            font.letterSpacing: 2
        }
    }

    Rectangle {
        Layout.leftMargin: 48
        Layout.rightMargin: 44
        Layout.topMargin: 18
        Layout.fillWidth: true
        Layout.preferredHeight: 3
        color: root.c.border

        Rectangle {
            height: parent.height
            width: Media.length > 0 ? parent.width * Math.min(1, Media.position / Media.length) : 0
            color: root.c.accent
        }
    }

    RowLayout {
        Layout.leftMargin: 48
        Layout.rightMargin: 44
        Layout.topMargin: 8
        Layout.fillWidth: true

        Text {
            text: root.fmt(Media.position)
            color: root.c.muted
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }

        Item { Layout.fillWidth: true }

        Text {
            text: Media.length > 0 ? root.fmt(Media.length) : ""
            color: root.c.muted
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }
    }

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        Layout.leftMargin: 4
        Layout.topMargin: 16
        spacing: 8

        Btn { glyph: "skip_previous"; onClicked: Media.previous() }
        Btn { glyph: Media.playing ? "pause" : "play_arrow"; primary: true; onClicked: Media.toggle() }
        Btn { glyph: "skip_next"; onClicked: Media.next() }
    }

    Item { Layout.fillHeight: true }
}
