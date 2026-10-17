pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Which dropdown is open under the bar. There is one slot: opening a panel closes the other one.
// Panels: "power", "tray" (overflow), "menu" (a tray app's own menu). The window is dropdown/DropdownHost.qml.
Singleton {
    id: root

    // Referenced from shell.qml so the IPC handler exists from the start.
    readonly property bool active: true

    readonly property var panels: ["power", "tray", "menu", "net", "bt", "sound"]     // later: "notif"

    property string current: ""
    property var menuItem: null             // the SystemTrayItem whose menu the "menu" panel shows
    property real menuAnchorX: 0            // screen x (px) of the tray icon the menu belongs to

    // A click outside closes the panel through the focus grab and is followed by the click on the button that caused it.
    // Remember which panel the grab closed, so that click does not reopen it.
    property string grabClosedName: ""
    property double grabClosedAt: 0

    // A screenshot (slurp) takes the keyboard focus, which would clear the focus grab and close the panel it is meant to capture.
    // While held, the grab is off. hypr/tk421-screenshot.sh holds and releases; the timer is a safety net if it never releases.
    property bool held: false

    function hold() {
        held = true
        holdTimeout.restart()
    }

    function release() {
        holdTimeout.stop()
        held = false
    }

    Timer {
        id: holdTimeout
        interval: 60000
        onTriggered: root.held = false
    }

    function recentlyClosedByGrab(name) {
        return name === grabClosedName && Date.now() - grabClosedAt < 400
    }

    function open(name) {
        if (panels.indexOf(name) < 0 || name === current || recentlyClosedByGrab(name))
            return
        current = name
    }

    function toggle(name) {
        if (current === name)
            close()
        else
            open(name)
    }

    function close() {
        current = ""
    }

    function openMenu(item, anchorX) {
        if (!item || (current !== "menu" && recentlyClosedByGrab("menu")))
            return
        menuItem = item
        menuAnchorX = anchorX
        current = "menu"
    }

    function closeByGrab() {
        if (current === "")
            return
        grabClosedName = current
        grabClosedAt = Date.now()
        current = ""
    }

    // Leaving the power panel drops a pending "are you sure?".
    onCurrentChanged: {
        if (current !== "power")
            Power.cancel()
    }

    IpcHandler {
        target: "dropdown"

        function open(name: string): void {
            root.open(name)
        }

        function close(): void {
            root.close()
        }

        function hold(): void {
            root.hold()
        }

        function release(): void {
            root.release()
        }

        function status(): string {
            return "current=" + root.current + (root.held ? " held" : "")
        }
    }
}
