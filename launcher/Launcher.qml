import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

import "../components"
import "../services"
import "../theme"
import "Fuzzy.js" as Fuzzy
import "logic.js" as Logic

// SUPER+Space: the Dynamic Island grows into the launcher (prototype prototypes/launcher/island.html, surface brief
// .impeccable/surfaces/launcher-launcher-qml.md). A fullscreen Overlay window: scrim, then the island silhouette, which
// starts at the island's current size (Launch.islandWidth/Height, written by island/Island.qml) and grows to 820x456.
// Left: ranked list (Frequent / Recent / All apps when empty). Right: the selected item's detail with an isometric
// object (assets/iso, from Isoflow). Prefixes: = calculate, > shell commands, @ open windows.
// IPC: `launcher toggle|open|close|isOpen`.
PanelWindow {
    id: win

    readonly property var c: Theme.imperial
    readonly property int cardWidth: 820
    readonly property int cardHeight: 456
    readonly property int flare: 10
    readonly property int searchHeight: 60
    readonly property int footHeight: 40
    readonly property int listWidth: 392
    readonly property int rowHeight: 40

    property bool open: false
    property bool expanded: false
    property bool shown: false
    property string query: ""
    readonly property var parsed: Logic.parse(query)
    property var items: []          // display list: rows and section headers
    property var rows: []           // selectable rows only, in display order
    property int current: 0
    property int actIndex: -1       // >= 0 while the arrow keys walk the selected app's own actions
    readonly property var sel: rows[current] ?? null
    property double now: Date.now()
    // Hover only selects on real pointer movement: a list that changes under a parked cursor makes Qt send a
    // synthetic move, which must not steal the keyboard selection.
    property point pointer: Qt.point(-1, -1)

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: shown

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "tk421-launcher"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    component Ease: NumberAnimation {
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
    }

    // ---------- model ----------

    function iconSourceOf(entry) {
        const name = entry?.icon ?? ""
        if (name === "")
            return ""
        return name.startsWith("/") ? "file://" + name : Quickshell.iconPath(name, true)
    }

    // Open windows per desktop entry id, and the window list for "@".
    function windows() {
        const out = []
        for (const t of Hyprland.toplevels.values) {
            const cls = t.lastIpcObject?.class ?? ""
            const entry = cls !== "" ? DesktopEntries.heuristicLookup(cls) : null
            out.push({ title: t.title || cls, address: t.address, ws: t.workspace?.id ?? 0, entry: entry, cls: cls })
        }
        return out
    }

    function appRow(entry, wins, extra) {
        const h = Launch.history[entry.id] ?? { hits: 0, last: 0 }
        let open = 0
        for (const w of wins) {
            if (w.entry && w.entry.id === entry.id)
                open++
        }
        return Object.assign({
            kind: "app", entry: entry, name: entry.name, sub: entry.genericName || "", text: entry.comment || "",
            idx: [], right: "", source: iconSourceOf(entry), glyph: "", iso: Logic.isoFor(entry.categories),
            hits: h.hits, last: h.last, windows: open,
            actions: (entry.actions ?? []).map(a => a.name)
        }, extra || {})
    }

    function build() {
        const p = parsed
        const out = []
        const header = label => out.push({ header: true, name: label })
        const push = row => out.push(row)
        const wins = windows()

        if (p.mode === "calc") {
            if (p.body !== "") {
                const v = Logic.calc(p.body)
                push({ kind: "calc", name: v === null ? "Not a calculation yet" : Logic.formatNumber(v), value: v,
                    sub: p.body, idx: [], right: "", source: "", glyph: "calculate", iso: "function-module", actions: [] })
            }
        } else if (p.mode === "shell") {
            const found = []
            for (const cmd of Logic.COMMANDS) {
                const m = Fuzzy.match(cmd.name, p.body)
                if (m)
                    found.push({ cmd: cmd, m: m })
            }
            if (p.body !== "")
                found.sort((a, b) => b.m.score - a.m.score)
            for (const f of found)
                push({ kind: "cmd", cmd: f.cmd, name: f.cmd.name, sub: f.cmd.hint, text: f.cmd.text, idx: f.m.idx,
                    right: f.cmd.hint, source: "", glyph: f.cmd.icon, iso: f.cmd.iso, actions: [] })
        } else if (p.mode === "windows") {
            const found = []
            for (const w of wins) {
                const m = Fuzzy.match(w.title, p.body) ?? (w.entry && Fuzzy.match(w.entry.name, p.body) ? { score: 0, idx: [] } : null)
                if (m)
                    found.push({ w: w, m: m })
            }
            found.sort((a, b) => p.body !== "" ? b.m.score - a.m.score : a.w.ws - b.w.ws)
            for (const f of found) {
                const appName = f.w.entry?.name ?? f.w.cls
                push({ kind: "win", address: f.w.address, ws: f.w.ws, name: f.w.title, sub: appName, idx: f.m.idx,
                    right: "ws " + f.w.ws, text: "Enter switches to workspace " + f.w.ws + " and focuses this window.",
                    source: iconSourceOf(f.w.entry), glyph: "", iso: "desktop", initials: appName, actions: [] })
            }
        } else {
            const apps = DesktopEntries.applications.values.filter(e => !e.noDisplay)
            if (p.body === "") {
                const byId = {}
                for (const e of apps)
                    byId[e.id] = e
                const ids = Object.keys(byId)
                const freq = Logic.frequent(ids, Launch.history, 4)
                const rec = Logic.recent(ids, Launch.history, freq, 3)
                if (freq.length) {
                    header("Frequent")
                    for (const id of freq)
                        push(appRow(byId[id], wins))
                }
                if (rec.length) {
                    header("Recent")
                    for (const id of rec)
                        push(appRow(byId[id], wins, { right: Logic.ago(Launch.history[id].last, now) }))
                }
                header("All apps")
                const rest = apps.filter(e => freq.indexOf(e.id) < 0 && rec.indexOf(e.id) < 0)
                    .sort((a, b) => a.name.localeCompare(b.name))
                for (const e of rest)
                    push(appRow(e, wins))
            } else {
                const ranked = []
                for (const e of apps) {
                    const m = Fuzzy.match(e.name, p.body)
                    if (m)
                        ranked.push({ e: e, m: m, s: m.score + Logic.boost(Launch.history[e.id]?.hits ?? 0) })
                }
                ranked.sort((a, b) => (b.s - a.s) || a.e.name.localeCompare(b.e.name))
                for (const r of ranked.slice(0, 50))
                    push(appRow(r.e, wins, { idx: r.m.idx }))
            }
        }

        const selectable = []
        for (const it of out) {
            if (!it.header) {
                it.ri = selectable.length
                selectable.push(it)
            }
        }
        items = out
        rows = selectable
        current = 0
        actIndex = -1
    }

    function show() {
        now = Date.now()
        Hyprland.refreshToplevels()
        input.text = ""
        query = ""
        build()
        pointer = Qt.point(-1, -1)
        hideTimer.stop()
        shown = true
        open = true
        Launch.open = true
        input.forceActiveFocus()
        Qt.callLater(() => win.expanded = win.open)
    }

    function hide() {
        if (!open)
            return
        open = false
        expanded = false
        Launch.open = false
        hideTimer.restart()
    }

    function move(step) {
        if (rows.length > 0) {
            current = (current + step + rows.length) % rows.length
            actIndex = -1
        }
    }

    function shellIpc(target, fn) {
        Quickshell.execDetached(["qs", "ipc", "-p", Quickshell.shellPath("shell.qml"), "call", target, fn])
    }

    // Runs after the launcher has let go of the keyboard, so a window that takes focus (clipboard, wallpaper) gets it.
    property var pending: null

    Timer {
        id: runTimer
        interval: 120
        onTriggered: {
            const job = win.pending
            win.pending = null
            if (job)
                job()
        }
    }

    function activate(i) {
        const r = rows[i]
        if (!r)
            return
        let job = null

        if (r.kind === "app") {
            const action = actIndex >= 0 ? (r.entry.actions ?? [])[actIndex] : null
            const entry = r.entry
            const label = action ? action.name : r.name
            job = () => {
                action ? action.execute() : entry.execute()
                Launch.record(entry.id)
                Hud.show("Opening", label, "", win.iconSourceOf(entry))
            }
        } else if (r.kind === "win") {
            const addr = String(r.address).startsWith("0x") ? r.address : "0x" + r.address
            job = () => Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ window = \"address:" + addr + "\" })"])
        } else if (r.kind === "calc") {
            if (r.value === null)
                return
            const text = String(r.value)
            job = () => {
                Quickshell.execDetached(["wl-copy", "--", text])
                Hud.show("Copied", r.name, "content_copy", "")
            }
        } else if (r.kind === "cmd") {
            const run = r.cmd.run.split(":")
            const asks = r.cmd.asks === true
            job = () => {
                if (run[0] === "power" && asks) {
                    Dropdown.open("power")
                    Power.ask(run[1])
                } else if (run[0] === "power") {
                    Power.run(run[1])
                } else {
                    win.shellIpc(run[1], run[2])
                }
            }
        }

        hide()
        pending = job
        runTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 380      // the 340 ms collapse, then the window goes
        onTriggered: win.shown = false
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

        // For visual checks: type into the open launcher.
        function search(text: string): void {
            if (win.open)
                input.text = text
        }
    }

    // ---------- scene ----------

    // Click outside the island closes.
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

    // Same silhouette as the island (island/Island.qml): flush with the top edge, concave flares, rounded bottom.
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
            strokeColor: win.c.hairline
            strokeWidth: 1

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

    Item {
        id: card

        readonly property real radius: 18

        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        width: win.expanded ? win.cardWidth : Launch.islandWidth
        height: win.expanded ? win.cardHeight : Launch.islandHeight
        clip: true

        Behavior on width { Ease { duration: win.expanded ? 520 : 340 } }
        Behavior on height { Ease { duration: win.expanded ? 520 : 340 } }

        // Swallows clicks on the island so they do not reach the scrim.
        MouseArea { anchors.fill: parent }

        // The content keeps its full size and stays centred: the growing card reveals it.
        Item {
            id: content

            x: (card.width - width) / 2
            width: win.cardWidth
            height: win.cardHeight
            opacity: win.expanded ? 1 : 0

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: win.expanded ? 160 : 0 }
                    NumberAnimation { duration: win.expanded ? 320 : 60 }
                }
            }

            // ----- search row -----
            Item {
                id: search

                width: parent.width
                height: win.searchHeight

                Image {
                    id: mark

                    x: 24
                    y: 3 + (parent.height - height) / 2
                    width: 20
                    height: 20
                    source: Qt.resolvedUrl("../assets/deathstar.svg")
                    sourceSize: Qt.size(40, 40)
                    opacity: input.activeFocus ? 1 : 0.6
                }

                Row {
                    id: modes

                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    y: 3 + (parent.height - height) / 2
                    spacing: 4

                    Repeater {
                        model: [{ p: "=", label: "Calculate" }, { p: ">", label: "Shell" }, { p: "@", label: "Windows" }]

                        delegate: Rectangle {
                            id: chip

                            required property var modelData
                            readonly property bool on: win.query.charAt(0) === modelData.p

                            width: chipRow.implicitWidth + 14
                            height: 28
                            radius: 10
                            color: on ? win.c.surfaceAlt : chipMouse.containsMouse ? win.c.rowHover : "transparent"

                            Behavior on color { ColorAnimation { duration: 140 } }

                            Row {
                                id: chipRow

                                x: 4
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 7

                                Rectangle {
                                    width: 20
                                    height: 20
                                    radius: 6
                                    color: chip.on ? win.c.ink : win.c.surfaceAlt

                                    Text {
                                        anchors.centerIn: parent
                                        text: chip.modelData.p
                                        color: chip.on ? win.c.text : win.c.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                        renderType: Text.CurveRendering
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: chip.modelData.label
                                    color: chip.on ? win.c.text : chipMouse.containsMouse ? win.c.muted : win.c.faint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    renderType: Text.CurveRendering
                                }
                            }

                            MouseArea {
                                id: chipMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    input.text = Logic.togglePrefix(input.text, chip.modelData.p)
                                    input.forceActiveFocus()
                                }
                            }
                        }
                    }
                }

                TextInput {
                    id: input

                    x: mark.x + mark.width + 14
                    width: modes.x - x - 14
                    y: 3 + (parent.height - height) / 2
                    color: win.c.text
                    selectionColor: win.c.border
                    selectedTextColor: win.c.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 17
                    clip: true
                    renderType: Text.CurveRendering
                    cursorDelegate: Rectangle {
                        width: 1
                        color: win.c.text
                    }

                    onTextChanged: {
                        win.query = text
                        win.build()
                    }

                    Keys.onPressed: event => {
                        const ctrl = event.modifiers & Qt.ControlModifier
                        const acts = win.sel?.actions ?? []
                        if (event.key === Qt.Key_Escape) {
                            if (win.actIndex >= 0)
                                win.actIndex = -1
                            else
                                win.hide()
                        } else if (event.key === Qt.Key_Down || (ctrl && event.key === Qt.Key_N)) {
                            win.move(1)
                        } else if (event.key === Qt.Key_Up || (ctrl && event.key === Qt.Key_P)) {
                            win.move(-1)
                        } else if (event.key === Qt.Key_Right && acts.length > 0 && cursorPosition === text.length) {
                            win.actIndex = Math.min(win.actIndex + 1, acts.length - 1)
                        } else if (event.key === Qt.Key_Left && win.actIndex >= 0) {
                            win.actIndex--
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            win.activate(win.current)
                        } else {
                            return
                        }
                        event.accepted = true
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: input.text.length === 0
                        text: "Search apps"
                        color: win.c.faint
                        font: input.font
                        renderType: Text.CurveRendering
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: win.c.hairline
                }
            }

            // ----- list -----
            ListView {
                id: list

                x: 8
                y: win.searchHeight + 6
                width: win.listWidth - 16
                height: win.cardHeight - win.searchHeight - win.footHeight - 12
                model: win.items
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                visible: win.rows.length > 0

                Connections {
                    target: win

                    function onCurrentChanged() {
                        const r = win.rows[win.current]
                        if (!r)
                            return
                        // Bring the section header into view along with the first row of a section.
                        const i = win.items.indexOf(r)
                        list.positionViewAtIndex(i > 0 && win.items[i - 1].header ? i - 1 : i, ListView.Contain)
                        if (win.current === 0)
                            list.positionViewAtBeginning()
                    }

                    function onItemsChanged() {
                        list.positionViewAtBeginning()
                    }
                }

                delegate: Item {
                    id: row

                    required property var modelData
                    readonly property bool header: modelData.header === true
                    readonly property bool sel: !header && modelData.ri === win.current

                    width: ListView.view.width
                    height: header ? 30 : win.rowHeight

                    Text {
                        visible: row.header
                        x: 14
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 8
                        text: row.modelData.name
                        color: win.c.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        renderType: Text.CurveRendering
                    }

                    Rectangle {
                        visible: !row.header
                        anchors.fill: parent
                        radius: 14
                        color: row.sel ? win.c.surfaceAlt : "transparent"

                        Behavior on color { ColorAnimation { duration: 140 } }

                        // Running: the app has open windows.
                        Rectangle {
                            visible: (row.modelData.windows ?? 0) > 0
                            x: 5
                            anchors.verticalCenter: parent.verticalCenter
                            width: 4
                            height: 6
                            radius: 2
                            color: row.sel ? win.c.text : win.c.muted
                        }

                        RowIcon {
                            id: rowIcon

                            x: 14
                            anchors.verticalCenter: parent.verticalCenter
                            size: 20
                            row: row.modelData
                            selected: row.sel
                        }

                        Text {
                            id: right

                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.right ?? ""
                            textFormat: Text.PlainText
                            color: win.c.faint
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.features: { "tnum": 1 }
                            renderType: Text.CurveRendering
                        }

                        // Names come from outside: Fuzzy.markup escapes them before StyledText sees them.
                        Text {
                            id: nameText

                            readonly property real room: (right.text !== "" ? right.x - 10 : parent.width - 14) - x

                            x: rowIcon.x + rowIcon.width + 12
                            width: Math.min(implicitWidth, room)
                            anchors.verticalCenter: parent.verticalCenter
                            textFormat: Text.StyledText
                            text: Fuzzy.markup(row.modelData.name, row.modelData.idx ?? [], row.sel ? "#ffffff" : win.c.text)
                            color: row.sel ? win.c.text : win.c.muted
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            renderType: Text.CurveRendering
                        }

                        Text {
                            visible: row.modelData.kind === "app" && width > 24
                            x: nameText.x + nameText.width + 8
                            width: nameText.x + nameText.room - x
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.sub ?? ""
                            textFormat: Text.PlainText
                            color: win.c.faint
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
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
                                if (!first && moved && win.current !== row.modelData.ri) {
                                    win.current = row.modelData.ri
                                    win.actIndex = -1
                                }
                            }
                            onClicked: win.activate(row.modelData.ri)
                        }
                    }
                }
            }

            // No result: say what was missing and how the prefixes work.
            Text {
                visible: win.rows.length === 0
                x: 22
                y: win.searchHeight + 18
                width: win.listWidth - 44
                wrapMode: Text.Wrap
                textFormat: Text.StyledText
                text: win.parsed.mode === "calc"
                    ? "Type a sum, like <b>= 12*7+3</b> or <b>= 15% * 240</b>."
                    : "No " + (win.parsed.mode === "windows" ? "window" : win.parsed.mode === "shell" ? "command" : "app")
                        + " named <b>“" + Fuzzy.escape(win.parsed.body) + "”</b>.<br><br>Start with <b>=</b> to calculate, "
                        + "<b>&gt;</b> for shell commands, <b>@</b> for open windows."
                color: win.c.muted
                linkColor: win.c.text
                font.family: Theme.fontFamily
                font.pixelSize: 13
                lineHeight: 1.25
                renderType: Text.CurveRendering
            }

            Rectangle {
                x: win.listWidth
                y: win.searchHeight
                width: 1
                height: win.cardHeight - win.searchHeight - win.footHeight
                color: win.c.hairline
            }

            // ----- detail -----
            Item {
                id: detail

                readonly property var r: win.sel
                readonly property string iso: r ? r.iso : ""

                x: win.listWidth + 1 + 22
                y: win.searchHeight + 16
                width: win.cardWidth - x - 22
                height: win.cardHeight - win.footHeight - y - 14

                onIsoChanged: if (iso !== "") drop.restart()

                // Isometric scene: an Isoflow object standing on a plinth over a faint grid floor.
                Rectangle {
                    id: scene

                    width: parent.width
                    height: 148
                    radius: 16
                    color: win.c.rowHover
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: Qt.resolvedUrl("../assets/iso/floor.svg")
                        sourceSize: Qt.size(width * 2, height * 2)
                        fillMode: Image.PreserveAspectCrop
                    }

                    Image {
                        id: plinth

                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 14
                        width: 128
                        height: 80
                        source: Qt.resolvedUrl("../assets/iso/block.svg")
                        sourceSize: Qt.size(256, 160)
                        fillMode: Image.PreserveAspectFit
                    }

                    Image {
                        id: object

                        property real lift: 0

                        visible: detail.iso !== ""
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height - 56 - height - lift
                        width: 120
                        height: 76
                        source: detail.iso !== "" ? Qt.resolvedUrl("../assets/iso/" + detail.iso + ".svg") : ""
                        sourceSize: Qt.size(240, 152)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true

                        ParallelAnimation {
                            id: drop

                            NumberAnimation { target: object; property: "lift"; from: 16; to: 0; duration: 300; easing.type: Easing.OutCubic }
                            NumberAnimation { target: object; property: "opacity"; from: 0; to: 1; duration: 300; easing.type: Easing.OutCubic }
                        }
                    }
                }

                // Calculator: the expression, then the result large.
                Column {
                    visible: detail.r?.kind === "calc"
                    y: scene.height + 14
                    width: parent.width
                    spacing: 8

                    Text {
                        text: (detail.r?.sub ?? "") + " ="
                        textFormat: Text.PlainText
                        width: parent.width
                        elide: Text.ElideRight
                        color: win.c.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        renderType: Text.CurveRendering
                    }

                    Text {
                        text: detail.r?.name ?? ""
                        textFormat: Text.PlainText
                        width: parent.width
                        elide: Text.ElideRight
                        color: win.c.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 44
                        font.weight: Font.Light
                        font.features: { "tnum": 1 }
                        renderType: Text.CurveRendering
                    }

                    Text {
                        text: detail.r?.value === null ? "Finish the expression to see the result." : "Enter copies the result to the clipboard."
                        color: win.c.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        renderType: Text.CurveRendering
                    }
                }

                // Apps, windows and commands: who, what, history.
                Column {
                    visible: detail.r !== null && detail.r.kind !== "calc"
                    y: scene.height + 14
                    width: parent.width
                    spacing: 10

                    Item {
                        width: parent.width
                        height: 36

                        RowIcon {
                            id: bigIcon

                            anchors.verticalCenter: parent.verticalCenter
                            size: 32
                            row: detail.r
                            selected: true
                        }

                        Column {
                            x: bigIcon.width + 12
                            width: parent.width - x
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                width: parent.width
                                text: detail.r?.name ?? ""
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                color: win.c.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 17
                                font.weight: Font.Medium
                                renderType: Text.CurveRendering
                            }

                            Text {
                                visible: text !== ""
                                width: parent.width
                                text: detail.r?.sub ?? ""
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                color: win.c.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                renderType: Text.CurveRendering
                            }
                        }
                    }

                    Text {
                        visible: text !== ""
                        width: parent.width
                        text: detail.r?.text ?? ""
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        color: win.c.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        renderType: Text.CurveRendering
                    }

                    Text {
                        visible: text !== ""
                        width: parent.width
                        text: {
                            const r = detail.r
                            if (!r)
                                return ""
                            if (r.kind === "win")
                                return "Workspace " + r.ws
                            if (r.kind !== "app")
                                return ""
                            const parts = [r.hits > 0 ? r.hits + (r.hits === 1 ? " launch" : " launches") : "Not launched from here yet"]
                            if (r.last > 0)
                                parts.push("Last opened " + Logic.agoLong(r.last, win.now))
                            if (r.windows > 0)
                                parts.push(r.windows + (r.windows === 1 ? " window open" : " windows open"))
                            return parts.join("    ")
                        }
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: win.c.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.features: { "tnum": 1 }
                        renderType: Text.CurveRendering
                    }
                }

                // The app's own actions (Desktop Actions), at the bottom of the pane.
                Flow {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    spacing: 6
                    visible: (detail.r?.actions ?? []).length > 0

                    Repeater {
                        model: detail.r?.actions ?? []

                        delegate: Rectangle {
                            id: act

                            required property string modelData
                            required property int index
                            readonly property bool on: win.actIndex === index

                            width: actText.implicitWidth + 24
                            height: 30
                            radius: 10
                            color: on || actMouse.containsMouse ? win.c.surfaceAlt : win.c.rowHover
                            border.width: on ? 1 : 0
                            border.color: Qt.rgba(1, 1, 1, 0.14)

                            Behavior on color { ColorAnimation { duration: 140 } }

                            Text {
                                id: actText

                                anchors.centerIn: parent
                                text: act.modelData
                                textFormat: Text.PlainText
                                color: act.on || actMouse.containsMouse ? win.c.text : win.c.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                renderType: Text.CurveRendering
                            }

                            MouseArea {
                                id: actMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    win.actIndex = act.index
                                    win.activate(win.current)
                                }
                            }
                        }
                    }
                }
            }

            // ----- footer: key hints -----
            Item {
                y: win.cardHeight - win.footHeight
                width: parent.width
                height: win.footHeight

                Rectangle {
                    width: parent.width
                    height: 1
                    color: win.c.hairline
                }

                Row {
                    x: 24
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 18

                    KeyHint {
                        visible: win.sel !== null && !(win.sel.kind === "calc" && win.sel.value === null)
                        key: "Enter"
                        label: {
                            const r = win.sel
                            if (!r)
                                return ""
                            if (r.kind === "calc")
                                return "Copy"
                            if (r.kind === "win")
                                return "Focus"
                            if (r.kind === "cmd")
                                return r.cmd.asks ? "Ask" : "Run"
                            return win.actIndex >= 0 ? (r.actions[win.actIndex] ?? "Open") : "Open"
                        }
                    }

                    KeyHint {
                        visible: (win.sel?.actions ?? []).length > 0
                        key: "→"
                        label: "Actions"
                    }

                    KeyHint {
                        key: "Esc"
                        label: win.actIndex >= 0 ? "Back" : "Close"
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 24
                    anchors.verticalCenter: parent.verticalCenter
                    text: "TK-421"
                    color: win.c.faint
                    font.family: Theme.displayFont
                    font.pixelSize: 9
                    font.weight: Font.Medium
                    font.letterSpacing: 2.2
                    renderType: Text.CurveRendering
                }
            }
        }
    }
}
