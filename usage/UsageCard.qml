import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

import "../components"
import "../services"
import "../theme"
import "logic.js" as Logic

// Dropdown card of the Claude usage chip: 5 h session and 7 d week limits. Fullscreen transparent overlay so a click
// outside closes it; the card hangs from the toolbar pill in the comms log language.
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
    visible: open || card.height > 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "tk421-usage"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    component Ease: NumberAnimation {
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
    }

    // One limit: name and window on the left, the percentage on the right, the meter, then when it resets.
    component LimitRow: Item {
        id: limit

        property string label
        property string span
        property int percent
        property string caption

        width: parent.width
        height: 62

        Text {
            id: labelText

            anchors.left: parent.left
            anchors.baseline: number.baseline
            text: limit.label
            color: Theme.imperial.text
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.weight: Font.Medium
            renderType: Text.CurveRendering
        }

        Text {
            anchors.left: labelText.right
            anchors.leftMargin: 6
            anchors.baseline: number.baseline
            text: limit.span
            color: Theme.imperial.faint
            font.family: Theme.fontFamily
            font.pixelSize: 12
            renderType: Text.CurveRendering
        }

        Text {
            id: unit

            anchors.right: parent.right
            anchors.baseline: number.baseline
            text: "%"
            color: Theme.imperial.faint
            font.family: Theme.fontFamily
            font.pixelSize: 12
            renderType: Text.CurveRendering
        }

        Text {
            id: number

            anchors.right: unit.left
            anchors.rightMargin: 1
            y: 0
            text: limit.percent
            color: Theme.imperial.text
            font.family: Theme.fontFamily
            font.pixelSize: 20
            font.weight: Font.Medium
            font.features: { "tnum": 1 }
            renderType: Text.CurveRendering
        }

        Meter {
            y: 32
            width: parent.width
            trackHeight: 4
            value: limit.percent
        }

        Text {
            y: 44
            width: parent.width
            text: limit.caption
            textFormat: Text.StyledText
            color: Theme.imperial.muted
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

    // The card hangs from the toolbar pill like the comms log: the pill's width, opaque ink, a hairline on the sides and
    // bottom only. Overlay layer, so it covers the pill's bottom hairline. Toolbar squares its corners (ClaudeUsage.docked).
    Binding {
        target: ClaudeUsage
        property: "docked"
        value: win.visible
    }

    Item {
        id: card

        readonly property real full: content.implicitHeight + 16 + 14

        width: Math.round(Notifications.dockWidth)
        height: win.open ? full : 0
        x: parent.width - width - 30
        y: 33
        clip: true

        Behavior on height { Ease { duration: win.open ? 520 : 340 } }

        // Swallows clicks on the card so they do not reach the closing area.
        MouseArea { anchors.fill: parent }

        Rectangle {
            anchors.fill: parent
            color: win.c.hairline
            bottomLeftRadius: 22
            bottomRightRadius: 22
        }

        Rectangle {
            x: 1
            width: parent.width - 2
            height: parent.height - 1
            color: win.c.ink
            bottomLeftRadius: 21
            bottomRightRadius: 21
        }

        Column {
            id: content

            x: 22
            y: 16
            width: parent.width - 44
            opacity: win.open ? 1 : 0

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: win.open ? 140 : 0 }
                    NumberAnimation { duration: win.open ? 320 : 140 }
                }
            }

            // Header: spark and title, the plan on the right.
            Item {
                width: parent.width
                height: 28

                Image {
                    id: spark

                    anchors.verticalCenter: parent.verticalCenter
                    width: 14
                    height: 14
                    source: Qt.resolvedUrl("../assets/claude.svg")
                    sourceSize: Qt.size(14, 14)
                }

                Text {
                    anchors.left: spark.right
                    anchors.leftMargin: 9
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 1
                    text: "CLAUDE"
                    color: win.c.text
                    font.family: Theme.displayFont
                    font.pixelSize: 11
                    font.letterSpacing: 2.2
                    renderType: Text.CurveRendering
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: ClaudeUsage.plan !== "" ? ClaudeUsage.plan.charAt(0).toUpperCase() + ClaudeUsage.plan.slice(1) + " plan" : "Plan limits"
                    textFormat: Text.PlainText
                    color: win.c.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    renderType: Text.CurveRendering
                }
            }

            Item { width: 1; height: 14 }

            // The limits: live when the read is ok; after a failed read the last values stay, dimmed, above the error.
            Column {
                width: parent.width
                spacing: 12
                visible: win.ok || ClaudeUsage.updatedAt > 0
                opacity: win.ok ? 1 : 0.45

                LimitRow {
                    label: "Session"
                    span: "5 hours"
                    percent: ClaudeUsage.sessionPercent
                    caption: win.sessionCaption()
                }

                LimitRow {
                    label: "Week"
                    span: "7 days"
                    percent: ClaudeUsage.weekPercent
                    caption: win.weekCaption()
                }
            }

            Item { width: 1; height: 14; visible: !win.ok && ClaudeUsage.updatedAt > 0 }

            Column {
                width: parent.width
                spacing: 4
                visible: !win.ok

                Text {
                    text: Logic.errorTitle(ClaudeUsage.error) + "."
                    color: win.c.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    renderType: Text.CurveRendering
                }

                Text {
                    width: parent.width
                    text: Logic.errorText(ClaudeUsage.error)
                    textFormat: Text.PlainText
                    wrapMode: Text.WordWrap
                    lineHeight: 1.25
                    color: win.c.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    renderType: Text.CurveRendering
                }
            }

            Item { width: 1; height: 12 }

            Item {
                width: parent.width
                height: 28

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: ClaudeUsage.updatedAt > 0
                        ? (win.ok ? "Updated " : "Last read ") + Logic.ago(ClaudeUsage.updatedAt, win.now)
                        : ClaudeUsage.busy ? "Reading…" : win.ok ? "Not read yet" : ""
                    color: win.c.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    renderType: Text.CurveRendering
                }

                Rectangle {
                    id: refreshButton

                    anchors.right: parent.right
                    anchors.rightMargin: -8
                    anchors.verticalCenter: parent.verticalCenter
                    width: refreshRow.implicitWidth + 20
                    height: 28
                    radius: 8
                    color: refreshArea.containsMouse && refreshButton.enabled ? win.c.surfaceAlt : "transparent"
                    // A rate-limited endpoint only answers 429 again: refresh waits for the automatic retry.
                    enabled: !ClaudeUsage.busy && ClaudeUsage.error !== "rate_limited"
                    opacity: enabled || ClaudeUsage.busy ? 1 : 0.4

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Row {
                        id: refreshRow

                        anchors.centerIn: parent
                        spacing: 6

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
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

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Refresh"
                            color: refreshArea.containsMouse ? win.c.text : win.c.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            renderType: Text.CurveRendering
                        }
                    }

                    MouseArea {
                        id: refreshArea

                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: refreshButton.enabled
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ClaudeUsage.refresh()
                    }
                }
            }
        }
    }
}
