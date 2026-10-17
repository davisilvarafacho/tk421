import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

import "../services"
import "../theme"

// Dynamic Island: replaces the bar clock. Idle pill -> media pill -> volume HUD -> calendar/agenda card.
// Priority: open > hud > media > idle. Prototype: prototypes/dynamic-island/index.html
PanelWindow {
    id: win

    readonly property var c: Theme.imperial

    property bool hoverOpen: false
    property bool pinned: false
    property bool hud: false
    property string tab: "agenda"      // expanded card: agenda | media (always reopens on agenda)
    readonly property bool open: hoverOpen || pinned
    readonly property bool playing: Media.playing
    readonly property bool pill: Hud.active && !open      // a brief confirmation, above the volume HUD
    readonly property bool notify: Notifications.toast !== null && !open      // a notification popup, above the HUD

    property date viewDate: clock.date
    property date selected: clock.date

    anchors.top: true
    margins.top: 4      // same top edge as the bar capsules
    implicitWidth: 800
    implicitHeight: 470
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "tk421-island"

    // Only the island itself takes input; the rest of the window is click-through.
    mask: Region { item: card }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    component Ease: NumberAnimation {
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
    }

    onOpenChanged: {
        Notifications.islandOpen = open
        if (open) {
            hud = false
            Agenda.refreshIfStale()
        } else {
            viewDate = clock.date
            selected = clock.date
            tab = "agenda"
        }
    }

    Connections {
        target: Audio

        function onChanged() {
            if (!win.open) {
                win.hud = true
                hudTimer.restart()
            }
        }
    }

    Timer {
        id: hudTimer
        interval: 1600
        onTriggered: win.hud = false
    }

    Timer {
        id: closeTimer
        interval: 180
        onTriggered: win.hoverOpen = false
    }

    IpcHandler {
        target: "island"

        function toggle(): void {
            win.pinned = !win.pinned
        }

        function tab(name: string): void {
            if (name === "agenda" || name === "media")
                win.tab = name
        }

        function currentTab(): string {
            return win.tab
        }
    }

    Rectangle {
        id: card

        anchors.horizontalCenter: parent.horizontalCenter
        y: 0

        width: win.open ? 748 : win.notify ? 360 : win.pill ? 250 : win.hud ? 300 : win.playing ? 168 : 108
        height: win.open ? 424 : win.notify ? toastView.height : win.pill || win.hud ? 44 : 28
        radius: win.open ? 24 : win.notify ? 20 : height / 2
        color: win.c.surface
        border.width: 1
        border.color: win.notify && toastView.critical ? win.c.danger : win.c.border
        clip: true

        Behavior on width { Ease { duration: win.open ? 520 : 340 } }
        Behavior on height { Ease { duration: win.open ? 520 : 340 } }
        Behavior on radius { Ease { duration: win.open ? 520 : 340 } }

        HoverHandler {
            onHoveredChanged: {
                if (hovered) {
                    closeTimer.stop()
                    if (win.notify)
                        Notifications.toastHovered = true      // hovering a popup expands it, it does not open the card
                    else
                        win.hoverOpen = true
                } else {
                    Notifications.toastHovered = false
                    closeTimer.restart()
                }
            }
        }

        // Compact media activity: art on the left, equalizer on the right.
        Rectangle {
            x: 12
            anchors.verticalCenter: parent.top
            anchors.verticalCenterOffset: 14
            width: 16
            height: 16
            radius: 4
            color: win.c.surfaceAlt
            border.width: 1
            border.color: win.c.border
            clip: true
            opacity: win.playing && !win.open && !win.hud && !win.pill && !win.notify ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: 200 } }

            Image {
                anchors.fill: parent
                source: Media.art
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }
        }

        Row {
            id: eq

            x: parent.width - width - 12      // width is 16: 4 bars of 2px + 3 gaps
            anchors.verticalCenter: parent.top
            anchors.verticalCenterOffset: 14
            spacing: 8 / 3
            opacity: win.playing && !win.open && !win.hud && !win.pill && !win.notify ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: 200 } }

            Repeater {
                model: [900, 640, 780, 560]

                delegate: Item {
                    required property int modelData

                    width: 2
                    height: 12

                    Rectangle {
                        id: bar
                        anchors.bottom: parent.bottom
                        width: 2
                        height: 12 * 0.3
                        color: win.c.text

                        SequentialAnimation on height {
                            running: win.playing && eq.opacity > 0
                            loops: Animation.Infinite
                            NumberAnimation { to: 12; duration: modelData; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 3; duration: modelData; easing.type: Easing.InOutSine }
                        }
                    }
                }
            }
        }

        // Clock: one element, centred in every state.
        Text {
            renderType: Text.CurveRendering
            id: time

            anchors.horizontalCenter: parent.horizontalCenter
            y: win.open ? 22 : 5      // 5 puts the Orbitron digits' ink at the pill's vertical centre
            scale: win.open ? 1 : 0.5
            transformOrigin: Item.Top
            opacity: (win.hud || win.pill || win.notify) && !win.open ? 0 : 1
            textFormat: Text.RichText
            text: Qt.formatTime(clock.date, "HH:mm") + "<font color=\"" + win.c.muted + "\">:" + Qt.formatTime(clock.date, "ss") + "</font>"
            color: win.c.text
            font.family: Theme.displayFont
            font.pixelSize: 30
            font.weight: Font.Medium
            font.letterSpacing: 1.2

            Behavior on y { Ease { duration: win.open ? 520 : 340 } }
            Behavior on scale { Ease { duration: win.open ? 520 : 340 } }
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        Text {
            renderType: Text.CurveRendering
            anchors.horizontalCenter: parent.horizontalCenter
            y: win.open ? 62 : 66
            text: Qt.locale("en_US").toString(clock.date, "dddd, d MMMM")
            color: win.c.muted
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.weight: Font.Medium
            opacity: win.open ? 1 : 0

            Behavior on y { Ease { duration: 420 } }
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: win.open ? 160 : 0 }
                    NumberAnimation { duration: win.open ? 320 : 160 }
                }
            }
        }

        // Volume HUD (brightness will reuse it once a backend exists).
        Row {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            spacing: 12
            opacity: win.hud && !win.pill && !win.notify && !win.open ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: win.hud ? 120 : 0 }
                    NumberAnimation { duration: win.hud ? 240 : 120 }
                }
            }

            readonly property bool off: Audio.muted || Audio.volume <= 0
            readonly property int cells: 20
            readonly property int lit: Math.round(Math.max(0, Math.min(1, Audio.volume)) * cells)

            Text {
                renderType: Text.CurveRendering
                anchors.verticalCenter: parent.verticalCenter
                text: parent.off ? "󰖁" : "󰕾"
                color: parent.off ? win.c.dangerText : win.c.text
                font.family: Theme.iconFont
                font.pixelSize: 18
            }

            // Segmented power-cell gauge (same as the sound flyout). Prototype: prototypes/sound-flyout/hud.html
            Item {
                id: gauge

                readonly property real step: width / parent.cells

                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 18 - 44 - 24
                height: 12

                Repeater {
                    model: gauge.parent.cells

                    delegate: Rectangle {
                        required property int index
                        readonly property bool on: index < gauge.parent.lit

                        // Pixel-snapped so every cell stays crisp.
                        x: Math.round(index * gauge.step)
                        width: Math.round((index + 1) * gauge.step) - x - 2
                        height: 12
                        radius: 1
                        color: !on ? "#26252A"
                            : gauge.parent.off ? "#4A494E"
                            : index === gauge.parent.lit - 1 ? win.c.accent : win.c.text

                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                }
            }

            Text {
                renderType: Text.CurveRendering
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 1
                width: 44
                horizontalAlignment: Text.AlignRight
                textFormat: Text.RichText
                text: Audio.muted ? "MUTE"
                    : Math.round(Math.max(0, Math.min(1, Audio.volume)) * 100)
                        + "<span style=\"font-size:9px; color:" + win.c.muted + "\">%</span>"
                color: Audio.muted ? win.c.dangerText : win.c.text
                font.family: Theme.displayFont
                font.pixelSize: Audio.muted ? 11 : 13
                font.letterSpacing: Audio.muted ? 1.5 : 0
                font.weight: Font.Medium
            }
        }

        // Hud pill: a glyph or an image, a label and a state (power actions, opening a tray app). Services/Hud.qml.
        Item {
            anchors.fill: parent
            opacity: win.pill && !win.notify ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: win.pill ? 120 : 0 }
                    NumberAnimation { duration: win.pill ? 240 : 120 }
                }
            }

            Text {
                visible: Hud.glyph !== ""
                x: 20
                anchors.verticalCenter: parent.verticalCenter
                text: Hud.glyph
                color: win.c.text
                renderType: Text.CurveRendering
                font.family: Theme.iconFont
                font.pixelSize: 16
            }

            Image {
                visible: Hud.image !== ""
                x: 20
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18
                source: Hud.image
                sourceSize: Qt.size(36, 36)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }

            Text {
                x: 48
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 1      // Orbitron's digits sit ~1px high at this size
                width: stateText.x - x - 8
                text: Hud.label
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: win.c.muted
                renderType: Text.CurveRendering
                font.family: Theme.displayFont
                font.pixelSize: 9
                font.letterSpacing: 1.6
                font.capitalization: Font.AllUppercase
            }

            Text {
                id: stateText

                x: parent.width - 20 - implicitWidth
                anchors.verticalCenter: parent.verticalCenter
                text: Hud.state
                textFormat: Text.PlainText
                color: win.c.text
                renderType: Text.CurveRendering
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.Medium
            }
        }

        // Notification popup (services/Notifications.qml). Prototype: prototypes/notifications/index.html
        NotificationToast {
            id: toastView

            opacity: win.notify ? 1 : 0
            visible: opacity > 0
            hovered: win.notify && Notifications.toastHovered
            onDismissed: Notifications.hideToast(true)

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: win.notify ? 120 : 0 }
                    NumberAnimation { duration: win.notify ? 240 : 120 }
                }
            }
        }

        // Tab switcher: top-left corner, level with the clock. Prototype: prototypes/island-media-tab/index.html
        Row {
            x: 28
            y: 26
            spacing: 18
            opacity: win.open ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: win.open ? 200 : 0 }
                    NumberAnimation { duration: win.open ? 320 : 140 }
                }
            }

            Repeater {
                model: [{ id: "agenda", label: "AGENDA" }, { id: "media", label: "MEDIA" }]

                delegate: Item {
                    id: tabItem

                    required property var modelData
                    readonly property bool active: win.tab === modelData.id

                    width: tabLabel.implicitWidth + (modelData.id === "media" ? 11 : 0)
                    height: 28

                    Text {
                        id: tabLabel
                        renderType: Text.CurveRendering
                        anchors.verticalCenter: parent.verticalCenter
                        text: tabItem.modelData.label
                        color: tabItem.active || tabArea.containsMouse ? win.c.text : win.c.muted
                        font.family: Theme.displayFont
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        font.letterSpacing: 2

                        Behavior on color { ColorAnimation { duration: 140 } }
                    }

                    // Something is playing: visible without switching tab.
                    Rectangle {
                        visible: tabItem.modelData.id === "media"
                        x: tabLabel.implicitWidth + 7
                        anchors.verticalCenter: parent.verticalCenter
                        width: 4
                        height: 4
                        radius: 2
                        color: win.c.accent
                        opacity: Media.playing ? 1 : 0
                        scale: Media.playing ? 1 : 0.4

                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        Behavior on scale { Ease { duration: 300 } }
                    }

                    MouseArea {
                        id: tabArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.tab = tabItem.modelData.id
                    }
                }
            }
        }

        // Expanded body: two panes (agenda: calendar | agenda, media), cross-faded. Opening un-blurs it, as in the prototype.
        Item {
            id: body

            property real veil: win.open ? 0 : 1      // 1 = blurred, 0 = sharp

            y: 100
            width: parent.width
            height: 300
            opacity: win.open ? 1 : 0
            scale: win.open ? 1 : 0.97
            transformOrigin: Item.Top
            visible: opacity > 0

            // Only rendered through the blur while it is animating, so settled text stays crisp.
            layer.enabled: veil > 0.001
            layer.effect: MultiEffect {
                blurEnabled: true
                blurMax: 32
                blur: body.veil * 0.25      // 0.25 of blurMax = 8 px
            }

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: win.open ? 140 : 0 }
                    NumberAnimation { duration: win.open ? 320 : 140 }
                }
            }
            Behavior on scale { Ease { duration: win.open ? 520 : 140 } }
            Behavior on veil {
                SequentialAnimation {
                    PauseAnimation { duration: win.open ? 140 : 0 }
                    NumberAnimation { duration: win.open ? 380 : 140 }
                }
            }

            Item {
                id: agendaView

                anchors.fill: parent
                opacity: win.tab === "agenda" ? 1 : 0
                visible: opacity > 0

                Behavior on opacity { NumberAnimation { duration: 140 } }

                CalendarPane {
                    x: 28
                    today: clock.date
                    viewDate: win.viewDate
                    selected: win.selected
                    onPicked: day => win.selected = day
                    onViewed: month => win.viewDate = month
                }

                Rectangle {
                    x: 28 + 308 + 28
                    width: 1
                    height: parent.height
                    color: win.c.border
                }

                AgendaPane {
                    x: 28 + 308 + 28 + 1 + 28
                    width: parent.width - x - 28
                    today: clock.date
                    selected: win.selected
                }
            }

            MediaPane {
                x: 28
                width: parent.width - 56
                height: parent.height
                opacity: win.tab === "media" ? 1 : 0
                visible: opacity > 0

                Behavior on opacity { NumberAnimation { duration: 140 } }
            }
        }
    }
}
