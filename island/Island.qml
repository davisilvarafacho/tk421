import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

import "../components"
import "../services"
import "../theme"

// Dynamic Island: replaces the bar clock. Idle pill -> media pill -> volume HUD -> calendar/agenda card.
// Priority: open > hud > media > idle. Hangs from the top edge of the screen (see `silhouette`). Prototype: prototypes/dynamic-island/index.html
PanelWindow {
    id: win

    readonly property var c: Theme.imperial

    readonly property int idleHeight: 42      // the island hangs from the top edge of the screen
    readonly property int contentCenter: 19   // clock, art and equalizer sit here; the rest of the idle height is bottom padding
    readonly property int flare: 10           // radius of the concave curve where it meets the edge

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
    margins.top: 0      // flush with the screen edge
    implicitWidth: 880      // the open card (820) plus a flare on each side
    implicitHeight: 510
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

    // 0 while the card is shorter than `bottom` (the lower edge of a piece of content) plus 40 px, 1 once it clears
    // it by 100 px: content is gone before the collapsing card gets down to it.
    function reveal(bottom) {
        return Math.max(0, Math.min(1, (card.height - bottom - 40) / 60))
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

        // Select a day of the agenda (YYYY-MM-DD), for visual checks.
        function selectDate(iso: string): void {
            const p = iso.split("-")
            const day = new Date(parseInt(p[0]), parseInt(p[1]) - 1, parseInt(p[2]))

            if (!isNaN(day.getTime())) {
                win.selected = day
                win.viewDate = day
            }
        }
    }

    // Silhouette of the card: stuck to the top edge, concave flares where it meets the edge, rounded bottom
    // corners. It follows the card's animated size; the card itself only clips and positions the content.
    Shape {
        id: silhouette

        readonly property real f: win.flare
        readonly property real w: card.width
        readonly property real h: card.height
        readonly property real r: Math.max(0, Math.min(card.radius, h - f, w / 2))

        anchors.horizontalCenter: card.horizontalCenter
        y: 0
        width: w + 2 * f
        height: h
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: win.c.ink
            // A faint light hairline: the grey Imperial border read as a halo against bright wallpapers.
            strokeColor: win.notify && toastView.critical ? win.c.danger : win.c.hairline
            strokeWidth: 1

            // Starts above the screen so the closing top line is never drawn.
            startX: 0
            startY: -2
            PathLine { x: 0; y: 0 }
            PathArc { x: silhouette.f; y: silhouette.f; radiusX: silhouette.f; radiusY: silhouette.f; direction: PathArc.Clockwise }
            PathLine { x: silhouette.f; y: silhouette.h - silhouette.r }
            PathArc { x: silhouette.f + silhouette.r; y: silhouette.h; radiusX: silhouette.r; radiusY: silhouette.r; direction: PathArc.Counterclockwise }
            PathLine { x: silhouette.f + silhouette.w - silhouette.r; y: silhouette.h }
            PathArc { x: silhouette.f + silhouette.w; y: silhouette.h - silhouette.r; radiusX: silhouette.r; radiusY: silhouette.r; direction: PathArc.Counterclockwise }
            PathLine { x: silhouette.f + silhouette.w; y: silhouette.f }
            PathArc { x: silhouette.w + 2 * silhouette.f; y: 0; radiusX: silhouette.f; radiusY: silhouette.f; direction: PathArc.Clockwise }
            PathLine { x: silhouette.w + 2 * silhouette.f; y: -2 }
        }
    }

    Rectangle {
        id: card

        anchors.horizontalCenter: parent.horizontalCenter
        y: 0

        width: win.open ? 820 : win.notify ? 360 : win.pill ? 290 : win.hud ? 340 : win.playing ? 216 : 144
        height: win.open ? 456 : win.notify ? toastView.height : win.pill || win.hud ? 52 : win.idleHeight
        radius: 18      // one radius in every state; leaves a straight wall below the flare in the idle pill (38 - 10 - 18)
        color: "transparent"
        clip: true
        // SUPER+Space: the launcher (launcher/Launcher.qml, Overlay layer) grows out of this exact shape and covers it.
        opacity: Launch.open ? 0 : 1

        Behavior on opacity { NumberAnimation { duration: Launch.open ? 0 : 200 } }

        Binding { target: Launch; property: "islandWidth"; value: card.width }
        Binding { target: Launch; property: "islandHeight"; value: card.height }

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
            x: 16
            anchors.verticalCenter: parent.top
            anchors.verticalCenterOffset: win.contentCenter
            width: 22
            height: 22
            radius: 6
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

            x: parent.width - width - 16      // width is 16: 4 bars of 2px + 3 gaps
            anchors.verticalCenter: parent.top
            anchors.verticalCenterOffset: win.contentCenter
            spacing: 8 / 3
            opacity: win.playing && !win.open && !win.hud && !win.pill && !win.notify ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: 200 } }

            Repeater {
                model: [900, 640, 780, 560]

                delegate: Item {
                    required property int modelData

                    width: 2
                    height: 14

                    Rectangle {
                        id: bar
                        anchors.bottom: parent.bottom
                        width: 2
                        height: 14 * 0.3
                        color: win.c.text

                        SequentialAnimation on height {
                            running: win.playing && eq.opacity > 0
                            loops: Animation.Infinite
                            NumberAnimation { to: 14; duration: modelData; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 4; duration: modelData; easing.type: Easing.InOutSine }
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
            y: win.open ? 22 : 7      // 7 puts the Orbitron digits' ink at the pill's vertical centre
            scale: win.open ? 1 : 0.66
            transformOrigin: Item.Top
            opacity: (win.hud || win.pill || win.notify) && !win.open ? 0 : 1
            textFormat: Text.RichText
            text: Qt.formatTime(clock.date, "HH:mm") + "<font color=\"" + win.c.muted + "\">:" + Qt.formatTime(clock.date, "ss") + "</font>"
            color: win.c.text
            font.family: Theme.displayFont
            font.pixelSize: 30
            font.weight: Font.Medium
            font.letterSpacing: 2

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
            property real shown: win.open ? 1 : 0
            opacity: shown * win.reveal(80)

            Behavior on y { Ease { duration: 420 } }
            Behavior on shown {
                SequentialAnimation {
                    PauseAnimation { duration: win.open ? 160 : 0 }
                    NumberAnimation { duration: win.open ? 320 : 60 }
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

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: parent.off ? "volume_off" : "volume_up"
                size: 18
                color: parent.off ? win.c.dangerText : win.c.text
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

            Icon {
                visible: Hud.glyph !== ""
                x: 20
                anchors.verticalCenter: parent.verticalCenter
                name: Hud.glyph
                size: Theme.iconSize.bar      // the label starts at x 48: a 24 px hero glyph would leave 4 px
                color: win.c.text
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

        // Tab switcher: a segmented pill in the top-left corner, level with the clock; the highlight slides.
        // Closing: the card collapses fast (ease-out). Each piece of content also fades with the card's height
        // (`reveal`), so it is gone by the time the card gets smaller than it, instead of poking out of the silhouette.
        Item {
            id: switcher

            x: 24
            y: 24
            width: switcherRow.implicitWidth + 8
            height: 36
            property real shown: win.open ? 1 : 0
            opacity: shown * win.reveal(60)
            visible: opacity > 0

            Behavior on shown {
                SequentialAnimation {
                    PauseAnimation { duration: win.open ? 200 : 0 }
                    NumberAnimation { duration: win.open ? 320 : 60 }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.06)
            }

            Rectangle {
                readonly property Item current: win.tab === "agenda" ? calendarTab : mediaTab

                x: 4 + current.x
                y: 4
                width: current.width
                height: 28
                radius: 14
                color: Qt.rgba(1, 1, 1, 0.14)

                Behavior on x { Ease { duration: 320 } }
                Behavior on width { Ease { duration: 320 } }
            }

            Row {
                id: switcherRow

                x: 4
                y: 4

                SegTab {
                    id: calendarTab
                    glyph: "calendar_today"
                    label: "Calendar"
                    active: win.tab === "agenda"
                    onClicked: win.tab = "agenda"
                }

                SegTab {
                    id: mediaTab
                    glyph: "music_note"
                    label: "Media"
                    active: win.tab === "media"
                    live: Media.playing
                    onClicked: win.tab = "media"
                }
            }
        }

        // Expanded body: two panes (agenda: calendar | agenda, media), cross-faded. Opening un-blurs it, as in the prototype.
        Item {
            id: body

            property real veil: win.open ? 0 : 1      // 1 = blurred, 0 = sharp

            y: 100
            width: parent.width
            height: 332
            property real shown: win.open ? 1 : 0
            opacity: shown * win.reveal(140)
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

            Behavior on shown {
                SequentialAnimation {
                    PauseAnimation { duration: win.open ? 140 : 0 }
                    NumberAnimation { duration: win.open ? 320 : 60 }
                }
            }
            Behavior on scale { Ease { duration: win.open ? 520 : 60 } }
            Behavior on veil {
                SequentialAnimation {
                    PauseAnimation { duration: win.open ? 140 : 0 }
                    NumberAnimation { duration: win.open ? 380 : 60 }
                }
            }

            Item {
                id: agendaView

                width: parent.width
                height: parent.height
                x: win.tab === "agenda" ? 0 : -24
                opacity: win.tab === "agenda" ? 1 : 0
                visible: opacity > 0

                Behavior on x { Ease { duration: 320 } }
                Behavior on opacity { NumberAnimation { duration: 180 } }

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
                    y: 6
                    width: 1
                    height: parent.height - 12
                    color: Qt.rgba(1, 1, 1, 0.08)
                }

                AgendaPane {
                    x: 28 + 308 + 28 + 1 + 28
                    width: parent.width - x - 28
                    today: clock.date
                    selected: win.selected
                }
            }

            MediaPane {
                x: win.tab === "media" ? 28 : 28 + 24
                width: parent.width - 56
                height: parent.height
                opacity: win.tab === "media" ? 1 : 0
                visible: opacity > 0

                Behavior on x { Ease { duration: 320 } }
                Behavior on opacity { NumberAnimation { duration: 180 } }
            }
        }
    }
}
