import Quickshell
import QtQuick

import "../components"
import "../services"
import "../theme"
import "netlogic.js" as Logic

// Network dropdown: the current connection (name, speed, address, live rates), Connect/Disconnect, and the Wi-Fi networks
// in range with a password prompt for secured ones. State: services/Net.qml.
// It hangs from the toolbar pill in the comms log language: Orbitron only for the title, Geist sentence case, quiet rows.
Item {
    id: panel

    readonly property var c: Theme.imperial

    property string joining: ""         // id of the secured network whose password field is open
    // Cutting the live link (it can drop a remote session) takes two clicks: the first arms it ("eth" or a Wi-Fi id)
    // and turns the control red; it disarms by itself after 3 s.
    property string armed: ""

    Timer {
        running: panel.armed !== ""
        interval: 3000
        onTriggered: panel.armed = ""
    }

    readonly property real bodyHeight: Math.min(column.implicitHeight, 440)

    implicitHeight: body.y + bodyHeight + 10

    PanelHeader {
        x: 22
        y: 16
        width: parent.width - 44
        title: "Network"
        detail: Net.connected ? "Connected" : "Not connected"
    }

    // A label and a value, aligned with the text column.
    component Kv: Item {
        id: kv

        property string label: ""
        property string value: ""

        width: column.width
        height: 22

        Text {
            x: 40
            anchors.verticalCenter: parent.verticalCenter
            text: kv.label
            color: Theme.imperial.faint
            renderType: Text.CurveRendering
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: kv.value
            textFormat: Text.PlainText
            color: Theme.imperial.text
            renderType: Text.CurveRendering
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.features: { "tnum": 1 }
        }
    }

    Flickable {
        id: body

        x: 10
        y: 16 + 28 + 6
        width: parent.width - 20
        height: panel.bodyHeight
        contentHeight: column.implicitHeight
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: column

            width: parent.width

            // ---- the current connection ----
            Item {
                width: column.width
                height: 48

                Icon {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    name: Net.mode === "eth" ? "lan" : Net.mode === "wifi" ? "wifi" : Net.hasWifi ? "wifi_off" : "lan"
                    color: Net.connected ? panel.c.text : panel.c.muted
                    size: Theme.iconSize.panel
                }

                Column {
                    x: 40
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x - 12

                    Text {
                        width: parent.width
                        text: Net.title
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Net.connected ? panel.c.text : panel.c.muted
                        renderType: Text.CurveRendering
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.Medium
                    }

                    Text {
                        width: parent.width
                        text: Net.subtitle
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: panel.c.muted
                        renderType: Text.CurveRendering
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }
            }

            Kv { visible: Net.connected && Net.ipv4 !== ""; height: visible ? 22 : 0; label: "IPv4"; value: Net.ipv4 }
            Kv { visible: Net.connected; height: visible ? 22 : 0; label: "Down"; value: Logic.formatRate(Net.rxRate) }
            Kv { visible: Net.connected; height: visible ? 22 : 0; label: "Up"; value: Logic.formatRate(Net.txRate) }

            // Connect / Disconnect (the wired connection; Wi-Fi networks have their own rows).
            Item {
                visible: Net.mode !== "wifi" && (Net.mock || Net.device !== null)
                width: column.width
                height: visible ? 44 : 0

                PanelButton {
                    x: 30
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 2
                    text: !Net.connected ? "Connect" : panel.armed === "eth" ? "Disconnect?" : "Disconnect"
                    primary: !Net.connected
                    danger: Net.connected && panel.armed === "eth"
                    onClicked: {
                        if (!Net.connected)
                            Net.connect()
                        else if (panel.armed !== "eth")
                            panel.armed = "eth"
                        else {
                            panel.armed = ""
                            Net.disconnect()
                        }
                    }
                }
            }

            // ---- Wi-Fi ----
            PanelSection {
                visible: Net.hasWifi
                width: column.width
                implicitHeight: visible ? 32 : 0
                label: "Available networks"
            }

            Repeater {
                model: Net.hasWifi ? Net.wifi : []

                delegate: Column {
                    id: wifiRow

                    required property var modelData

                    readonly property bool asking: panel.joining === modelData.id

                    width: column.width

                    Item {
                        width: parent.width
                        height: 44

                        Rectangle {
                            anchors.fill: parent
                            radius: 14
                            color: rowArea.containsMouse || wifiRow.asking ? panel.c.rowHover : "transparent"

                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        // Signal bars.
                        Row {
                            x: 13
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: 1
                            spacing: 1.5

                            Repeater {
                                model: 4

                                delegate: Rectangle {
                                    required property int index

                                    anchors.bottom: parent.bottom
                                    width: 2.5
                                    height: 4 + index * 3
                                    radius: 0.5
                                    color: panel.c.text
                                    opacity: index < Logic.signalBars(wifiRow.modelData.strength) ? 1 : 0.3
                                }
                            }
                        }

                        Column {
                            x: 40
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - x - 12 - 90

                            Text {
                                width: parent.width
                                text: wifiRow.modelData.name
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                color: wifiRow.modelData.connected || rowArea.containsMouse ? panel.c.text : panel.c.muted
                                renderType: Text.CurveRendering
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: wifiRow.modelData.connected ? Font.Medium : Font.Normal
                            }

                            Text {
                                text: wifiRow.modelData.busy ? "Connecting…" : wifiRow.modelData.connected ? "Connected" : wifiRow.modelData.known ? "Saved" : wifiRow.modelData.secure ? "Secured" : "Open"
                                color: panel.c.faint
                                renderType: Text.CurveRendering
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                            }
                        }

                        // At rest: a lock on secured networks. On hover: what a click does.
                        Icon {
                            visible: wifiRow.modelData.secure && !rowArea.containsMouse
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            name: "lock"
                            color: panel.c.faint
                            size: Theme.iconSize.panel
                        }

                        Text {
                            readonly property bool armed: panel.armed === wifiRow.modelData.id

                            visible: (rowArea.containsMouse || armed) && !wifiRow.modelData.busy
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: wifiRow.modelData.connected ? (armed ? "Disconnect?" : "Disconnect")
                                : wifiRow.modelData.secure && !wifiRow.modelData.known ? "Enter password" : "Connect"
                            color: armed ? panel.c.dangerText : panel.c.muted
                            renderType: Text.CurveRendering
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }

                        MouseArea {
                            id: rowArea

                            anchors.fill: parent
                            enabled: !wifiRow.modelData.busy
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const n = wifiRow.modelData
                                if (n.secure && !n.connected && !n.known)
                                    panel.joining = panel.joining === n.id ? "" : n.id
                                else if (n.connected && panel.armed !== n.id)
                                    panel.armed = n.id
                                else {
                                    panel.armed = ""
                                    Net.toggleWifiNetwork(n.id)
                                }
                            }
                        }
                    }

                    // Password prompt for a secured network that is not saved yet.
                    Item {
                        visible: wifiRow.asking
                        width: parent.width
                        height: visible ? 46 : 0

                        Rectangle {
                            x: 40
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 10
                            width: parent.width - x - 12 - 64
                            height: 1
                            color: input.activeFocus ? panel.c.muted : panel.c.surfaceAlt
                        }

                        TextInput {
                            id: input

                            x: 40
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 14
                            width: parent.width - x - 12 - 64
                            echoMode: TextInput.Password
                            color: panel.c.text
                            selectionColor: panel.c.accentDim
                            clip: true
                            font.family: Theme.fontFamily
                            font.pixelSize: 13

                            Text {
                                visible: input.text === "" && !input.activeFocus
                                text: "Password"
                                color: panel.c.faint
                                font: input.font
                            }

                            onAccepted: join()
                            onVisibleChanged: if (visible) forceActiveFocus()
                            Keys.onEscapePressed: panel.joining = ""

                            function join() {
                                if (text === "")
                                    return
                                Net.joinWifi(wifiRow.modelData.id, text)
                                text = ""                       // the password is never kept
                                panel.joining = ""
                            }
                        }

                        PanelButton {
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 4
                            text: "Join"
                            primary: true
                            onClicked: input.join()
                        }
                    }
                }
            }

            Text {
                visible: !Net.hasWifi
                x: 40
                topPadding: 6
                bottomPadding: 4
                text: "No Wi-Fi adapter on this machine."
                color: panel.c.faint
                renderType: Text.CurveRendering
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
        }
    }
}
