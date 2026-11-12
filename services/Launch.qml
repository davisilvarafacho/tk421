pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

import "../launcher/logic.js" as Logic

// Shared state of the launcher (launcher/Launcher.qml), which grows out of the Dynamic Island:
// `open` tells the island to hide its own content while the launcher covers it, and the island writes its current
// size here so the launcher starts its growth from exactly that shape.
// Also the launch history (frequent / recent), kept in git-ignored launcher/history.json: { id: { hits, last } }.
Singleton {
    id: root

    property bool open: false
    property real islandWidth: 144
    property real islandHeight: 42

    property var history: ({})

    function record(id) {
        history = Logic.record(history, id, Date.now())
        historyView.setText(JSON.stringify(history))
    }

    FileView {
        id: historyView

        path: Quickshell.shellPath("launcher/history.json")
        printErrors: false      // the file does not exist until the first launch
        atomicWrites: true

        onLoaded: {
            try {
                const h = JSON.parse(text())
                root.history = h && typeof h === "object" ? h : {}
            } catch (e) {
                root.history = {}
            }
        }
    }
}
