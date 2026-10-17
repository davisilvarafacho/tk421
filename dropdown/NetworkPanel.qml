import Quickshell
import QtQuick

import "../components"
import "../services"
import "../theme"
import "netlogic.js" as Logic

// Network dropdown: the current connection (name, speed, address, live rates), Connect/Disconnect, and the Wi-Fi networks
// in range with a password prompt for secured ones. State: services/Net.qml. Prototype: prototypes/toolbar/index.html.
Item {
    id: panel

    readonly property var c: Theme.imperial

    property string joining: ""         // id of the secured network whose password field is open

    readonly property real bodyHeight: Math.min(column.implicitHeight, 420)

    implicitHeight: 48 + bodyHeight + 10

    Text {
        id: title

        x: 16
        y: 2 + (46 - height) / 2
        text: "Network"
        color: panel.c.text
        renderType: Text.CurveRendering
        font.family: Theme.displayFont
        font.pixelSize: 11
        font.letterSpacing: 2.2
        font.capitalization: Font.AllUppercase
    }

    Text {
        x: title.x + title.implicitWidth + 8
        y: title.y
        height: title.height
        verticalAlignment: Text.AlignVCenter
        text: Net.connected ? "Connected" : "Not connected"
        color: panel.c.muted
        renderType: Text.CurveRendering
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }

    component Kv: Item {
        id: kv

        property string label: ""
        property string value: ""

        width: column.width
        height: 24

        Text {
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            text: kv.label
            color: panel.c.muted
            renderType: Text.CurveRendering
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }

        Text {
            x: parent.width - 16 - implicitWidth
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 1
            text: kv.value
            textFormat: Text.PlainText
            color: panel.c.text
            renderType: Text.CurveRendering
            font.family: Theme.displayFont
            font.pixelSize: 11
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

            // ---- the current connection ----
            Item {
                width: column.width
                height: 62

                Text {
                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: Net.mode === "eth" ? "󰈀" : Net.mode === "wifi" ? "󰖩" : Net.hasWifi ? "󰖪" : "󰈁"
                    color: Net.connected ? panel.c.text : panel.c.muted
                    renderType: Text.CurveRendering
                    font.family: Theme.iconFont
                    font.pixelSize: 26
                }

                Column {
                    x: 56
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 56 - 16

                    Text {
                        width: parent.width
                        text: Net.title
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: panel.c.text
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

            Kv { visible: Net.connected && Net.ipv4 !== ""; height: visible ? 24 : 0; label: "IPv4"; value: Net.ipv4 }
            Kv { visible: Net.connected; height: visible ? 24 : 0; label: "Down"; value: Logic.formatRate(Net.rxRate) }
            Kv { visible: Net.connected; height: visible ? 24 : 0; label: "Up"; value: Logic.formatRate(Net.txRate) }

            // Connect / Disconnect (the wired connection; Wi-Fi networks have their own rows).
            Item {
                visible: Net.mode !== "wifi" && (Net.mock || Net.device !== null)
                width: column.width
                height: visible ? 44 : 0

                ActionButton {
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: Net.connected ? "Disconnect" : "Connect"
                    onClicked: Net.connected ? Net.disconnect() : Net.connect()
                }
            }

            // ---- Wi-Fi ----
            Item {
                visible: Net.hasWifi
                width: column.width
                height: visible ? 28 : 0

                Text {
                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 6
                    text: "Available networks"
                    color: panel.c.muted
                    renderType: Text.CurveRendering
                    font.family: Theme.displayFont
                    font.pixelSize: 9
                    font.letterSpacing: 1.8
                    font.capitalization: Font.AllUppercase
                }
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
                        height: 40

                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(0.91, 0.9, 0.89, 0.035)
                            opacity: rowArea.containsMouse ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation { duration: 120 }
                            }
                        }

                        // Signal bars.
                        Row {
                            x: 16
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1.5

                            Repeater {
                                model: 4

                                delegate: Rectangle {
                                    required property int index

                                    anchors.bottom: parent.bottom
                                    width: 2.5
                                    height: 4 + index * 3
                                    color: panel.c.text
                                    opacity: index < Logic.signalBars(wifiRow.modelData.strength) ? 1 : 0.25
                                }
                            }
                        }

                        Column {
                            x: 46
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 46 - 70

                            Row {
                                spacing: 6

                                Rectangle {
                                    visible: wifiRow.modelData.connected
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 5
                                    height: 5
                                    radius: 2.5
                                    color: panel.c.accent
                                }

                                Text {
                                    text: wifiRow.modelData.name
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    width: Math.min(implicitWidth, 190)
                                    color: panel.c.text
                                    renderType: Text.CurveRendering
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                }
                            }

                            Text {
                                text: wifiRow.modelData.busy ? "Connecting…" : wifiRow.modelData.connected ? "Connected" : wifiRow.modelData.known ? "Saved" : wifiRow.modelData.secure ? "Secured" : "Open"
                                color: panel.c.muted
                                renderType: Text.CurveRendering
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                            }
                        }

                        Text {
                            visible: wifiRow.modelData.secure
                            x: parent.width - 16 - implicitWidth
                            anchors.verticalCenter: parent.verticalCenter
                            text: ""
                            color: panel.c.muted
                            renderType: Text.CurveRendering
                            font.family: Theme.iconFont
                            font.pixelSize: 11
                        }

                        Text {
                            x: parent.width - 36 - implicitWidth
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: 1
                            text: wifiRow.modelData.connected ? "Disconnect" : "Connect"
                            visible: !wifiRow.modelData.secure || wifiRow.modelData.connected || wifiRow.modelData.known
                            opacity: rowArea.containsMouse && !wifiRow.modelData.busy ? 1 : 0
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
                            id: rowArea

                            anchors.fill: parent
                            enabled: !wifiRow.modelData.busy
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const n = wifiRow.modelData
                                if (n.secure && !n.connected && !n.known)
                                    panel.joining = panel.joining === n.id ? "" : n.id
                                else
                                    Net.toggleWifiNetwork(n.id)
                            }
                        }
                    }

                    // Password prompt for a secured network that is not saved yet.
                    Item {
                        visible: wifiRow.asking
                        width: parent.width
                        height: visible ? 44 : 0

                        Rectangle {
                            x: 46
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 8
                            width: parent.width - 46 - 16 - 64
                            height: 1
                            color: input.activeFocus ? panel.c.accent : panel.c.border
                        }

                        TextInput {
                            id: input

                            x: 46
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 10
                            width: parent.width - 46 - 16 - 64
                            echoMode: TextInput.Password
                            color: panel.c.text
                            selectionColor: panel.c.accentDim
                            clip: true
                            font.family: Theme.fontFamily
                            font.pixelSize: 13

                            Text {
                                visible: input.text === "" && !input.activeFocus
                                text: "Password"
                                color: panel.c.muted
                                font: input.font
                            }

                            onAccepted: join()

                            function join() {
                                if (text === "")
                                    return
                                Net.joinWifi(wifiRow.modelData.id, text)
                                text = ""                       // the password is never kept
                                panel.joining = ""
                            }
                        }

                        ActionButton {
                            x: parent.width - width - 12
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
                x: 16
                topPadding: 4
                bottomPadding: 6
                text: "Wi-Fi · no adapter found on this machine"
                color: panel.c.muted
                renderType: Text.CurveRendering
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
        }
    }
}
