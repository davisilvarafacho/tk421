import QtQuick
import Quickshell.Services.Notifications

import "logic.js" as Logic

// One notification as the UI sees it. Display fields are cleaned, length-limited copies of the live
// Notification, which its app may replace or withdraw at any moment; `live` is null once it is gone.
QtObject {
    id: entry

    required property int uid
    property var live: null

    property int nid: -1
    property string appName: ""
    property string appIcon: ""
    property string desktopEntry: ""
    property string label: ""           // header name: the app's name, a fallback, or the themed name (see Logic.appLabel)
    property string iconAsset: ""       // themed icon in assets/, or empty
    property string summary: ""         // already a display title (falls back to the app name)
    property string body: ""
    property bool critical: false
    property bool low: false
    property bool isTransient: false    // not named `transient`: that is a reserved word in QML
    property bool resident: false
    property var actions: []            // [{ index, identifier, text }]; index points into live.actions
    property double timestamp: Date.now()
    property bool unread: true
    property bool dropped: false        // removed by the service: ignore anything else that happens to it

    signal updated()                    // the app replaced or edited it
    signal withdrawn()                  // the app closed it

    function refresh() {
        const n = live
        if (!n)
            return

        nid = n.id
        appName = Logic.clip(n.appName, Logic.LIMITS.appName)
        appIcon = n.appIcon
        desktopEntry = n.desktopEntry
        summary = Logic.titleOf(n.summary, n.appName)
        const app = Logic.appLabel(n.appName, n.desktopEntry, n.summary)
        label = app.name
        iconAsset = app.asset
        body = Logic.clip(n.body, Logic.LIMITS.body)
        critical = n.urgency === NotificationUrgency.Critical
        low = n.urgency === NotificationUrgency.Low
        isTransient = n.transient === true || n.mockTransient === true      // reading n.transient is fine; declaring it is not
        resident = n.resident
        actions = Logic.pickActions(n.actions)
    }

    // Property changes arrive one at a time; one timer turns a replacement into a single update.
    property Timer debounce: Timer {
        interval: 40
        onTriggered: {
            entry.refresh()
            entry.updated()
        }
    }

    property Connections watcher: Connections {
        target: entry.live
        ignoreUnknownSignals: true

        function onSummaryChanged() { entry.debounce.restart() }
        function onBodyChanged() { entry.debounce.restart() }
        function onAppIconChanged() { entry.debounce.restart() }
        function onUrgencyChanged() { entry.debounce.restart() }
        function onActionsChanged() { entry.debounce.restart() }
        function onClosed(reason) { entry.withdrawn() }
    }
}
