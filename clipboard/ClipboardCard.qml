import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

import "../launcher/Fuzzy.js" as Fuzzy
import "../services"
import "../theme"
import "logic.js" as Logic

// Clipboard archive (SUPER+H): replaces `cliphist list | fuzzel`. Same card as the launcher; text previews under the list,
// image previews beside it. Prototype: prototypes/clipboard/index.html. IPC: `clipboard toggle|open|close|isOpen`.
// Enter puts the record back on the clipboard, Ctrl+Enter also pastes it, Del removes it.
PanelWindow {
    id: win

    readonly property var c: Theme.imperial
    readonly property int rowHeight: 38
    readonly property int maxRows: 6
    readonly property int listWidth: 544        // the list never stretches when the card widens for an image

    property bool open: false
    property string query: ""
    property var records: []            // every record of `cliphist list`
    property var results: []            // [{ rec, name, idx }], at most Logic.LIMIT
    property int current: 0
    property string previewBody: ""     // full text of the selected text record
    property point pointer: Qt.point(-1, -1)   // see launcher/Launcher.qml: hover only selects on real movement

    readonly property var selected: current < results.length ? results[current].rec : null
    readonly property bool sideImage: selected !== null && selected.kind === "image"
    readonly property int rowsHeight: Math.min(results.length, maxRows) * rowHeight
    readonly property int bodyHeight: results.length === 0 ? 64
        : sideImage ? Math.max(rowsHeight + 12, 304)
        : rowsHeight + 12 + 128

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
    WlrLayershell.namespace: "tk421-clipboard"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    component Ease: NumberAnimation {
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
    }

    function refresh() {
        results = Logic.rank(records, query, Logic.LIMIT)
        current = Math.min(current, Math.max(results.length - 1, 0))
    }

    function show() {
        input.text = ""
        query = ""
        current = 0
        results = []
        previewBody = ""
        pointer = Qt.point(-1, -1)
        listProc.running = true
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

    // The preview of a text record is its whole text (first bytes); until it arrives the flattened preview stands in.
    function loadText(id) {
        if (textProc.running) {
            textProc.queued = id
            return
        }
        textProc.forId = id
        textProc.command = ["sh", "-c", 'cliphist decode "$1" | head -c "$2"', "_", String(id), String(Logic.TEXT_BYTES)]
        textProc.running = true
    }

    function pick(i, paste) {
        const r = results[i]?.rec
        if (!r)
            return
        hide()
        if (paste) {
            Quickshell.execDetached(["lua", Quickshell.shellPath("clipboard/paste.lua"), String(r.id)])
            Hud.show("ARCHIVE", "pasted", "", "")
        } else {
            Quickshell.execDetached(["sh", "-c", 'cliphist decode "$1" | wl-copy', "_", String(r.id)])
            Hud.show("ARCHIVE", "copied", "", "")
        }
    }

    function purge(i) {
        const r = results[i]?.rec
        if (!r)
            return
        Quickshell.execDetached(["sh", "-c",
            'printf "%s\\t\\n" "$1" | cliphist delete; rm -f "$2/$1.bin"',
            "_", String(r.id), Quickshell.env("XDG_RUNTIME_DIR") + "/tk421-clipboard"])
        records = records.filter(x => x.id !== r.id)
        refresh()
        Hud.show("ARCHIVE", "purged", "", "")
    }

    onSelectedChanged: previewTimer.restart()

    Timer {
        id: previewTimer
        interval: 50

        onTriggered: {
            const r = win.selected
            if (r === null || r.kind === "image")
                return
            win.previewBody = r.preview
            win.loadText(r.id)
        }
    }

    Process {
        id: listProc

        command: ["cliphist", "list"]

        stdout: StdioCollector {
            onStreamFinished: {
                win.records = Logic.parseList(text)
                win.refresh()
            }
        }
    }

    Process {
        id: textProc

        property int forId: -1
        property int queued: -1

        stdout: StdioCollector {
            onStreamFinished: {
                if (textProc.forId === win.selected?.id)
                    win.previewBody = Logic.previewText(text, 5)
            }
        }

        onExited: {
            if (queued >= 0) {
                const id = queued
                queued = -1
                win.loadText(id)
            }
        }
    }

    IpcHandler {
        target: "clipboard"

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

        width: win.sideImage ? 880 : 560
        height: 52 + win.bodyHeight
        x: (parent.width - width) / 2
        y: parent.height * 0.18 + (win.open ? 0 : -6)
        radius: 16
        color: Qt.alpha(win.c.surface, 0.72)    // Hyprland blurs what is behind it: layer rule in hypr/hyprland.lua
        border.width: 1
        border.color: win.c.border
        clip: true
        opacity: win.open ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: win.open ? 180 : 120 } }
        Behavior on y { Ease { duration: win.open ? 320 : 200 } }
        Behavior on width { Ease { duration: 320 } }
        Behavior on height { Ease { duration: 180 } }

        // Swallows clicks on the card so they do not reach the scrim.
        MouseArea { anchors.fill: parent }

        Item {
            id: search

            width: parent.width
            height: 52

            Text {
                id: mark

                x: 18
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                horizontalAlignment: Text.AlignHCenter
                text: ""
                color: input.activeFocus ? win.c.text : win.c.muted
                renderType: Text.CurveRendering
                font.family: Theme.iconFont
                font.pixelSize: 17

                Behavior on color { ColorAnimation { duration: 140 } }
            }

            Text {
                id: tag

                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                visible: win.records.length > 0
                text: win.records.length + " RECORDS"
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
                    win.current = 0
                    win.refresh()
                }

                Keys.onPressed: event => {
                    const ctrl = event.modifiers & Qt.ControlModifier
                    const enter = event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                    if (event.key === Qt.Key_Escape) {
                        win.hide()
                    } else if (event.key === Qt.Key_Down || (ctrl && event.key === Qt.Key_N)) {
                        win.move(1)
                    } else if (event.key === Qt.Key_Up || (ctrl && event.key === Qt.Key_P)) {
                        win.move(-1)
                    } else if (enter) {
                        win.pick(win.current, ctrl)
                    } else if (event.key === Qt.Key_Delete && input.cursorPosition === input.text.length) {
                        win.purge(win.current)      // at the end of the query Del has nothing to delete in the field
                    } else {
                        return
                    }
                    event.accepted = true
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text.length === 0
                    text: "SEARCH THE ARCHIVE"
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
            width: win.listWidth
            height: win.rowsHeight
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

                function onQueryChanged() {
                    list.positionViewAtBeginning()
                }
            }

            delegate: Rectangle {
                id: row

                required property var modelData
                required property int index
                readonly property bool sel: index === win.current
                readonly property string kind: modelData.rec.kind

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

                Rectangle {
                    id: tile

                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 22
                    radius: 6
                    color: row.sel ? win.c.bg : win.c.surfaceAlt
                    clip: true

                    Behavior on color { ColorAnimation { duration: 140 } }

                    Text {
                        anchors.centerIn: parent
                        visible: row.kind !== "image"
                        text: row.kind === "link" ? "" : row.kind === "code" ? "" : ""
                        color: row.sel ? win.c.text : win.c.muted
                        renderType: Text.CurveRendering
                        font.family: Theme.iconFont
                        font.pixelSize: 11
                    }

                    Loader {
                        anchors.fill: parent
                        active: row.kind === "image"

                        sourceComponent: ClipImage {
                            recordId: row.modelData.rec.id
                        }
                    }
                }

                Text {
                    id: tagText

                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 1
                    text: row.modelData.rec.meta
                    textFormat: Text.PlainText
                    color: row.sel ? win.c.text : win.c.muted
                    opacity: row.sel ? 0.9 : 0.45
                    font.family: Theme.displayFont
                    font.pixelSize: 9
                    font.weight: Font.Medium
                    font.letterSpacing: 1.8
                    renderType: Text.CurveRendering
                }

                // Records come from other apps and pages: Fuzzy.markup escapes them before StyledText sees them.
                Text {
                    x: tile.x + tile.width + 14
                    width: tagText.x - x - 12
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.StyledText
                    text: row.kind === "image" ? "Image"
                        : Fuzzy.markup(row.modelData.name, row.modelData.idx, row.sel ? "#ffffff" : win.c.text)
                    color: row.sel ? win.c.text : win.c.muted
                    elide: Text.ElideRight
                    font.family: row.kind === "code" ? Theme.monoFont : Theme.fontFamily
                    font.pixelSize: row.kind === "code" ? 12.5 : 14
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
                    onClicked: win.pick(row.index, false)
                }
            }
        }

        // Text, link and code records: the whole text under the list.
        Item {
            x: 8
            y: 54 + win.rowsHeight + 4
            width: win.listWidth
            height: 124
            visible: win.selected !== null && !win.sideImage

            Rectangle {
                width: parent.width
                height: 1
                color: win.c.border
            }

            Row {
                x: 10
                y: 12
                width: parent.width - 20
                height: 12

                Text {
                    text: "RECORD " + Logic.recordLabel(win.current + 1)
                    color: win.c.muted
                    font.family: Theme.displayFont
                    font.pixelSize: 9
                    font.letterSpacing: 2
                    renderType: Text.CurveRendering
                }
            }

            Text {
                x: 10
                y: 12
                width: parent.width - 20
                horizontalAlignment: Text.AlignRight
                text: win.selected?.meta ?? ""
                color: win.c.muted
                font.family: Theme.displayFont
                font.pixelSize: 9
                font.letterSpacing: 2
                renderType: Text.CurveRendering
            }

            Text {
                x: 10
                y: 32
                width: parent.width - 20
                height: 88
                text: win.previewBody
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                maximumLineCount: 5
                elide: Text.ElideRight
                color: win.c.text
                opacity: 0.92
                font.family: win.selected?.kind === "code" ? Theme.monoFont : Theme.fontFamily
                font.pixelSize: win.selected?.kind === "code" ? 12 : 13
                lineHeight: 17.6
                lineHeightMode: Text.FixedHeight
                renderType: Text.CurveRendering
            }
        }

        // Image records: the picture beside the list.
        Item {
            x: 8 + win.listWidth + 8
            y: 54
            width: panel.width - x - 8
            height: parent.height - 54 - 12
            visible: win.sideImage

            Rectangle {
                width: 1
                height: parent.height
                color: win.c.border
            }

            Rectangle {
                x: 14
                width: parent.width - 14
                height: 224
                radius: 8
                color: "transparent"
                border.width: 1
                border.color: win.c.border
                clip: true

                Repeater {
                    model: win.sideImage ? [win.selected.id] : []

                    delegate: ClipImage {
                        required property int modelData

                        anchors.fill: parent
                        recordId: modelData
                        fillMode: Image.PreserveAspectFit
                        decodeSize: 1200
                    }
                }
            }

            Column {
                x: 14
                y: 236
                spacing: 8

                Text {
                    text: "RECORD " + Logic.recordLabel(win.current + 1)
                    color: win.c.muted
                    font.family: Theme.displayFont
                    font.pixelSize: 9
                    font.letterSpacing: 2
                    renderType: Text.CurveRendering
                }

                Text {
                    text: win.selected ? win.selected.meta + " · " + win.selected.size : ""
                    textFormat: Text.PlainText
                    color: win.c.muted
                    font.family: Theme.displayFont
                    font.pixelSize: 9
                    font.letterSpacing: 2
                    renderType: Text.CurveRendering
                }
            }
        }

        Column {
            x: 18
            y: 52 + 2 + 14
            spacing: 10
            visible: win.results.length === 0

            Text {
                text: win.query.trim() !== "" ? "NO MATCH" : "NO RECORDS"
                color: win.c.muted
                font.family: Theme.displayFont
                font.pixelSize: 10
                font.weight: Font.Medium
                font.letterSpacing: 2.6
                renderType: Text.CurveRendering
            }

            Text {
                width: panel.width - 36
                text: win.query.trim() !== "" ? "Nothing in the archive matches “" + win.query.trim() + "”."
                    : "The archive is empty."
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
