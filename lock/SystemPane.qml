import QtQuick
import QtQuick.Layouts
import Quickshell.Io

import "../services"
import "../theme"

ColumnLayout {
    id: root

    required property var session

    readonly property var c: Theme.imperial

    property int notifications: 0
    property real uptimeSeconds: 0

    function uptimeText() {
        const m = Math.floor(uptimeSeconds / 60)
        return Math.floor(m / 60) + "h " + String(m % 60).padStart(2, "0") + "m"
    }

    component Heading: Item {
        property alias text: label.text

        Layout.fillWidth: true
        Layout.leftMargin: 44
        Layout.rightMargin: 48
        Layout.preferredHeight: 28

        Text {
            id: label
            color: root.c.muted
            font.family: Theme.displayFont
            font.pixelSize: 11
            font.weight: Font.Medium
            font.letterSpacing: 2.4
            font.capitalization: Font.AllUppercase
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: root.c.border
        }
    }

    component Metric: RowLayout {
        property string name
        property real value

        Layout.fillWidth: true
        Layout.leftMargin: 44
        Layout.rightMargin: 48
        Layout.preferredHeight: 28
        spacing: 12

        Text {
            Layout.preferredWidth: 44
            text: parent.name
            color: root.c.muted
            font.family: Theme.displayFont
            font.pixelSize: 11
            font.letterSpacing: 1.5
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 3
            color: root.c.border

            Rectangle {
                height: parent.height
                width: parent.width * Math.max(0, Math.min(1, parent.parent.value / 100))
                color: parent.parent.value > 85 ? root.c.danger : root.c.accent

                Behavior on width { NumberAnimation { duration: 700; easing.type: Easing.OutExpo } }
            }
        }

        Text {
            Layout.preferredWidth: 36
            horizontalAlignment: Text.AlignRight
            text: Math.round(parent.value) + "%"
            color: root.c.text
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }
    }

    component Row2: RowLayout {
        property string name
        property string value
        property color valueColor: root.c.text

        Layout.fillWidth: true
        Layout.leftMargin: 44
        Layout.rightMargin: 48
        Layout.preferredHeight: 28

        Text {
            text: parent.name
            color: root.c.muted
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }

        Item { Layout.fillWidth: true }

        Text {
            text: parent.value
            color: parent.valueColor
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }
    }

    spacing: 0

    SystemStats { id: stats }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        blockLoading: true
    }

    Process {
        id: swaync
        command: ["swaync-client", "-c"]
        stdout: StdioCollector {
            onStreamFinished: root.notifications = parseInt(text) || 0
        }
    }

    Timer {
        interval: 15000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            uptimeFile.reload()
            uptimeFile.waitForJob()
            root.uptimeSeconds = Number(uptimeFile.text().split(" ")[0]) || 0
            swaync.running = true
        }
    }

    Item { Layout.fillHeight: true }

    Heading { text: "System" }
    Item { Layout.preferredHeight: 6 }
    Metric { name: "CPU"; value: stats.cpuPercent }
    Metric { name: "RAM"; value: stats.ramPercent }
    Metric { name: "GPU"; value: stats.gpuPercent }
    Metric { name: "VRAM"; value: stats.vramPercent }

    Item { Layout.preferredHeight: 22 }

    Heading { text: "Session" }
    Item { Layout.preferredHeight: 6 }
    Row2 { name: "Uptime"; value: root.uptimeText() }
    Row2 { name: "Locked since"; value: Qt.formatTime(root.session.lockedSince, "HH:mm") }
    Row2 {
        name: "Failed attempts"
        value: String(root.session.failed)
        valueColor: root.session.failed > 0 ? root.c.dangerText : root.c.text
    }

    Item { Layout.preferredHeight: 22 }

    Heading { text: "Notifications" }
    Item { Layout.preferredHeight: 6 }
    Row2 { name: "Pending"; value: String(root.notifications) }

    Text {
        Layout.leftMargin: 44
        Layout.topMargin: 4
        text: "Content hidden while locked"
        color: root.c.muted
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }

    Item { Layout.fillHeight: true }
}
