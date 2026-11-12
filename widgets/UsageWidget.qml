import QtQuick

import "../services"
import "../theme"
import "logic.js" as Logic
import "../usage/logic.js" as UsageLogic

// Claude plan limits: the 5 hour session and the week, each with its reset time (services/ClaudeUsage.qml).
WidgetPanel {
    id: w

    property double now: Date.now()
    readonly property bool ok: ClaudeUsage.status === "ok"

    label: "Claude plan"
    aside: ok ? "updated " + UsageLogic.ago(ClaudeUsage.updatedAt, now)
        : ClaudeUsage.status === "unknown" ? "reading…" : "offline"

    component Meter: Column {
        id: m

        property string name: ""
        property int percent: 0
        property string reset: ""
        property bool live: true

        opacity: live ? 1 : 0.45

        Item {
            width: m.width
            height: 13

            Text {
                text: m.name
                color: Theme.imperial.muted
                renderType: Text.CurveRendering
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }

            Text {
                anchors.right: parent.right
                text: m.live ? m.percent + "%" : "—"
                color: Theme.imperial.text
                renderType: Text.CurveRendering
                font.family: Theme.displayFont
                font.weight: Font.Medium
                font.pixelSize: 13
            }
        }

        Item { width: 1; height: 9 }

        Rectangle {
            width: m.width
            height: 3
            radius: 1.5
            color: "#1F1F25"

            Rectangle {
                width: parent.width * Math.max(0, Math.min(100, m.percent)) / 100
                height: parent.height
                radius: 1.5
                color: "#B9B6B2"

                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
        }

        Item { width: 1; height: 7 }

        Text {
            visible: m.reset !== ""
            text: m.reset
            color: Theme.imperial.faint
            renderType: Text.CurveRendering
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }
    }

    Meter {
        width: parent.width
        name: "Session, 5 hours"
        percent: ClaudeUsage.sessionPercent
        reset: Logic.resetLabel(ClaudeUsage.sessionResets, w.now)
        live: w.ok
    }

    Item { width: 1; height: 16 }

    Meter {
        width: parent.width
        name: "Week"
        percent: ClaudeUsage.weekPercent
        reset: Logic.resetLabel(ClaudeUsage.weekResets, w.now)
        live: w.ok
    }
}
