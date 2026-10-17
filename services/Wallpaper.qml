pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

import "../wallpaper/logic.js" as Logic

// Wallpaper picker model. `awww` is the real wallpaper; wallpaper/WallpaperStage.qml draws the transitions above it and
// wallpaper/WallpaperPicker.qml is the door. `shown` is what the desktop should display right now: the selection while the
// picker is open, `applied` otherwise. Spec: docs/superpowers/specs/2026-10-14-wallpaper-picker-design.md
Singleton {
    id: root

    readonly property bool active: true
    readonly property string dir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    readonly property string stateFile: Quickshell.shellPath("wallpaper/state.json")

    property var folderFiles: []          // what is in the folder (absolute paths)
    property var files: []                // folderFiles plus the applied wallpaper when it lives elsewhere
    property string applied: ""           // what awww is painting
    property string shown: ""
    property int selected: 0
    property string effect: "laser"
    property bool open: false
    property bool reducedMotion: false
    property string dimensions: ""        // "1920×804 · PNG" of the selection
    readonly property bool applying: applier.running

    property string statePath: ""         // path stored in state.json
    property string queryPath: ""         // path reported by `awww query` (the truth, when it answers)
    property bool queryDone: false        // awww answered (or did not within 3 s)
    property string pending: ""

    function rebuild() {
        const keep = open ? shown : applied
        const next = Logic.withApplied(folderFiles, applied)

        if (next.join("\n") !== files.join("\n"))
            files = next

        const i = files.indexOf(keep)
        if (i >= 0) {
            selected = i
        } else {
            const j = files.indexOf(applied)
            selected = j >= 0 ? j : 0
            shown = applied
        }

        if (!open)
            shown = applied
    }

    // awww's own answer wins; the stored path is the fallback when the daemon does not answer.
    function resolveApplied() {
        const path = Logic.chooseApplied(queryPath, statePath, queryDone)
        if (path === "" || path === applied)
            return

        applied = path
        rebuild()
    }

    function loadState(text) {
        const s = Logic.parseState(text)
        effect = s.effect
        statePath = s.path
        resolveApplied()
    }

    function save() {
        stateView.setText(Logic.serializeState(applied, effect))
    }

    function listed(text) {
        folderFiles = Logic.listImages(text.split("\n")).map(n => dir + "/" + n)
        rebuild()
    }

    function refresh() {
        if (!lister.running)
            lister.running = true
    }

    function describe(path) {
        if (!open || path === "")
            return

        identifier.running = false
        identifier.command = ["magick", "identify", "-ping", "-format", "%w×%h · %m", path + "[0]"]
        identifier.running = true
    }

    function show() {
        if (applying)
            return

        refresh()
        shown = applied
        const i = files.indexOf(applied)
        selected = i >= 0 ? i : 0
        open = true
        describe(shown)
    }

    function toggle() {
        open ? cancel() : show()
    }

    function select(i) {
        if (files.length === 0)
            return

        selected = Logic.stepIndex(i, 0, files.length)
        shown = files[selected]
    }

    function step(d) {
        if (open && files.length > 0)
            select(selected + d)
    }

    function neighbor(d) {
        return files.length > 0 ? files[Logic.stepIndex(selected, d, files.length)] : ""
    }

    function setEffect(id) {
        if (!Logic.isEffect(id))
            return

        effect = id
        save()
    }

    function cycleEffect(d) {
        setEffect(Logic.stepEffect(effect, d))
    }

    // Enter: keep the selection. Nothing runs when it is the wallpaper that is already applied.
    function commit() {
        const path = shown
        open = false

        if (Logic.needsApply(applied, path) && !applier.running)
            startApply(path)
    }

    // Esc: back to the original; the stage plays the transition in reverse.
    function cancel() {
        open = false

        if (shown !== applied) {
            shown = applied
            const i = files.indexOf(applied)
            if (i >= 0)
                selected = i
        }
    }

    function startApply(path) {
        pending = path
        applier.command = Logic.awwwArgs(path)
        applier.running = true
    }

    // A file that cannot be decoded leaves the bay.
    function drop(path) {
        if (files.indexOf(path) < 0 || path === applied)
            return

        console.log("wallpaper: dropping undecodable file " + path)
        folderFiles = folderFiles.filter(f => f !== path)
        files = files.filter(f => f !== path)

        const i = files.indexOf(shown)
        selected = i >= 0 ? i : Math.max(0, Math.min(selected, files.length - 1))
        if (i < 0 && files.length > 0)
            shown = files[selected]
    }

    onShownChanged: describeTimer.restart()

    Component.onCompleted: {
        lister.running = true
        querier.running = true
        motionProbe.running = true
        queryGiveUp.start()
    }

    // If awww does not answer, the stored path stands.
    Timer {
        id: queryGiveUp

        interval: 3000
        onTriggered: {
            if (!root.queryDone) {
                root.queryDone = true
                root.resolveApplied()
            }
        }
    }

    // The folder is watched while the picker is open: a wallpaper added or removed shows up without reopening.
    Timer {
        interval: 2000
        repeat: true
        running: root.open
        onTriggered: root.refresh()
    }

    Timer {
        id: describeTimer

        interval: 120
        onTriggered: root.describe(root.shown)
    }

    FileView {
        id: stateView

        path: root.stateFile
        printErrors: false      // the file does not exist until the first change
        atomicWrites: true

        onLoaded: root.loadState(text())
        onLoadFailed: root.loadState("")
    }

    Process {
        id: lister

        command: ["find", "-L", root.dir, "-maxdepth", "1", "-type", "f", "-printf", "%f\n"]
        stdout: StdioCollector {
            onStreamFinished: root.listed(text)
        }
    }

    Process {
        id: querier

        command: ["awww", "query"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.queryPath = Logic.parseAwwwQuery(text)
                root.queryDone = true
                root.resolveApplied()
            }
        }
    }

    Process {
        id: applier

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && exitStatus === 0) {
                root.applied = root.pending
                root.save()
                root.rebuild()
            } else {
                // Keep the last good wallpaper and say so; the stage returns to it.
                root.shown = root.applied
                Hud.show("WALLPAPER", "awww failed", "")
            }
        }
    }

    Process {
        id: identifier

        stdout: StdioCollector {
            onStreamFinished: root.dimensions = text.trim()
        }
    }

    // gsettings may be missing: then animations stay on.
    Process {
        id: motionProbe

        command: ["gsettings", "get", "org.gnome.desktop.interface", "enable-animations"]
        stdout: StdioCollector {
            onStreamFinished: root.reducedMotion = text.trim() === "false"
        }
    }

    IpcHandler {
        target: "wallpaper"

        function toggle(): void {
            root.toggle()
        }

        function isOpen(): bool {
            return root.open
        }

        function next(): void {
            root.step(1)
        }

        function prev(): void {
            root.step(-1)
        }

        function effect(name: string): string {
            if (!Logic.isEffect(name))
                return "unknown effect: " + name

            root.setEffect(name)
            return root.effect
        }

        function apply(): void {
            root.commit()
        }

        function cancel(): void {
            root.cancel()
        }

        function status(): string {
            return JSON.stringify({
                open: root.open,
                applied: root.applied,
                shown: root.shown,
                selected: root.selected,
                count: root.files.length,
                effect: root.effect,
                applying: root.applying,
                reducedMotion: root.reducedMotion,
                dimensions: root.dimensions
            })
        }

        function list(): string {
            return root.files.join("\n")
        }
    }
}
