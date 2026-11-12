import Quickshell
import QtQuick

import "../components"
import "../services"
import "../theme"

// Bluetooth dropdown: the adapter switch, Scan, the paired devices (connect, disconnect, battery) and nearby devices to
// pair. State: services/Bt.qml.
// It hangs from the toolbar pill in the comms log language: Orbitron only for the title, Geist sentence case, quiet rows,
// a monochrome switch (white when on).
Item {
    id: panel

    readonly property var c: Theme.imperial

    readonly property real bodyHeight: Math.min(column.implicitHeight, 420)

    implicitHeight: body.y + bodyHeight + 10

    PanelHeader {
        id: header

        x: 22
        y: 16
        width: parent.width - 44
        title: "Bluetooth"
    }

    // Scan and the adapter switch, on the header line.
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: header.verticalCenter
        spacing: 10

        PanelButton {
            visible: Bt.powered
            anchors.verticalCenter: parent.verticalCenter
            text: Bt.scanning ? "Scanning…" : "Scan"
            enabled: !Bt.scanning
            onClicked: Bt.scan()
        }

        Rectangle {
            id: sw

            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 18
            radius: 9
            color: Bt.powered ? panel.c.text : swArea.containsMouse ? "#24242C" : panel.c.surfaceAlt
            // Off, the track would vanish on the ink (1.2:1): a faint edge keeps the switch visible.
            border.width: Bt.powered ? 0 : 1
            border.color: panel.c.faint

            Behavior on color { ColorAnimation { duration: 160 } }

            Rectangle {
                x: Bt.powered ? parent.width - width - 3 : 3
                anchors.verticalCenter: parent.verticalCenter
                width: 12
                height: 12
                radius: 6
                color: Bt.powered ? panel.c.ink : panel.c.muted

                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }

            MouseArea {
                id: swArea

                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Bt.setPowered(!Bt.powered)
            }
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
            radius: 14
            color: area.containsMouse ? Theme.imperial.rowHover : "transparent"

            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Icon {
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            name: row.modelData.glyph
            size: Theme.iconSize.panel
            color: row.modelData.connected || area.containsMouse ? Theme.imperial.text : Theme.imperial.muted

            // A device that is connecting or pairing breathes until it settles.
            SequentialAnimation on opacity {
                running: row.modelData.busy
                loops: Animation.Infinite
                alwaysRunToEnd: true

                NumberAnimation { to: 0.35; duration: 600; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
            }
        }

        Column {
            x: 40
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - 12 - 80

            Text {
                width: parent.width
                text: row.modelData.name
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: row.modelData.connected || area.containsMouse ? Theme.imperial.text : Theme.imperial.muted
                renderType: Text.CurveRendering
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: row.modelData.connected ? Font.Medium : Font.Normal
            }

            Text {
                width: parent.width
                // "Paired" under every row of "My devices" only repeats the section: the line shows only news.
                visible: text !== "" && text !== "Paired"
                text: row.modelData.sub
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: row.modelData.connected || row.modelData.busy ? Theme.imperial.muted : Theme.imperial.faint
                renderType: Text.CurveRendering
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
        }

        // What a click does, only on hover.
        Text {
            visible: area.containsMouse && !row.modelData.busy
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: row.action
            color: Theme.imperial.muted
            renderType: Text.CurveRendering
            font.family: Theme.fontFamily
            font.pixelSize: 11
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
        id: body

        x: 10
        y: 16 + 28 + 2
        width: parent.width - 20
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
                x: 40
                width: column.width - 40
                topPadding: 14
                bottomPadding: 6
                spacing: 2

                Text {
                    text: "Bluetooth is off."
                    color: panel.c.text
                    renderType: Text.CurveRendering
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }

                Text {
                    text: "Turn it on to connect your devices."
                    color: panel.c.muted
                    renderType: Text.CurveRendering
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }

                Item { width: 1; height: 10 }

                PanelButton {
                    x: -10
                    text: "Turn on"
                    primary: true
                    onClicked: Bt.setPowered(true)
                }
            }

            // ---- on ----
            PanelSection { visible: Bt.powered; width: column.width; implicitHeight: visible ? 30 : 0; label: "My devices" }

            Repeater {
                model: Bt.powered ? Bt.devices : []

                delegate: DeviceRow {
                    action: modelData.connected ? "Disconnect" : "Connect"
                    onClicked: Bt.toggle(modelData.id)
                }
            }

            Text {
                visible: Bt.powered && Bt.devices.length === 0
                x: 40
                topPadding: 4
                bottomPadding: 6
                text: "No paired devices. Scan to find one."
                color: panel.c.faint
                renderType: Text.CurveRendering
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }

            PanelSection {
                visible: Bt.powered && (Bt.scanning || Bt.nearby.length > 0)
                width: column.width
                implicitHeight: visible ? 34 : 0
                label: "Nearby"
                status: Bt.scanning ? "Searching" : ""
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
