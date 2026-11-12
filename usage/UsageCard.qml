import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

import "../components"
import "../services"
import "../theme"
import "logic.js" as Logic

// Dropdown card of the Claude usage chip: 5 h session and 7 d week limits. Fullscreen transparent overlay so a click
// outside closes it; the card itself is translucent (Hyprland blurs it, layer rule in hypr/hyprland.lua).
// Prototype: prototypes/claude-usage/index.html. IPC: `usage toggle|refresh|status`.
PanelWindow {
    id: win

    readonly property var c: Theme.imperial
    readonly property bool open: ClaudeUsage.open
    readonly property bool ok: ClaudeUsage.status === "ok"
    property double now: Date.now()

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: open || card.opacity > 0.01

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "tk421-usage"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    component Ease: NumberAnimation {
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
    }

    // One limit: label, big percentage, meter, caption (StyledText, built from our own strings only).
    component LimitRow: Item {
        id: limit

        property string label
        property int percent
        property string caption

        width: parent.width
        height: 55

        Text {
            id: labelText

            anchors.left: parent.left
            anchors.baseline: number.baseline
            text: limit.label
            color: win.c.muted
            font.family: Theme.displayFont
            font.pixelSize: 9
            font.weight: Font.Medium
            font.letterSpacing: 2
            renderType: Text.CurveRendering
        }

        Text {
            id: unit

            anchors.right: parent.right
            anchors.baseline: number.baseline
            text: "%"
            color: win.c.muted
            font.family: Theme.displayFont
            font.pixelSize: 10
            renderType: Text.CurveRendering
        }

        Text {
            id: number

            anchors.right: unit.left
            anchors.rightMargin: 2
            y: 0
            text: limit.percent
            color: win.c.text
            font.family: Theme.displayFont
            font.pixelSize: 17
            font.weight: Font.Medium
            renderType: Text.CurveRendering
        }

        Meter {
            y: 27
            width: parent.width
            trackHeight: 5
            value: limit.percent
        }

        Text {
            y: 40
            width: parent.width
            text: limit.caption
            textFormat: Text.StyledText
            color: win.c.muted
            font.family: Theme.fontFamily
            font.pixelSize: 12
            renderType: Text.CurveRendering
        }
    }

    function bold(s) {
        return "<font color=\"#c9c7c4\"><b>" + s + "</b></font>"
    }

    function sessionCaption() {
        return "Resets in " + bold(Logic.remaining(ClaudeUsage.sessionResets, win.now))
    }

    // Within a day the countdown is more useful than a weekday.
    function weekCaption() {
        const at = new Date(ClaudeUsage.weekResets)
        if (isNaN(at.getTime()))
            return ""
        if (at.getTime() - win.now < 24 * 3600 * 1000)
            return "Resets in " + bold(Logic.remaining(ClaudeUsage.weekResets, win.now))
        return "Resets " + bold(Qt.formatDateTime(at, "ddd HH:mm"))
    }

    onOpenChanged: {
        if (open) {
            now = Date.now()
            ClaudeUsage.refreshIfStale()
        }
    }

    Timer {
        interval: 1000
        running: win.open
        repeat: true
        onTriggered: win.now = Date.now()
    }

    IpcHandler {
        target: "usage"

        function toggle(): void {
            ClaudeUsage.open = !ClaudeUsage.open
        }

        function refresh(): void {
            ClaudeUsage.refresh()
        }

        function status(): string {
            return "status=" + ClaudeUsage.status + " session=" + ClaudeUsage.sessionPercent
                + " week=" + ClaudeUsage.weekPercent + " plan=" + ClaudeUsage.plan
                + " error=" + ClaudeUsage.error + " open=" + ClaudeUsage.open
        }
    }

    // Click outside the card closes.
    MouseArea {
        anchors.fill: parent
        onClicked: ClaudeUsage.open = false
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: ClaudeUsage.open = false
    }

    Rectangle {
        id: card

        width: 308
        height: content.implicitHeight + 36    // 18 px of padding above and below
        x: parent.width - width - 30
        y: 40 + (win.open ? 0 : -6)
        radius: 16
        color: Qt.alpha(win.c.surface, 0.72)
        border.width: 1
        border.color: win.c.border
        clip: true
        opacity: win.open ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: win.open ? 180 : 120 } }
        Behavior on y { Ease { duration: win.open ? 320 : 200 } }
        Behavior on height { Ease { duration: 180 } }

        // Swallows clicks on the card so they do not reach the closing area.
        MouseArea { anchors.fill: parent }

        Column {
            id: content

            x: 20
            y: 18
            width: parent.width - 40

            Item {
                width: parent.width
                height: 15

                Image {
                    id: spark

                    anchors.verticalCenter: parent.verticalCenter
                    width: 15
                    height: 15
                    source: Qt.resolvedUrl("../assets/claude.svg")
                    sourceSize: Qt.size(30, 30)
                }

                Text {
                    anchors.left: spark.right
                    anchors.leftMargin: 9
                    anchors.verticalCenter: parent.verticalCenter
                    text: "CLAUDE"
                    color: win.c.text
                    font.family: Theme.displayFont
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    font.letterSpacing: 2.4
                    renderType: Text.CurveRendering
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: ClaudeUsage.plan !== "" ? "PLAN · " + ClaudeUsage.plan.toUpperCase() : "PLAN LIMITS"
                    textFormat: Text.PlainText
                    color: win.c.muted
                    opacity: 0.6
                    font.family: Theme.displayFont
                    font.pixelSize: 9
                    font.weight: Font.Medium
                    font.letterSpacing: 2.2
                    renderType: Text.CurveRendering
                }
            }

            Item { width: 1; height: 14 }

            Column {
                width: parent.width
                spacing: 14
                visible: win.ok

                LimitRow {
                    label: "SESSION · 5 H"
                    percent: ClaudeUsage.sessionPercent
                    caption: win.sessionCaption()
                }

                LimitRow {
                    label: "WEEK · 7 D"
                    percent: ClaudeUsage.weekPercent
                    caption: win.weekCaption()
                }
            }

            Column {
                width: parent.width
                spacing: 10
                visible: !win.ok

                Text {
                    text: "OFFLINE"
                    color: win.c.muted
                    font.family: Theme.displayFont
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    font.letterSpacing: 2.6
                    renderType: Text.CurveRendering
                }

                Text {
                    width: parent.width
                    text: Logic.errorText(ClaudeUsage.error)
                    textFormat: Text.PlainText
                    wrapMode: Text.WordWrap
                    lineHeight: 1.25
                    color: win.c.muted
                    opacity: 0.85
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    renderType: Text.CurveRendering
                }
            }

            Item { width: 1; height: 14 }

            Item {
                width: parent.width
                height: 22

                Text {
                    id: updatedText

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: ClaudeUsage.updatedAt > 0
                        ? (win.ok ? "Updated " : "Last read ") + Logic.ago(ClaudeUsage.updatedAt, win.now)
                        : ClaudeUsage.busy ? "Reading…" : "Not read yet"
                    color: win.c.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    renderType: Text.CurveRendering
                }

                // Refresh: hover pill, glyph and label. The label sits on the baseline of the "Updated" text.
                Rectangle {
                    id: refreshButton

                    anchors.right: parent.right
                    anchors.rightMargin: -6
                    anchors.verticalCenter: parent.verticalCenter
                    width: refreshGlyph.implicitWidth + 6 + refreshLabel.implicitWidth + 12
                    height: 22
                    radius: 7
                    color: win.c.surfaceAlt
                    opacity: refreshArea.containsMouse ? 1 : 0

                    Behavior on opacity { NumberAnimation { duration: 140 } }
                }

                Text {
                    id: refreshLabel

                    anchors.right: parent.right
                    anchors.baseline: updatedText.baseline
                    text: "Refresh"
                    color: refreshArea.containsMouse ? win.c.text : win.c.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    renderType: Text.CurveRendering
                }

                Icon {
                    id: refreshGlyph

                    anchors.right: refreshLabel.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: refreshLabel.verticalCenter
                    name: "refresh"
                    color: refreshArea.containsMouse ? win.c.text : win.c.muted
                    size: Theme.iconSize.panel

                    RotationAnimator on rotation {
                        from: 0
                        to: 360
                        duration: 800
                        loops: Animation.Infinite
                        running: ClaudeUsage.busy
                    }
                }

                MouseArea {
                    id: refreshArea

                    anchors.fill: refreshButton
                    hoverEnabled: true
                    onClicked: ClaudeUsage.refresh()
                }
            }
        }
    }
}
