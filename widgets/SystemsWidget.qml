import QtQuick

import "../resources"
import "../services"
import "../theme"
import "logic.js" as Logic

// CPU, GPU and RAM with their last minute as graphs, one bar per CPU thread, then VRAM, disk and the busiest process.
// Everything comes from services/Resources.qml (its detail sample runs while the widgets show: Resources.watched).
WidgetPanel {
    id: w

    property string uptime: ""
    property string disk: "—"

    readonly property real gaugeWidth: (width - 40 - 2 * 18) / 3

    label: "Systems"
    aside: uptime

    component Gauge: Column {
        id: g

        property string name: ""
        property string value: ""
        property string unit: ""
        property string sub: ""
        property var values: []

        Text {
            text: g.name
            color: Theme.imperial.muted
            renderType: Text.CurveRendering
            font.family: Theme.displayFont
            font.pixelSize: 10
            font.letterSpacing: 2.2
        }

        Item { width: 1; height: 10 }

        Row {
            spacing: 3

            Text {
                id: big

                text: g.value
                color: Theme.imperial.text
                renderType: Text.CurveRendering
                font.family: Theme.displayFont
                font.weight: Font.Medium
                font.pixelSize: 26
            }

            Text {
                anchors.baseline: big.baseline
                text: g.unit
                color: Theme.imperial.muted
                renderType: Text.CurveRendering
                font.family: Theme.displayFont
                font.pixelSize: 11
            }
        }

        Item { width: 1; height: 6 }

        Text {
            text: g.sub
            color: Theme.imperial.faint
            renderType: Text.CurveRendering
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }

        Item { width: 1; height: 12 }

        Spark {
            width: g.width
            height: 34
            values: g.values
        }
    }

    component Fact: Row {
        id: f

        property string name: ""
        property string value: ""

        spacing: 4

        Text {
            text: f.name
            color: Theme.imperial.faint
            renderType: Text.CurveRendering
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }

        Text {
            text: f.value
            textFormat: Text.PlainText      // process names come from other programs
            color: Theme.imperial.muted
            renderType: Text.CurveRendering
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }
    }

    Row {
        width: parent.width
        spacing: 18

        Gauge {
            width: w.gaugeWidth
            name: "CPU"
            value: Math.round(Resources.cpu)
            unit: "%"
            sub: (Resources.cpuTemp >= 0 ? Math.round(Resources.cpuTemp) + " °C" : "—")
                + (Resources.cpuMHz > 0 ? " · " + (Resources.cpuMHz / 1000).toFixed(1) + " GHz" : "")
            values: Resources.cpuHistory
        }

        Gauge {
            width: w.gaugeWidth
            name: "GPU"
            value: Math.round(Resources.gpu)
            unit: "%"
            sub: (Resources.gpuTemp >= 0 ? Math.round(Resources.gpuTemp) + " °C" : "—")
                + (Resources.gpuPower >= 0 ? " · " + Math.round(Resources.gpuPower) + " W" : "")
            values: Resources.gpuHistory
        }

        Gauge {
            width: w.gaugeWidth
            name: "RAM"
            value: Resources.ramUsedGiB.toFixed(1)
            unit: "GB"
            sub: "of " + Math.round(Resources.ramTotalGiB) + " GB"
            values: Resources.ramHistory
        }
    }

    Item { width: 1; height: 18 }

    // One bar per thread, in two rows.
    Grid {
        id: cores

        readonly property int count: Resources.cores.length
        readonly property int cols: Math.max(1, Math.ceil(count / 2))

        width: parent.width
        columns: cols
        spacing: 3

        Repeater {
            model: Resources.cores

            delegate: Rectangle {
                required property real modelData

                width: (cores.width - (cores.cols - 1) * 3) / cores.cols
                height: 11.5
                radius: 1.5
                color: "#1F1F25"
                clip: true

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: parent.height * Math.max(0, Math.min(100, modelData)) / 100
                    color: "#7F7D80"

                    Behavior on height { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                }
            }
        }
    }

    Item { width: 1; height: 16 }

    Item {
        width: parent.width
        height: 12

        Fact {
            name: "VRAM"
            value: Resources.vramTotalGiB > 0
                ? Resources.vramUsedGiB.toFixed(1) + " / " + Math.round(Resources.vramTotalGiB) + " GB" : "—"
        }

        Fact {
            anchors.horizontalCenter: parent.horizontalCenter
            name: "Disk"
            value: w.disk
        }

        Fact {
            anchors.right: parent.right
            name: "Busiest"
            value: Resources.topCpu.length > 0 ? Resources.topCpu[0].name : "—"
        }
    }
}
