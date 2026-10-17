pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Calendar events for the island agenda. Events come from agenda/cache/agenda.json, written by
// agenda/sync.py (Google Calendar secret iCal feed). Event shape:
// { date: "YYYY-MM-DD", allday: bool, time: "HH:mm", title: string, sub: string, calendar: string }
Singleton {
    id: root

    readonly property string dir: Qt.resolvedUrl("../agenda/").toString().replace("file://", "")
    readonly property string home: Quickshell.env("HOME")

    property var events: []
    property string generatedAt: ""

    // "unknown" (no sync result yet) | "ok" | "stale" (last sync failed, showing old data)
    // | "unconfigured" (no/invalid config) | "error"
    property string status: "unknown"
    property double lastSyncStart: 0

    // Failure bookkeeping: one quick retry (Wi-Fi often is not up yet at login), cleared by any success.
    property bool retried: false
    property bool started: false
    property int pendingCode: 0
    property int pendingStatus: 0

    function pad(n) {
        return String(n).padStart(2, "0")
    }

    function dateKey(d) {
        return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate())
    }

    // All-day events first, then by start time.
    function eventsOn(d) {
        const key = dateKey(d)

        return events
            .filter(e => e.date === key)
            .sort((a, b) => (b.allday ? 1 : 0) - (a.allday ? 1 : 0) || String(a.time).localeCompare(String(b.time)))
    }

    function hasEvents(d) {
        return eventsOn(d).length > 0
    }

    function sync() {
        if (syncProcess.running)
            return

        lastSyncStart = Date.now()
        settle.stop()
        syncProcess.running = true
        watchdog.restart()
    }

    function fail(newStatus) {
        status = newStatus

        if (!retried) {
            retried = true
            retryTimer.restart()
        }
    }

    // Decide the status once the process has exited and its stderr has been drained.
    function finish() {
        const code = pendingCode
        const crashed = pendingStatus !== 0 // QProcess::NormalExit (the enum is not exported to QML)

        if (!crashed && code === 0) {
            status = "ok"
            retried = false
            retryTimer.stop()
        } else if (crashed) {
            fail("error")
        } else if (code === 2 && errOut.text.startsWith("config error:")) {
            status = "unconfigured" // a real config problem: retrying will not help
        } else if (code === 3 && events.length > 0) {
            fail("stale")
        } else {
            fail("error")
        }
    }

    // The first load of the cache decides whether the startup sync can be skipped (it is fresh enough).
    function startup() {
        if (started)
            return

        started = true

        const written = generatedAt ? Date.parse(generatedAt) : NaN
        const age = Date.now() - written

        if (!isNaN(written) && age >= 0 && age < 5 * 60 * 1000) {
            lastSyncStart = written
            if (status === "unknown")
                status = "ok"
        } else {
            sync()
        }
    }

    // Used when the island opens: sync only if the last attempt is older than 5 minutes.
    function refreshIfStale() {
        if (Date.now() - lastSyncStart > 5 * 60 * 1000)
            sync()
    }

    function apply(text) {
        try {
            const data = JSON.parse(text)

            if (Array.isArray(data.events)) {
                events = data.events.filter(e => e && typeof e === "object" && typeof e.date === "string")
                generatedAt = data.generated_at || ""
            }
        } catch (e) {
            // Corrupt cache: keep whatever we already show.
        }
    }

    FileView {
        id: cache

        path: root.dir + "cache/agenda.json"
        watchChanges: true
        printErrors: false // the cache does not exist until the first successful sync

        onFileChanged: reload()
        onLoaded: {
            root.apply(text())
            root.startup()
        }
        onLoadFailed: root.startup()
    }

    Process {
        id: syncProcess

        // PATH may lack ~/.local/bin when Quickshell is started from the Hyprland autostart.
        command: ["env", "PATH=" + root.home + "/.local/bin:" + Quickshell.env("PATH"),
                  "uv", "run", "--quiet", "--project", root.dir, root.dir + "sync.py"]

        // stderr is only inspected for sync.py's own "config error:" prefix; it is never logged.
        stderr: StdioCollector {
            id: errOut
        }

        onExited: (exitCode, exitStatus) => {
            watchdog.stop()

            // The cache may not have existed when the FileView started (nothing to watch yet).
            cache.reload()

            // Give the stderr collector a moment to see the end of the stream before deciding.
            root.pendingCode = exitCode
            root.pendingStatus = exitStatus
            settle.restart()
        }
    }

    Timer {
        id: settle

        interval: 200
        onTriggered: root.finish()
    }

    // A hung sync (no network, stuck uv download) must not block later syncs forever.
    Timer {
        id: watchdog

        interval: 120 * 1000
        onTriggered: {
            if (syncProcess.running) {
                syncProcess.running = false
                settle.stop()
                root.fail("error")
            }
        }
    }

    Timer {
        id: retryTimer

        interval: 60 * 1000
        onTriggered: root.sync()
    }

    Timer {
        interval: 15 * 60 * 1000
        repeat: true
        running: true
        onTriggered: root.sync()
    }

    IpcHandler {
        target: "agenda"

        function status(): string {
            return root.status
        }

        function sync(): void {
            root.sync()
        }
    }
}
