pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick

import "../notifications"
import "../notifications/logic.js" as Logic

// Notification daemon of the shell. Owns the D-Bus server, the history, Do Not Disturb and the popup (toast).
// The UI never touches Notification objects, it reads this singleton.
// Spec: docs/superpowers/specs/2026-10-12-notifications-design.md
Singleton {
    id: root

    // true: the D-Bus server is not expected to own the name yet (swaync still runs) and `inject` fills the UI
    // with fake notifications. Switched to false at cutover (plan, Task 6).
    property bool mock: false

    // Referenced from shell.qml so the D-Bus server starts with the shell instead of on first use.
    readonly property bool active: true

    property var history: []            // NotificationEntry, newest first
    property int unreadCount: 0
    property bool dnd: false
    property bool centerOpen: false
    property bool settling: false       // centre just closed: unread flags clear after its close animation
    property bool islandOpen: false     // written by Island: an open island suppresses popups
    property bool clearing: false       // clear() just ran, lets the list stagger its exit

    property var toast: null            // the entry shown as a popup, or null
    property bool toastHovered: false
    property real toastProgress: 1      // 1 -> 0 over the popup's life

    property int lastUid: 0
    property int mockId: 100000
    property double grabClosedAt: 0
    property double settleCutoff: 0

    signal pinged()

    // ---- bookkeeping ----

    function recount() {
        unreadCount = history.reduce((n, e) => n + (e.unread ? 1 : 0), 0)
    }

    function setHistory(list) {
        history = list
        recount()
    }

    function urgencyOf(entry) {
        return entry.critical ? "critical" : entry.low ? "low" : "normal"
    }

    function newEntry(n) {
        const e = entryComponent.createObject(root, { uid: ++lastUid, live: n })
        e.refresh()
        e.updated.connect(() => root.arrive(e))
        e.withdrawn.connect(() => root.forget(e))
        return e
    }

    // ---- arrivals ----

    function accept(n) {
        n.tracked = true

        const known = history.find(e => e.nid === n.id)
        if (known) {                                    // the app replaced its own notification
            known.live = n
            known.debounce.restart()
            return
        }

        const entry = newEntry(n)
        if (n.lastGeneration) {                         // carried over a hot reload: restore it, never announce it
            entry.unread = false
            setHistory([entry].concat(history))
            return
        }
        arrive(entry)
    }

    // Popup / ping / history are decided here, once. A suppressed popup is never shown later.
    function arrive(entry) {
        if (entry.dropped)
            return

        entry.unread = true
        entry.timestamp = Date.now()

        const p = Logic.arrivalPolicy({
            centerOpen: centerOpen,
            islandOpen: islandOpen,
            dnd: dnd,
            urgency: urgencyOf(entry),
            transient: entry.isTransient
        })

        const list = history.filter(e => e !== entry)
        if (p.history) {
            list.unshift(entry)
            while (list.length > Logic.LIMITS.history)
                retire(list.pop())
        }
        setHistory(list)

        if (p.toast)
            showToast(entry)
        else if (!p.history)
            retire(entry)                               // transient and not shown: nothing keeps it

        if (p.ping)
            pinged()
    }

    // ---- removal ----

    // Release an entry for good: hide its popup, tell the app (unless the app already closed it), free it later.
    // destroy() is delayed because list rows may still be animating out.
    function retire(entry) {
        if (!entry || entry.dropped)
            return
        entry.dropped = true

        if (toast === entry)
            clearToast()

        const n = entry.live
        entry.live = null
        if (n) {
            // Read before dismiss(): a real Notification is destroyed as soon as its `closed` handlers return.
            const isMock = n.isMock === true
            n.dismiss()
            if (isMock)
                n.destroy(1000)
        }
        entry.destroy(1000)
    }

    function remove(entry) {
        if (!entry || entry.dropped)
            return
        setHistory(history.filter(e => e !== entry))
        retire(entry)
    }

    function dismiss(entry) {
        remove(entry)
    }

    // The app closed it (CloseNotification): it is gone from history and from the popup.
    function forget(entry) {
        entry.live = null
        remove(entry)
    }

    function clear() {
        const old = history
        clearing = true
        clearTimer.restart()
        setHistory([])
        old.forEach(e => retire(e))
    }

    function markRead(entry) {
        if (!entry || entry.dropped)
            return
        entry.unread = false
        recount()
    }

    function invoke(entry, index) {
        if (!entry || entry.dropped || !entry.live)
            return

        const a = entry.actions[index]
        if (!a)
            return

        const resident = entry.resident
        entry.live.actions[a.index].invoke()
        if (resident) {
            hideToast(true)
            markRead(entry)
        } else {
            remove(entry)
        }
    }

    // ---- popup ----

    function showToast(entry) {
        const prev = toast
        toast = entry
        toastHovered = false
        toastProgress = 1

        if (entry.critical)
            countdown.stop()                            // critical alerts stay until dismissed
        else
            countdown.restart()

        if (prev && prev !== entry && prev.isTransient)
            retire(prev)
    }

    function clearToast() {
        countdown.stop()
        const e = toast
        toast = null
        toastHovered = false
        toastProgress = 1
        return e
    }

    // markRead: the user dismissed it (click or x). Timing out leaves it unread.
    function hideToast(markRead) {
        const e = clearToast()
        if (!e)
            return
        if (e.isTransient)
            retire(e)
        else if (markRead)
            root.markRead(e)
    }

    // ---- DND and centre ----

    function setDnd(on) {
        dnd = on
        Hud.show("COMMS", on ? "silenced" : "open", on ? "notifications_paused" : "notifications", "")
        if (on && toast && !toast.critical)
            hideToast(false)
    }

    function setCenterOpen(open) {
        if (open === centerOpen)
            return
        centerOpen = open

        if (open) {
            settleTimer.stop()
            settling = false
            hideToast(true)
        } else {
            settleCutoff = Date.now()
            settling = true
            settleTimer.restart()
        }
    }

    function toggleCenter() {
        if (!centerOpen && Date.now() - grabClosedAt < 400)
            return                                      // the outside click that just closed it must not reopen it
        setCenterOpen(!centerOpen)
    }

    function closeByGrab() {
        if (!centerOpen)
            return
        grabClosedAt = Date.now()
        setCenterOpen(false)
    }

    onIslandOpenChanged: {
        if (islandOpen)
            hideToast(false)
    }

    // ---- mock ----

    function mockSpec(kind) {
        const act = (id, text) => ({ identifier: id, text: text, invoke: () => console.log("mock action:", id) })

        switch (kind) {
        case "normal":
            return { appName: "Ghostty", appIcon: "com.mitchellh.ghostty", summary: "Build finished",
                     body: "quickshell · release build completed in 42 s with 0 warnings.",
                     urgency: NotificationUrgency.Normal, actions: [] }
        case "actions":
            return { appName: "Calendar", appIcon: "x-office-calendar", summary: "Daily starts in 10 minutes",
                     body: "Google Meet · 10:00 · 30 min · 6 attendees",
                     urgency: NotificationUrgency.Normal, actions: [act("join", "Join"), act("snooze", "Snooze")] }
        case "critical":
            return { appName: "System", appIcon: "dialog-warning", summary: "Disk space low",
                     body: "/ is 94% full on nvme0n1p2. Free some space before the next system update.",
                     urgency: NotificationUrgency.Critical, actions: [act("open", "Open")] }
        case "low":
            return { appName: "Updates", appIcon: "system-software-update", summary: "14 updates available",
                     body: "linux, mesa, hyprland and 11 more packages",
                     urgency: NotificationUrgency.Low, actions: [] }
        case "long":
            return { appName: "Chat", appIcon: "", summary: "A very long summary ".repeat(12),
                     body: "Lorem ipsum dolor sit amet. ".repeat(60),
                     urgency: NotificationUrgency.Normal, actions: [act("a", "One"), act("b", "Two"), act("c", "Three"), act("d", "Four")] }
        default:
            return null
        }
    }

    function inject(kind) {
        if (!mock)
            return "mock is off"

        const spec = mockSpec(kind)
        if (!spec)
            return "unknown kind, use: normal actions critical low long"

        const n = mockComponent.createObject(root, Object.assign({ id: ++mockId }, spec))
        accept(n)
        return "ok"
    }

    // ---- parts ----

    Component {
        id: entryComponent

        NotificationEntry {}
    }

    // Stand-in for a Notification, so the UI can be exercised without D-Bus.
    Component {
        id: mockComponent

        QtObject {
            property bool isMock: true
            property int id: 0
            property string appName: ""
            property string appIcon: ""
            property string desktopEntry: ""
            property string summary: ""
            property string body: ""
            property int urgency: NotificationUrgency.Normal
            property var actions: []
            property bool mockTransient: false      // a real Notification has `transient`; a QML property cannot be named that
            property bool resident: false
            property bool lastGeneration: false
            property bool tracked: false

            signal closed(int reason)

            function dismiss() {
                closed(1)
            }
        }
    }

    NotificationServer {
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: false
        inlineReplySupported: false

        onNotification: n => root.accept(n)
    }

    // One animation is both the popup timeout and the line that drains along the island's bottom edge.
    NumberAnimation {
        id: countdown

        target: root
        property: "toastProgress"
        from: 1
        to: 0
        duration: Logic.TOAST_MS
        paused: root.toastHovered && running      // a critical popup has no countdown to pause
        onFinished: root.hideToast(false)
    }

    Timer {
        id: settleTimer
        interval: 360

        onTriggered: {
            root.history.forEach(e => {
                if (e.timestamp <= root.settleCutoff)
                    e.unread = false
            })
            root.settling = false
            root.recount()
        }
    }

    Timer {
        id: clearTimer
        interval: 700
        onTriggered: root.clearing = false
    }

    IpcHandler {
        target: "notifications"

        function toggleCenter(): void {
            root.toggleCenter()
        }

        function toggleDnd(): void {
            root.setDnd(!root.dnd)
        }

        function clear(): void {
            root.clear()
        }

        function status(): string {
            return root.unreadCount + "/" + root.history.length + " dnd=" + root.dnd
                + " toast=" + (root.toast !== null) + " center=" + root.centerOpen
        }

        function inject(kind: string): string {
            return root.inject(kind)
        }
    }
}
