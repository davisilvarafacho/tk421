pragma Singleton

import Quickshell
import Quickshell.Services.Mpris
import QtQuick

// Normalized view of whichever MPRIS player is active (Spotify, browsers, ...).
Singleton {
    id: root

    // Fake track for previewing the layout without a real player.
    property bool mock: false
    property bool mockPlaying: true
    property real mockPosition: 72

    readonly property var player: {
        const list = Mpris.players.values
        let first = null
        for (let i = 0; i < list.length; i++) {
            if (list[i].isPlaying)
                return list[i]
            if (first === null)
                first = list[i]
        }
        return first
    }

    readonly property bool present: mock || player !== null
    readonly property string title: mock ? "The Imperial March" : (player?.trackTitle ?? "")
    readonly property string artist: mock ? "John Williams" : (player?.trackArtist ?? "")
    readonly property string source: mock ? "Spotify" : (player?.identity ?? "")
    readonly property string art: mock ? "" : (player?.trackArtUrl ?? "")
    readonly property bool playing: mock ? mockPlaying : (player?.isPlaying ?? false)
    readonly property real length: mock ? 186 : (player?.length ?? 0)
    readonly property bool canControl: mock || player !== null

    property real position: 0

    function toggle() {
        if (mock) mockPlaying = !mockPlaying
        else if (player?.canTogglePlaying) player.togglePlaying()
    }

    function next() {
        if (!mock && player?.canGoNext) player.next()
    }

    function previous() {
        if (mock) mockPosition = 0
        else if (player?.canGoPrevious) player.previous()
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.present
        onTriggered: {
            if (root.mock) {
                if (root.mockPlaying)
                    root.mockPosition = (root.mockPosition + 1) % 186
                root.position = root.mockPosition
            } else if (root.player) {
                root.player.positionChanged()
                root.position = root.player.position
            }
        }
    }
}
