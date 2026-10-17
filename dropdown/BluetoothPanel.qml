import Quickshell
import QtQuick

import "../components"
import "../services"
import "../theme"

// Bluetooth dropdown: the adapter switch, Scan, the paired devices (connect, disconnect, battery) and nearby devices to
// pair. State: services/Bt.qml. Prototype: prototypes/toolbar/index.html.
Item {
    id: panel

    readonly property var c: Theme.imperial

    readonly property real bodyHeight: Math.min(column.implicitHeight, 400)

    implicitHeight: 48 + bodyHeight + 10

    Text {
        id: title

        x: 16
        y: 2 + (46 - height) / 2
        text: "Bluetooth"
        color: panel.c.text
        renderType: Text.CurveRendering
        font.family: Theme.displayFont
        font.pixelSize: 11
        font.letterSpacing: 2.2
        font.capitalization: Font.AllUppercase
    }

    // Switch: thin outline, accent when on.
    Rectangle {
        id: sw

        x: parent.width - 16 - width
        y: 2 + (46 - height) / 2
        width: 30
        height: 16
        radius: 8
        color: Bt.powered ? panel.c.accentDim : "transparent"
        border.width: 1
        border.color: Bt.powered ? panel.c.accent : panel.c.border

        Behavior on color {
            ColorAnimation { duration: 160 }
        }

        Rectangle {
            x: Bt.powered ? 16 : 3
            anchors.verticalCenter: parent.verticalCenter
            width: 10
            height: 10
            radius: 5
            color: Bt.powered ? panel.c.text : panel.c.muted

            Behavior on x {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Bt.setPowered(!Bt.powered)
        }
    }

    ActionButton {
        visible: Bt.powered
        x: sw.x - 6 - width
        y: 2 + (46 - height) / 2
        text: Bt.scanning ? "Scanning…" : "Scan"
        enabled: !Bt.scanning
        opacity: enabled ? 1 : 0.6
        onClicked: Bt.scan()
    }

    component Section: Item {
        id: section

        property string label: ""

        width: column.width
        height: 28

        Text {
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 6
            text: section.label
            color: panel.c.muted
            renderType: Text.CurveRendering
            font.family: Theme.displayFont
            font.pixelSize: 9
            font.letterSpacing: 1.8
            font.capitalization: Font.AllUppercase
        }
    }

    component DeviceRow: Item {
        id: row

        required property var modelData
        property string action: ""
        signal clicked()

        width: column.width
        height: 44

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.91, 0.9, 0.89, 0.035)
            opacity: area.containsMouse ? 1 : 0

            Behavior on opacity {
                NumberAnimation { duration: 120 }
            }
        }

        Text {
            x: 16
            width: 20
            horizontalAlignment: Text.AlignHCenter
            anchors.verticalCenter: parent.verticalCenter
            text: row.modelData.glyph
            color: area.containsMouse ? panel.c.text : panel.c.muted
            renderType: Text.CurveRendering
            font.family: Theme.iconFont
            font.pixelSize: 16
        }

        Column {
            x: 48
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 48 - 90

            Row {
                spacing: 6

                Rectangle {
                    visible: row.modelData.connected
                    anchors.verticalCenter: parent.verticalCenter
                    width: 5
                    height: 5
                    radius: 2.5
                    color: panel.c.accent
                }

                Text {
                    text: row.modelData.name
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 170)
                    color: panel.c.text
                    renderType: Text.CurveRendering
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }
            }

            Text {
                text: row.modelData.sub
                textFormat: Text.PlainText
                color: panel.c.muted
                renderType: Text.CurveRendering
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
        }

        Text {
            x: parent.width - 16 - implicitWidth
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 1
            text: row.action
            opacity: area.containsMouse && !row.modelData.busy ? 1 : 0
            color: panel.c.muted
            renderType: Text.CurveRendering
            font.family: Theme.displayFont
            font.pixelSize: 9
            font.letterSpacing: 1.4
            font.capitalization: Font.AllUppercase

            Behavior on opacity {
                NumberAnimation { duration: 140 }
            }
        }

        MouseArea {
            id: area

            anchors.fill: parent
            enabled: !row.modelData.busy
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.clicked()
        }
    }

    Flickable {
        y: 48
        width: parent.width
        height: panel.bodyHeight
        contentHeight: column.implicitHeight
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: column

            width: parent.width

            // ---- off ----
            Column {
                visible: !Bt.powered
                width: column.width
                topPadding: 26
                bottomPadding: 22
                spacing: 6

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: ""
                    color: panel.c.muted
                    renderType: Text.CurveRendering
                    font.family: Theme.iconFont
                    font.pixelSize: 24
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: 6
                    text: "Bluetooth is off"
                    color: panel.c.text
                    renderType: Text.CurveRendering
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Turn it on to connect your devices."
                    color: panel.c.muted
                    renderType: Text.CurveRendering
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }

                ActionButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Turn on"
                    primary: true
                    onClicked: Bt.setPowered(true)
                }
            }

            // ---- on ----
            Section { visible: Bt.powered; height: visible ? 28 : 0; label: "My devices" }

            Repeater {
                model: Bt.powered ? Bt.devices : []

                delegate: DeviceRow {
                    action: modelData.connected ? "Disconnect" : "Connect"
                    onClicked: Bt.toggle(modelData.id)
                }
            }

            Text {
                visible: Bt.powered && Bt.devices.length === 0
                x: 16
                topPadding: 2
                bottomPadding: 6
                text: "No paired devices. Press Scan."
                color: panel.c.muted
                renderType: Text.CurveRendering
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }

            Section { visible: Bt.powered && (Bt.scanning || Bt.nearby.length > 0); height: visible ? 28 : 0; label: "Nearby" }

            Text {
                visible: Bt.powered && Bt.scanning && Bt.nearby.length === 0
                x: 16
                topPadding: 2
                bottomPadding: 6
                text: "Searching…"
                color: panel.c.muted
                renderType: Text.CurveRendering
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }

            Repeater {
                model: Bt.powered ? Bt.nearby : []

                delegate: DeviceRow {
                    action: "Pair"
                    onClicked: Bt.pair(modelData.id)
                }
            }
        }
    }
}
