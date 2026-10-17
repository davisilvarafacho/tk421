pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false

    signal changed()

    // Ignore the initial readings and sink switches; only real changes count.
    property bool ready: false

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    onSinkChanged: {
        ready = false
        settle.restart()
    }

    Timer {
        id: settle
        interval: 300
        running: true
        onTriggered: root.ready = true
    }

    onVolumeChanged: if (ready) changed()
    onMutedChanged: if (ready) changed()
}
