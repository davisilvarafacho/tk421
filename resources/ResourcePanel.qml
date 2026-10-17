import Quickshell
import Quickshell.Wayland
import QtQuick

import "../services"
import "../theme"
import "logic.js" as Logic

// Hover panel of the CPU / RAM / GPU capsule: three blocks (load, history, details, busiest processes).
// Opens while the pointer is on the capsule or on the panel (services/Resources.qml keeps that state).
// Prototype: prototypes/resources/index.html
PanelWindow {
    id: win

    readonly property var c: Theme.imperial
    readonly property real blockWidth: 240
    readonly property real innerWidth: blockWidth - 32

    anchors {
        top: true
        left: true
    }
    margins.top: 40
    margins.left: 30
    implicitWidth: blockWidth * 3
    implicitHeight: 460
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: Resources.open || panel.opacity > 0.01

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "tk421-resources"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Only the panel takes input; the rest of the window is click-through.
    mask: Region { item: panel }

    component Ease: NumberAnimation {
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
    }

    // Inline components cannot see the ids of this file: they read the theme directly.
    component Label: Text {
        color: Theme.imperial.muted
        renderType: Text.CurveRendering
        font.family: Theme.displayFont
        font.pixelSize: 9
        font.letterSpacing: 1.8
        font.capitalization: Font.AllUppercase
    }

    component StatRow: Item {
        property string label: ""
        property string value: ""
        property bool hot: false

        width: parent.width
        height: 14

        Label {
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 1
            text: parent.label
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: parent.value
            textFormat: Text.PlainText
            color: parent.hot ? Theme.imperial.dangerText : Theme.imperial.text
            renderType: Text.CurveRendering
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }
    }

    // The busiest processes. Names come from other programs: plain text, always.
    component TopList: Column {
        property var rows: []
        property string suffix: ""
        property int digits: 1

        width: parent.width
        spacing: 6

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.imperial.border
        }

        Label {
            text: "TOP"
            topPadding: 4
        }

        Repeater {
            model: parent.rows

            delegate: Item {
                required property var modelData

                width: parent.width
                height: 14

                Text {
                    id: amount

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.value.toFixed(parent.parent.digits) + parent.parent.suffix
                    color: Theme.imperial.muted
                    renderType: Text.CurveRendering
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - amount.width - 8
                    text: modelData.name
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Theme.imperial.text
                    opacity: 0.9
                    renderType: Text.CurveRendering
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }
            }
        }
    }

    component BigNumber: Row {
        property real value: 0

        spacing: 3

        Text {
            text: Math.round(parent.value)
            color: Theme.imperial.text
            renderType: Text.CurveRendering
            font.family: Theme.displayFont
            font.pixelSize: 28
            font.weight: Font.Medium
        }

        Text {
            anchors.baseline: parent.children[0].baseline
            text: "%"
            color: Theme.imperial.muted
            renderType: Text.CurveRendering
            font.family: Theme.displayFont
            font.pixelSize: 11
        }
    }

    component Meter: Rectangle {
        property real value: 0

        width: parent.width
        height: 3
        radius: 1.5
        color: Theme.imperial.surfaceAlt

        Rectangle {
            width: parent.width * Math.max(0, Math.min(100, parent.value)) / 100
            height: parent.height
            radius: 1.5
            color: "#B9B6B2"
            opacity: 0.85

            Behavior on width { Ease { duration: 400 } }
        }
    }

    Rectangle {
        id: panel

        y: Resources.open ? 0 : -6
        width: win.blockWidth * 3
        height: blocks.implicitHeight
        radius: 20
        color: Qt.alpha(win.c.surface, 0.72)    // Hyprland blurs what is behind it: layer rule in hypr/hyprland.lua
        border.width: 1
        border.color: win.c.border
        clip: true
        opacity: Resources.open ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: Resources.open ? 180 : 140 } }
        Behavior on y { Ease { duration: Resources.open ? 320 : 200 } }

        HoverHandler {
            onHoveredChanged: Resources.panelHovered = hovered
        }

        Row {
            id: blocks

            // CPU
            Item {
                width: win.blockWidth
                implicitHeight: cpuColumn.implicitHeight + 30

                Column {
                    id: cpuColumn

                    x: 16
                    y: 16
                    width: win.innerWidth
                    spacing: 12

                    Item {
                        width: parent.width
                        height: 12

                        Label {
                            text: "CPU"
                            color: win.c.text
                            font.pixelSize: 10
                            font.letterSpacing: 2.2
                        }

                        Text {
                            anchors.right: parent.right
                            text: (Resources.cpuName !== "" ? Resources.cpuName + " · " : "") + Resources.cores.length + " threads"
                            color: win.c.muted
                            renderType: Text.CurveRendering
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }
                    }

                    BigNumber {
                        value: Resources.cpu
                    }

                    Spark {
                        width: parent.width
                        height: 36
                        values: Resources.cpuHistory
                    }

                    Row {
                        width: parent.width
                        height: 24
                        spacing: 3

                        Repeater {
                            model: Resources.cores

                            delegate: Rectangle {
                                required property real modelData

                                width: Math.max(2, (win.innerWidth - (Resources.cores.length - 1) * 3) / Math.max(1, Resources.cores.length))
                                height: 24
                                radius: 1.5
                                color: win.c.surfaceAlt

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: parent.height * Math.max(0, Math.min(100, modelData)) / 100
                                    radius: 1.5
                                    color: "#B9B6B2"
                                    opacity: 0.85

                                    Behavior on height { Ease { duration: 400 } }
                                }
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 7

                        StatRow {
                            label: "Temp"
                            value: Resources.cpuTemp >= 0 ? Math.round(Resources.cpuTemp) + "°C" : "—"
                            hot: Resources.cpuTemp > 75
                        }

                        StatRow {
                            label: "Clock"
                            value: Resources.cpuMHz > 0 ? (Resources.cpuMHz / 1000).toFixed(2) + " GHz" : "—"
                        }
                    }

                    TopList {
                        rows: Resources.topCpu
                        suffix: "%"
                        digits: 1
                    }
                }
            }

            Rectangle {
                width: 1
                height: parent.height
                color: win.c.border
            }

            // GPU
            Item {
                width: win.blockWidth - 1
                implicitHeight: gpuColumn.implicitHeight + 30

                Column {
                    id: gpuColumn

                    x: 16
                    y: 16
                    width: win.innerWidth
                    spacing: 12

                    Item {
                        width: parent.width
                        height: 12

                        Label {
                            text: "GPU"
                            color: win.c.text
                            font.pixelSize: 10
                            font.letterSpacing: 2.2
                        }

                        Text {
                            anchors.right: parent.right
                            text: (Resources.gpuName !== "" ? Resources.gpuName + " · " : "") + Math.round(Resources.vramTotalGiB) + " GiB"
                            color: win.c.muted
                            renderType: Text.CurveRendering
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }
                    }

                    BigNumber {
                        value: Resources.gpu
                    }

                    Spark {
                        width: parent.width
                        height: 36
                        values: Resources.gpuHistory
                    }

                    Meter {
                        value: Resources.vram
                    }

                    Column {
                        width: parent.width
                        spacing: 7

                        StatRow {
                            label: "VRAM"
                            value: Resources.vramUsedGiB.toFixed(1) + " / " + Resources.vramTotalGiB.toFixed(0) + " GiB"
                        }

                        StatRow {
                            label: "Temp"
                            value: Resources.gpuTemp >= 0 ? Math.round(Resources.gpuTemp) + "°C" : "—"
                            hot: Resources.gpuTemp > 85
                        }

                        StatRow {
                            label: "Power"
                            value: Resources.gpuPower >= 0
                                ? Math.round(Resources.gpuPower) + " W" + (Resources.gpuCap > 0 ? " / " + Math.round(Resources.gpuCap) + " W" : "")
                                : "—"
                        }

                        StatRow {
                            label: "Fan"
                            value: Resources.gpuFan >= 0 ? Math.round(Resources.gpuFan) + " RPM" : "—"
                        }
                    }
                }
            }

            Rectangle {
                width: 1
                height: parent.height
                color: win.c.border
            }

            // RAM
            Item {
                width: win.blockWidth - 1
                implicitHeight: ramColumn.implicitHeight + 30

                Column {
                    id: ramColumn

                    x: 16
                    y: 16
                    width: win.innerWidth
                    spacing: 12

                    Item {
                        width: parent.width
                        height: 12

                        Label {
                            text: "RAM"
                            color: win.c.text
                            font.pixelSize: 10
                            font.letterSpacing: 2.2
                        }

                        Text {
                            anchors.right: parent.right
                            text: Math.round(Resources.ramTotalGiB) + " GiB"
                            color: win.c.muted
                            renderType: Text.CurveRendering
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }
                    }

                    BigNumber {
                        value: Resources.ram
                    }

                    Spark {
                        width: parent.width
                        height: 36
                        values: Resources.ramHistory
                    }

                    Meter {
                        value: Resources.ram
                    }

                    Column {
                        width: parent.width
                        spacing: 7

                        StatRow {
                            label: "Used"
                            value: Logic.gib(Resources.ramUsedGiB)
                        }

                        StatRow {
                            label: "Cache"
                            value: Logic.gib(Resources.ramCacheGiB)
                        }

                        StatRow {
                            label: "Free"
                            value: Logic.gib(Resources.ramFreeGiB)
                        }
                    }

                    TopList {
                        rows: Resources.topMem
                        suffix: " GiB"
                        digits: 2
                    }
                }
            }
        }
    }
}
