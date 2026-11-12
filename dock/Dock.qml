import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

import "../components"
import "../theme"
import "logic.js" as Logic
import "../launcher/Fuzzy.js" as Fuzzy

// The dock: the island's twin at the bottom edge (prototype prototypes/dock/index.html, approved 2026-11-12).
// Same opaque ink silhouette as the island, mirrored: concave flares where it meets the screen edge, rounded top
// corners. In auto-hide (default) it rests as a 76 x 6 lip; pushing the pointer against the bottom edge grows it.
// Slots: the launcher mark, the pinned apps, then running apps that are not pinned. Icons are the candy theme drawn
// grey; state is colour only (a faint dash under a running app, a white one under the focused app).
PanelWindow {
    id: win

    readonly property var c: Theme.imperial

    // Geometry, as in the prototype.
    readonly property int dockHeight: 58
    readonly property int cell: 44
    readonly property int gap: 4
    readonly property int pad: 12
    readonly property int flare: 10
    readonly property int iconSize: 32
    readonly property int sepWidth: 13
    readonly property int lipWidth: 76
    readonly property int lipHeight: 6
    readonly property real mag: 0.32
    readonly property real reach: 2.4

    property var pinned: Logic.DEFAULT_PINNED.slice()
    property string dockMode: "auto"       // auto | always
    property bool revealed: false          // auto-hide: grown by the pointer at the edge (or IPC)
    property var slots: []
    property var launching: ({})           // desktop entry id -> true while its first window is pending
    property var menuSlot: null            // the slot whose context menu is open
    property real menuX: 0
    property var hotSlot: null             // the hovered slot, for the tooltip
    property real hotX: 0
    property real hotScale: 1

    readonly property bool shown: dockMode === "always" || revealed || menuSlot !== null
    readonly property real restWidth: restRow()
    // 0 = the lip, 1 = the full dock. Everything that grows follows this one number.
    property real openness: shown ? 1 : 0
    readonly property bool settled: openness > 0.98
    property real pointerX: -1
    readonly property bool magnifying: pointerX >= 0 && settled && menuSlot === null

    Behavior on openness {
        NumberAnimation {
            duration: win.shown ? 360 : 260
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
        }
    }

    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    implicitHeight: 460      // room above the dock for the context menu
    color: "transparent"
    exclusionMode: dockMode === "always" ? ExclusionMode.Normal : ExclusionMode.Ignore
    exclusiveZone: dockMode === "always" ? dockHeight : 0

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "tk421-dock"
    WlrLayershell.keyboardFocus: menuSlot !== null ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Input only on the dock itself, the edge strip while hidden, and the context menu while open.
    mask: Region {
        item: body
        Region { item: win.shown ? null : edgeStrip }
        Region { item: win.menuSlot !== null ? menu : null }
    }

    // ---------- model ----------

    function entryFor(key) {
        return DesktopEntries.byId(key)
    }

    function keyFor(appId) {
        const e = DesktopEntries.heuristicLookup(appId)
        return e ? e.id : appId
    }

    function rebuild() {
        const wins = ToplevelManager.toplevels.values
            .filter(t => !Logic.ignored(t.appId))
            .map(t => ({ key: keyFor(t.appId), ref: t }))
        const groups = Logic.group(pinned, wins)
            .map(g => Object.assign(g, { kind: "app", entry: entryFor(g.key) }))
            // a pinned app that is no longer installed stays in the list but is not drawn
            .filter(g => g.entry !== null || g.wins.length > 0)

        const still = {}
        for (const k in launching)
            if (!groups.some(g => g.key === k && g.wins.length > 0))
                still[k] = true
        launching = still

        const out = [{ kind: "launcher", key: "@launcher" }, { kind: "sep", key: "@sep1" }]
        const loose = groups.filter(g => !g.pinned)
        groups.filter(g => g.pinned).forEach(g => out.push(g))
        if (loose.length > 0) {
            out.push({ kind: "sep", key: "@sep2" })
            loose.forEach(g => out.push(g))
        }
        slots = out

        if (menuSlot !== null)
            menuSlot = slots.find(s => s.key === menuSlot.key) ?? null
    }

    function restRow() {
        let w = 0
        for (let i = 0; i < slots.length; i++)
            w += (slots[i].kind === "sep" ? sepWidth : cell) + (i > 0 ? gap : 0)
        return w
    }

    // The resting (unmagnified) centre of slot i, in window coordinates: magnification is measured from these, so the
    // dock does not chase the pointer as it widens.
    function restCentre(i) {
        let x = width / 2 - restWidth / 2
        for (let j = 0; j < i; j++)
            x += (slots[j].kind === "sep" ? sepWidth : cell) + gap
        return x + (slots[i].kind === "sep" ? sepWidth : cell) / 2
    }

    function nameOf(s) {
        if (s.kind === "launcher")
            return "Apps"
        return s.entry?.name || s.wins?.[0]?.appId || s.key
    }

    function save() {
        stateView.setText(Logic.serializeState(pinned, dockMode))
    }

    function activate(s) {
        menuSlot = null
        if (s.kind === "launcher") {
            // The launcher is its own component; reach it the way Hyprland's SUPER+Space does.
            Quickshell.execDetached(["qs", "ipc", "-p", Quickshell.env("HOME") + "/.config/quickshell/shell.qml", "call", "launcher", "open"])
            return
        }
        if (launching[s.key])
            return
        if (s.wins.length === 0) {
            launch(s)
            return
        }
        const i = Logic.nextWindow(s.wins.map(t => t.activated))
        s.wins[i].activate()
    }

    function launch(s) {
        if (!s.entry)
            return
        const l = Object.assign({}, launching)
        l[s.key] = true
        launching = l
        launchTimeout.restart()
        s.entry.execute()
    }

    function togglePin(s) {
        pinned = Logic.togglePin(pinned, s.key)
        save()
        rebuild()
    }

    function closeAll(s) {
        s.wins.slice().forEach(t => t.close())
    }

    function openMenu(s, centreX) {
        if (s.kind !== "app")
            return
        menuX = centreX
        menuSlot = s
    }

    function scheduleHide() {
        if (dockMode === "always" || menuSlot !== null)
            return
        hideTimer.restart()
    }

    onShownChanged: if (!shown) pointerX = -1
    onRevealedChanged: if (revealed && !peekTimer.running) scheduleHide()      // grown by the edge strip without entering the dock
    onMenuSlotChanged: if (menuSlot === null && !bodyHover.hovered) scheduleHide()

    Connections {
        target: ToplevelManager.toplevels
        function onValuesChanged() { rebuildTimer.restart() }
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { rebuildTimer.restart() }
    }

    // A window's app id can arrive after the window itself.
    Instantiator {
        model: ToplevelManager.toplevels
        delegate: Connections {
            required property var modelData
            target: modelData
            function onAppIdChanged() { rebuildTimer.restart() }
        }
    }

    Timer {
        id: rebuildTimer
        interval: 60
        onTriggered: win.rebuild()
    }

    Timer {
        id: launchTimeout
        interval: 10000
        onTriggered: win.launching = ({})
    }

    Timer {
        id: edgeTimer
        interval: 120
        onTriggered: {
            if (!(ToplevelManager.activeToplevel?.fullscreen ?? false))
                win.revealed = true
        }
    }

    Timer {
        id: hideTimer
        interval: 380
        onTriggered: if (!bodyHover.hovered && win.menuSlot === null && !peekTimer.running) win.revealed = false
    }

    FileView {
        id: stateView

        path: Quickshell.shellPath("dock/state.json")
        printErrors: false      // the file does not exist until the first change
        atomicWrites: true

        onLoaded: {
            const s = Logic.parseState(text())
            win.pinned = s.pinned
            win.dockMode = s.mode
            win.rebuild()
        }
        onLoadFailed: win.rebuild()
    }

    Component.onCompleted: rebuild()

    HyprlandFocusGrab {
        windows: [win]
        active: win.menuSlot !== null
        onCleared: win.menuSlot = null
    }

    Shortcut {
        sequence: "Escape"
        enabled: win.menuSlot !== null
        onActivated: win.menuSlot = null
    }

    IpcHandler {
        target: "dock"

        function status(): string {
            return "mode=" + win.dockMode + " shown=" + win.shown + " slots=" + win.slots.filter(s => s.kind === "app").length
                + " menu=" + (win.menuSlot ? win.menuSlot.key : "none")
        }

        // One line per app slot: index, key, pinned, window count, focused.
        function list(): string {
            return win.slots.filter(s => s.kind === "app").map((s, i) => i + " " + s.key + (s.pinned ? " pinned" : "")
                + " wins=" + s.wins.length + (s.wins.some(t => t.activated) ? " focused" : "")).join("\n")
        }

        function setMode(mode: string): void {
            if (Logic.MODES.indexOf(mode) < 0)
                return
            win.dockMode = mode
            win.save()
        }

        // Grow it for a few seconds without the pointer (visual checks).
        function reveal(): void {
            peekTimer.restart()
            win.revealed = true
        }

        function conceal(): void {
            win.menuSlot = null
            win.revealed = false
        }

        // Open the context menu of app slot i (visual checks; it closes on an outside click or Esc).
        function menu(i: int): void {
            const apps = win.slots.filter(s => s.kind === "app")
            if (i < 0 || i >= apps.length)
                return
            win.revealed = true
            win.openMenu(apps[i], win.restCentre(win.slots.indexOf(apps[i])))
        }
    }

    Timer {
        id: peekTimer
        interval: 3000
        onTriggered: win.scheduleHide()
    }

    // ---------- the edge strip (hidden state) ----------

    Item {
        id: edgeStrip

        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(win.restWidth + 2 * (win.flare + win.pad), 320)
        height: 2

        HoverHandler {
            onHoveredChanged: {
                if (hovered && win.dockMode === "auto")
                    edgeTimer.restart()
                else
                    edgeTimer.stop()
            }
        }
    }

    // ---------- the dock ----------

    Item {
        id: body

        readonly property real fullWidth: row.width + 2 * (win.flare + win.pad)

        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: win.lipWidth + (fullWidth - win.lipWidth) * win.openness
        height: win.lipHeight + (win.dockHeight - win.lipHeight) * win.openness

        HoverHandler {
            id: bodyHover

            onHoveredChanged: {
                if (hovered) {
                    hideTimer.stop()
                } else {
                    win.pointerX = -1
                    win.scheduleHide()
                }
            }
            onPointChanged: if (hovered && win.settled) win.pointerX = body.x + point.position.x
        }

        Shape {
            id: silhouette

            readonly property real w: body.width
            readonly property real h: body.height
            readonly property real f: Math.min(win.flare, h / 2)
            readonly property real r: Math.max(0, Math.min(18, h - f, (w - 2 * f) / 2))

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: win.c.ink
                strokeColor: win.c.hairline
                strokeWidth: 1

                // Starts below the screen so the closing bottom line is never drawn.
                startX: 0
                startY: silhouette.h + 2
                PathLine { x: 0; y: silhouette.h }
                PathArc { x: silhouette.f; y: silhouette.h - silhouette.f; radiusX: silhouette.f; radiusY: silhouette.f; direction: PathArc.Counterclockwise }
                PathLine { x: silhouette.f; y: silhouette.r }
                PathArc { x: silhouette.f + silhouette.r; y: 0; radiusX: silhouette.r; radiusY: silhouette.r; direction: PathArc.Clockwise }
                PathLine { x: silhouette.w - silhouette.f - silhouette.r; y: 0 }
                PathArc { x: silhouette.w - silhouette.f; y: silhouette.r; radiusX: silhouette.r; radiusY: silhouette.r; direction: PathArc.Clockwise }
                PathLine { x: silhouette.w - silhouette.f; y: silhouette.h - silhouette.f }
                PathArc { x: silhouette.w; y: silhouette.h; radiusX: silhouette.f; radiusY: silhouette.f; direction: PathArc.Counterclockwise }
                PathLine { x: silhouette.w; y: silhouette.h + 2 }
            }
        }

        // The slots, laid across the full width; they fade in late and rise from below while the lip grows.
        Row {
            id: row

            x: (body.width - width) / 2
            y: body.height - win.dockHeight + (1 - win.openness) * 14
            height: win.dockHeight
            spacing: win.gap
            opacity: Math.max(0, (win.openness - 0.55) / 0.45)
            visible: win.openness > 0.3

            Repeater {
                model: win.slots

                delegate: Item {
                    id: slot

                    required property var modelData
                    required property int index

                    readonly property var s: modelData
                    readonly property bool isSep: s.kind === "sep"
                    readonly property bool running: s.kind === "app" && s.wins.length > 0
                    readonly property bool focused: running && s.wins.some(t => t.activated)
                    readonly property bool pending: s.kind === "app" && win.launching[s.key] === true
                    readonly property bool hot: area.containsMouse || win.menuSlot === s
                    readonly property real want: win.magnifying && !isSep
                        ? Logic.magnify(win.pointerX - win.restCentre(index), win.cell, win.reach, win.mag) : 1
                    property real scaleNow: want

                    Behavior on scaleNow { NumberAnimation { duration: 90 } }

                    width: isSep ? win.sepWidth : win.cell * scaleNow
                    height: win.dockHeight

                    onHotChanged: {
                        if (area.containsMouse) {
                            win.hotSlot = s
                            win.hotScale = scaleNow
                            win.hotX = slot.mapToItem(null, width / 2, 0).x
                        } else if (win.hotSlot === s) {
                            win.hotSlot = null
                        }
                    }
                    onScaleNowChanged: if (win.hotSlot === s) { win.hotScale = scaleNow; win.hotX = slot.mapToItem(null, width / 2, 0).x }
                    onXChanged: if (win.hotSlot === s) win.hotX = slot.mapToItem(null, width / 2, 0).x

                    Rectangle {
                        visible: slot.isSep
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 17
                        width: 1
                        height: 22
                        color: win.c.hairline
                    }

                    Item {
                        id: glyph

                        visible: !slot.isSep
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: win.dockHeight - 13 - height
                        width: win.iconSize
                        height: win.iconSize
                        transformOrigin: Item.Bottom
                        scale: slot.scaleNow
                        opacity: slot.hot ? 1 : 0.62

                        Behavior on opacity { NumberAnimation { duration: 140 } }

                        readonly property string iconName: slot.s.kind === "launcher" ? ""
                            : (slot.s.entry?.icon ?? "") !== "" ? slot.s.entry.icon : (slot.s.wins?.[0]?.appId ?? "")
                        readonly property string source: slot.s.kind === "launcher" ? Qt.resolvedUrl("../assets/deathstar.svg")
                            : iconName === "" ? ""
                            : iconName.startsWith("/") ? "file://" + iconName
                            : Quickshell.iconPath(iconName, true)

                        Image {
                            id: appIcon

                            anchors.fill: parent
                            anchors.margins: slot.s.kind === "launcher" ? 4 : 0
                            source: glyph.source
                            sourceSize: Qt.size(64, 64)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            visible: status === Image.Ready
                            layer.enabled: visible && slot.s.kind !== "launcher"
                            layer.effect: MultiEffect {
                                saturation: -1
                            }
                        }

                        // No icon in the theme: the launcher's initials tile.
                        Rectangle {
                            visible: appIcon.status !== Image.Ready && slot.s.kind === "app"
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 9
                            color: win.c.surfaceAlt

                            Text {
                                anchors.centerIn: parent
                                text: Fuzzy.initials(win.nameOf(slot.s))
                                textFormat: Text.PlainText
                                color: win.c.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                renderType: Text.CurveRendering
                            }
                        }
                    }

                    // State dash: faint and short under a running app, white and long under the focused one, breathing
                    // while an app starts.
                    Rectangle {
                        visible: slot.s.kind === "app"
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: win.dockHeight - 4 - height
                        height: 2
                        radius: 1
                        width: slot.focused ? 14 : slot.running || slot.pending ? 5 : 0
                        color: slot.focused ? win.c.text : slot.pending ? win.c.muted : win.c.faint

                        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 220 } }

                        SequentialAnimation on opacity {
                            running: slot.pending
                            loops: Animation.Infinite
                            alwaysRunToEnd: true
                            NumberAnimation { from: 1; to: 0.25; duration: 700; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 0.25; to: 1; duration: 700; easing.type: Easing.InOutSine }
                        }
                    }

                    MouseArea {
                        id: area

                        anchors.fill: parent
                        enabled: !slot.isSep
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor

                        onClicked: event => {
                            if (event.button === Qt.RightButton)
                                win.openMenu(slot.s, slot.mapToItem(null, slot.width / 2, 0).x)
                            else if (event.button === Qt.MiddleButton && slot.s.kind === "app")
                                win.launch(slot.s)
                            else
                                win.activate(slot.s)
                        }
                    }
                }
            }
        }
    }

    // ---------- tooltip ----------

    Rectangle {
        id: tip

        readonly property bool on: win.hotSlot !== null && win.menuSlot === null && win.settled

        x: Math.round(win.hotX - width / 2)
        y: win.height - (13 + win.iconSize * win.hotScale + 10) - height
        width: tipRow.implicitWidth + 24
        height: 27
        radius: 13
        color: win.c.ink
        border.width: 1
        border.color: win.c.hairline
        opacity: on ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 120 } }

        Row {
            id: tipRow

            anchors.centerIn: parent
            spacing: 6

            Text {
                text: win.hotSlot ? win.nameOf(win.hotSlot) : ""
                textFormat: Text.PlainText
                color: win.c.text
                font.family: Theme.fontFamily
                font.pixelSize: 13
                renderType: Text.CurveRendering
            }

            Text {
                visible: (win.hotSlot?.wins?.length ?? 0) > 1
                text: Logic.windowCount(win.hotSlot?.wins?.length ?? 0)
                color: win.c.faint
                font.family: Theme.fontFamily
                font.pixelSize: 12
                renderType: Text.CurveRendering
            }
        }
    }

    // ---------- context menu ----------

    component MenuRow: Rectangle {
        id: mrow

        property string icon: ""
        property string label: ""
        property bool current: false
        signal picked()

        width: 220
        height: 34
        radius: 14
        color: rowArea.containsMouse ? win.c.rowHover : "transparent"

        Icon {
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            name: mrow.icon
            size: Theme.iconSize.panel
            color: win.c.faint
        }

        Text {
            x: 38
            width: parent.width - 50
            anchors.verticalCenter: parent.verticalCenter
            text: mrow.label
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: rowArea.containsMouse || mrow.current ? win.c.text : win.c.muted
            font.family: Theme.fontFamily
            font.pixelSize: 13
            renderType: Text.CurveRendering
        }

        MouseArea {
            id: rowArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mrow.picked()
        }
    }

    Rectangle {
        id: menu

        readonly property var s: win.menuSlot
        readonly property int count: s ? s.wins.length : 0

        visible: opacity > 0.01
        opacity: s ? 1 : 0
        x: Math.max(8, Math.min(win.width - width - 8, Math.round(win.menuX - width / 2)))
        y: win.height - win.dockHeight - 10 - height + (s ? 0 : 6)
        width: 232
        height: menuCol.implicitHeight + 12
        radius: 18
        color: win.c.ink
        border.width: 1
        border.color: win.c.hairline

        Behavior on opacity { NumberAnimation { duration: 160 } }
        Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        Column {
            id: menuCol

            x: 6
            y: 6

            Item {
                width: 220
                height: 46

                Text {
                    x: 12
                    y: 10
                    text: menu.s ? win.nameOf(menu.s) : ""
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    width: 196
                    color: win.c.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    renderType: Text.CurveRendering
                }

                Text {
                    x: 12
                    y: 27
                    text: Logic.windowCount(menu.count)
                    color: win.c.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    renderType: Text.CurveRendering
                }
            }

            Repeater {
                model: menu.s ? menu.s.wins.slice(0, 8) : []

                delegate: MenuRow {
                    required property var modelData
                    icon: "web_asset"
                    label: modelData.title || win.nameOf(menu.s)
                    current: modelData.activated
                    onPicked: {
                        modelData.activate()
                        win.menuSlot = null
                    }
                }
            }

            Item {
                visible: menu.count > 0
                width: 220
                height: 13

                Rectangle {
                    x: 8
                    y: 6
                    width: 204
                    height: 1
                    color: win.c.hairline
                }
            }

            MenuRow {
                visible: menu.s?.entry != null
                icon: "add"
                label: menu.count > 0 ? "New window" : "Open"
                onPicked: {
                    const s = menu.s
                    win.menuSlot = null
                    win.launch(s)
                }
            }

            MenuRow {
                icon: menu.s?.pinned ? "keep_off" : "keep"
                label: menu.s?.pinned ? "Remove from dock" : "Keep in dock"
                onPicked: {
                    const s = menu.s
                    win.menuSlot = null
                    win.togglePin(s)
                }
            }

            MenuRow {
                visible: menu.count > 0
                icon: "close"
                label: Logic.closeLabel(menu.count)
                onPicked: {
                    const s = menu.s
                    win.menuSlot = null
                    win.closeAll(s)
                }
            }
        }
    }
}
