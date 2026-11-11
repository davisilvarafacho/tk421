pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import QtQuick

import "../bar/trayLogic.js" as Logic

// The apps that keep an icon in the bar (StatusNotifierItems), split into what the capsule shows and what sits behind
// its chevron. The rules are in bar/trayLogic.js (unit-tested).
Singleton {
    id: root

    // [{ id, item, passive, attention }], in the order the apps registered.
    readonly property var entries: {
        const out = []
        const items = SystemTray.items.values
        for (let i = 0; i < items.length; i++) {
            const it = items[i]
            out.push({
                id: it.id + "#" + i,
                item: it,
                passive: it.status === Status.Passive,
                attention: it.status === Status.NeedsAttention
            })
        }
        return out
    }

    // Every app is shown in the capsule, passive ones included (the user wants them all in sight). The chevron and the
    // "tray" overflow dropdown stay wired but only appear while overflowItems is non-empty, which is now never;
    // Logic.partition(entries, max) brings the old split back.
    readonly property var visibleItems: entries.map(e => e.item)
    readonly property var overflowItems: []
    readonly property bool overflowAttention: false
    readonly property bool any: entries.length > 0

    function nameOf(item) {
        return Logic.cleanLabel(item?.tooltipTitle || item?.title || item?.id || "", 40)
    }

    // Left-click or "Open": activate the app and confirm it in the island.
    function activateItem(item) {
        if (!item)
            return
        item.activate()
        Hud.show(nameOf(item), "Opening", "", item.icon)
    }

    function statusText(item) {
        return item.status === Status.NeedsAttention ? "Needs attention" : item.status === Status.Passive ? "Passive" : "Running"
    }

    // The app quit while its menu was open: close the menu instead of showing a dead one.
    onEntriesChanged: {
        if (Dropdown.current === "menu" && !entries.some(e => e.item === Dropdown.menuItem))
            Dropdown.close()
    }

    // Debugging and tests without a pointer.
    IpcHandler {
        target: "tray"

        function status(): string {
            return "items=" + root.entries.length + " visible=" + root.visibleItems.length + " hidden=" + root.overflowItems.length
                + " attention=" + root.overflowAttention + " dropdown=" + Dropdown.current
        }

        function list(): string {
            return root.entries.map((e, i) => i + ":" + root.nameOf(e.item) + ":" + (e.passive ? "passive" : e.attention ? "attention" : "active")).join(" | ")
        }

        function activate(index: int): void {
            const e = root.entries[index]
            if (e)
                root.activateItem(e.item)
        }

        function menu(index: int): void {
            const e = root.entries[index]
            if (e && e.item.hasMenu)
                Dropdown.openMenu(e.item, 2300)
        }
    }
}
