pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Plan limits (5 h session, 7 d week) of the signed-in Claude Code account, read through usage/fetch.py
// (OAuth token from ~/.claude, never stored here). Prototype: prototypes/claude-usage/index.html
Singleton {
    id: root

    readonly property string dir: Qt.resolvedUrl("../usage/").toString().replace("file://", "")

    // "unknown" (nothing read yet) | "ok" | "offline" (last read failed; `error` is fetch.py's code)
    property string status: "unknown"
    property string error: ""
    property string plan: ""

    property int sessionPercent: 0
    property int weekPercent: 0
    property string sessionResets: ""   // ISO 8601
    property string weekResets: ""
    property double updatedAt: 0        // ms since the epoch

    property bool open: false           // dropdown card, toggled by the bar chip
    property bool docked: false         // written by UsageCard while the card hangs from the toolbar pill
    readonly property bool busy: fetchProcess.running
    readonly property int worstPercent: Math.max(sessionPercent, weekPercent)

    function refresh() {
        if (!fetchProcess.running)
            fetchProcess.running = true
    }

    function refreshIfStale() {
        if (Date.now() - updatedAt > 60 * 1000)
            refresh()
    }

    function apply(text) {
        let d
        try {
            d = JSON.parse(text)
        } catch (e) {
            d = { ok: false, error: "bad_response" }
        }

        if (!d.ok) {
            status = "offline"
            error = d.error || "bad_response"
            return
        }

        plan = d.plan || ""
        sessionPercent = d.session ? d.session.percent : 0
        weekPercent = d.week ? d.week.percent : 0
        sessionResets = d.session ? d.session.resetsAt || "" : ""
        weekResets = d.week ? d.week.resetsAt || "" : ""
        updatedAt = (d.fetchedAt || 0) * 1000
        error = ""
        status = "ok"
    }

    Process {
        id: fetchProcess

        command: ["python3", "-I", root.dir + "fetch.py"]

        stdout: StdioCollector {
            onStreamFinished: root.apply(text)
        }
    }

    // Every 5 minutes; a failed read (often Wi-Fi not up yet at login) retries after one.
    Timer {
        interval: root.status === "offline" ? 60 * 1000 : 5 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
