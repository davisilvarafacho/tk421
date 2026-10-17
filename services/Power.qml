pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

import "../dropdown/power.js" as Logic

// Power actions of the bar menu. The commands come from dropdown/power.js.
// Released by the user on 2026-10-13: dryRun is false and the buttons really act. While dryRun is true nothing is executed,
// the action is only recorded in `last`. The shell hot-reloads while other sessions edit this repository, so the IPC `run` and
// `confirm` below do nothing unless dryRun is true: a test can never suspend the machine through them. Never set dryRun back
// to false from a test.
Singleton {
    id: root

    readonly property bool active: true
    // The real path of shell.qml (Qt.resolvedUrl gives Quickshell's virtual "qs:@/" path, which the lock command cannot use).
    readonly property string shellPath: Quickshell.shellPath("shell.qml")
    readonly property var actions: Logic.ACTIONS

    property bool dryRun: false
    property string confirming: ""          // "" or the id of the action waiting for a yes
    property string last: ""                // what was run, or would have been

    function find(id) {
        return Logic.ACTIONS.find(a => a.id === id) ?? null
    }

    // Destructive actions ask first; the question cancels itself after 5 s.
    function ask(id) {
        if (!Logic.isDestructive(id))
            return
        confirming = id
        confirmTimer.restart()
    }

    function cancel() {
        confirming = ""
        confirmTimer.stop()
    }

    function confirm() {
        const id = confirming
        if (id === "")
            return
        cancel()
        run(id)
    }

    function run(id) {
        const action = find(id)
        const command = Logic.commandFor(id, shellPath)
        if (!action || !command)
            return

        cancel()
        last = id + ": " + command.join(" ")
        if (!dryRun)
            Quickshell.execDetached(command)

        Hud.show(action.hud, dryRun ? "dry run" : "…", action.glyph, "")
        Dropdown.close()
    }

    Timer {
        id: confirmTimer
        interval: 5000
        onTriggered: root.confirming = ""
    }

    IpcHandler {
        target: "power"

        function status(): string {
            return "dryRun=" + root.dryRun + " confirming=" + root.confirming + " last=" + root.last
        }

        function setDryRun(on: bool): void {
            root.dryRun = on
        }

        function ask(id: string): void {
            root.ask(id)
        }

        function cancel(): void {
            root.cancel()
        }

        // Test hooks: refused unless dryRun is true (see the note at the top of this file).
        function confirm(): void {
            if (root.dryRun)
                root.confirm()
        }

        function run(id: string): void {
            if (root.dryRun)
                root.run(id)
        }
    }
}
