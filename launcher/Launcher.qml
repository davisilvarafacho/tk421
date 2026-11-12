import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

import "../theme"
import "Fuzzy.js" as Fuzzy

// Application launcher: replaces Hyprlauncher. Fullscreen overlay with the card at 24% height, over a light scrim.
// Prototype: prototypes/launcher/index.html (graphite and steel only, no hue). IPC: `launcher toggle|open|close|isOpen`.
PanelWindow {
    id: win

    readonly property var c: Theme.imperial
    readonly property int rowHeight: 38
    readonly property int maxRows: 6

    property bool open: false
    property string query: ""
    property var results: []        // [{ entry, name, idx }]
    property int current: 0
    // Last pointer position in window coordinates. Hover only selects on real movement: a list that changes
    // under a parked cursor makes Qt send a synthetic move, which must not steal the keyboard selection.
    property point pointer: Qt.point(-1, -1)

    // Height of the area under the search row: rows (+10 padding), the "no match" message, or nothing.
    readonly property int listHeight: results.length > 0
        ? Math.min(results.length, maxRows) * rowHeight + 10
        : query.trim() !== "" ? 64 : 0

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: open || panel.opacity > 0.01

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "tk421-launcher"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    component Ease: NumberAnimation {
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
    }

    function refresh() {
        const apps = DesktopEntries.applications.values.filter(e => !e.noDisplay)
        results = Fuzzy.rank(apps, query, 50)
        current = 0
    }

    function show() {
        input.text = ""
        query = ""
        refresh()
        pointer = Qt.point(-1, -1)
        open = true
        input.forceActiveFocus()
    }

    function hide() {
        open = false
    }

    function move(step) {
        if (results.length > 0)
            current = (current + step + results.length) % results.length
    }

    function launch(i) {
        const r = results[i]
        if (!r)
            return
        hide()
        r.entry.execute()
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            win.open ? win.hide() : win.show()
        }

        function open(): void {
            win.show()
        }

        function close(): void {
            win.hide()
        }

        function isOpen(): bool {
            return win.open
        }
    }

    // Click outside the card closes.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(5 / 255, 5 / 255, 5 / 255, 0.35)
        opacity: win.open ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 200 } }

        MouseArea {
            anchors.fill: parent
            onClicked: win.hide()
        }
    }

    Rectangle {
        id: panel

        width: 480
        height: 52 + win.listHeight
        x: (parent.width - width) / 2
        y: parent.height * 0.24 + (win.open ? 0 : -6)
        radius: 16
        color: Qt.alpha(win.c.surface, 0.72)    // Hyprland blurs what is behind it: layer rule in hypr/hyprland.lua
        border.width: 1
        border.color: win.c.border
        clip: true
        opacity: win.open ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: win.open ? 180 : 120 } }
        Behavior on y { Ease { duration: win.open ? 320 : 200 } }
        Behavior on height { Ease { duration: 180 } }

        // Swallows clicks on the card so they do not reach the scrim.
        MouseArea { anchors.fill: parent }

        Item {
            id: search

            width: parent.width
            height: 52

            Image {
                id: mark

                x: 18
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                height: 22
                source: Qt.resolvedUrl("../assets/deathstar.svg")
                sourceSize: Qt.size(44, 44)
                smooth: true
            }

            Text {
                id: tag

                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                text: "TK-421"
                color: win.c.muted
                opacity: 0.6
                font.family: Theme.displayFont
                font.pixelSize: 9
                font.weight: Font.Medium
                font.letterSpacing: 2.2
                renderType: Text.CurveRendering
            }

            TextInput {
                id: input

                x: mark.x + mark.width + 12
                width: tag.x - x - 12
                anchors.verticalCenter: parent.verticalCenter
                color: win.c.text
                selectionColor: win.c.border
                selectedTextColor: win.c.text
                font.family: Theme.fontFamily
                font.pixelSize: 16
                clip: true
                renderType: Text.CurveRendering
                cursorDelegate: Rectangle {
                    width: 1
                    color: win.c.text
                }

                onTextChanged: {
                    win.query = text
                    win.refresh()
                }

                Keys.onPressed: event => {
                    const ctrl = event.modifiers & Qt.ControlModifier
                    if (event.key === Qt.Key_Escape) {
                        win.hide()
                    } else if (event.key === Qt.Key_Down || (ctrl && event.key === Qt.Key_N)) {
                        win.move(1)
                    } else if (event.key === Qt.Key_Up || (ctrl && event.key === Qt.Key_P)) {
                        win.move(-1)
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        win.launch(win.current)
                    } else {
                        return
                    }
                    event.accepted = true
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text.length === 0
                    text: "AWAITING ORDERS..."
                    color: win.c.muted
                    opacity: 0.55
                    font.family: Theme.displayFont
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    font.letterSpacing: 2.9
                    renderType: Text.CurveRendering
                }
            }

            // The only decoration: a steel hairline that draws in under the input.
            Rectangle {
                anchors.bottom: parent.bottom
                height: 1
                width: win.open ? parent.width : 0
                color: win.c.accent

                Behavior on width {
                    enabled: win.open
                    Ease { duration: 360 }
                }
            }
        }

        ListView {
            id: list

            y: 54
            x: 8
            width: parent.width - 16
            height: Math.min(win.results.length, win.maxRows) * win.rowHeight
            model: win.results
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            visible: win.results.length > 0

            Connections {
                target: win

                function onCurrentChanged() {
                    list.positionViewAtIndex(win.current, ListView.Contain)
                }

                function onResultsChanged() {
                    list.positionViewAtBeginning()
                }
            }

            delegate: Rectangle {
                id: row

                required property var modelData
                required property int index
                readonly property bool sel: index === win.current

                width: ListView.view.width
                height: win.rowHeight
                radius: 10
                color: sel ? win.c.surfaceAlt : "transparent"

                Behavior on color { ColorAnimation { duration: 140 } }

                // 2 px selection rail
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 2
                    height: row.sel ? 16 : 0
                    radius: 2
                    color: win.c.accent

                    Behavior on height { Ease { duration: 180 } }
                }

                // The app's icon from the active icon theme, drawn grey so the launcher stays hueless (chosen with the
                // user: "candy grey", prototypes/launcher/index.html). Without an icon the initials tile stays.
                Rectangle {
                    id: tile

                    readonly property string iconName: row.modelData.entry.icon ?? ""
                    readonly property string iconSource: iconName === "" ? ""
                        : iconName.startsWith("/") ? "file://" + iconName
                        : Quickshell.iconPath(iconName, true)
                    readonly property bool hasIcon: appIcon.status === Image.Ready

                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 22
                    radius: 6
                    color: hasIcon ? "transparent" : row.sel ? win.c.bg : win.c.surfaceAlt

                    Behavior on color { ColorAnimation { duration: 140 } }

                    Image {
                        id: appIcon

                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        source: tile.iconSource
                        sourceSize: Qt.size(40, 40)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        visible: tile.hasIcon
                        opacity: row.sel ? 1 : 0.62
                        layer.enabled: visible
                        layer.effect: MultiEffect {
                            saturation: -1
                        }

                        Behavior on opacity { NumberAnimation { duration: 140 } }
                    }

                    Text {
                        visible: !tile.hasIcon
                        anchors.centerIn: parent
                        text: Fuzzy.initials(row.modelData.name)
                        textFormat: Text.PlainText
                        color: row.sel ? win.c.text : win.c.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        renderType: Text.CurveRendering
                    }
                }

                Text {
                    id: num

                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(row.index + 1).padStart(2, "0")
                    color: row.sel ? win.c.text : win.c.muted
                    opacity: row.sel ? 0.9 : 0.4
                    font.family: Theme.displayFont
                    font.pixelSize: 9
                    font.weight: Font.Medium
                    font.letterSpacing: 1.8
                    renderType: Text.CurveRendering
                }

                // Names come from desktop entries: Fuzzy.markup escapes them before StyledText sees them.
                Text {
                    x: tile.x + tile.width + 14
                    width: num.x - x - 12
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.StyledText
                    text: Fuzzy.markup(row.modelData.name, row.modelData.idx, row.sel ? "#ffffff" : win.c.text)
                    color: row.sel ? win.c.text : win.c.muted
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    renderType: Text.CurveRendering
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onPositionChanged: mouse => {
                        const p = mapToItem(null, mouse.x, mouse.y)
                        const first = win.pointer.x < 0
                        const moved = p.x !== win.pointer.x || p.y !== win.pointer.y
                        win.pointer = p
                        if (!first && moved)
                            win.current = row.index
                    }
                    onClicked: win.launch(row.index)
                }
            }
        }

        Column {
            x: 18
            y: 52 + 2 + 14
            spacing: 10
            visible: win.results.length === 0 && win.query.trim() !== ""

            Text {
                text: "NEGATIVE"
                color: win.c.muted
                font.family: Theme.displayFont
                font.pixelSize: 10
                font.weight: Font.Medium
                font.letterSpacing: 2.6
                renderType: Text.CurveRendering
            }

            Text {
                width: panel.width - 36
                text: "No program named “" + win.query.trim() + "”."
                textFormat: Text.PlainText
                color: win.c.muted
                opacity: 0.75
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: 13
                renderType: Text.CurveRendering
            }
        }
    }
}
