pragma Singleton

import Quickshell
import QtQuick

// A brief pill in the island: a confirmation of something the user just did (a power action, opening a tray app).
// Shows `glyph` (an icon name from theme/icons.js) or `image` (a URL), then `label` and `state`.
Singleton {
    id: root

    property bool active: false
    property string label: ""
    property string state: ""
    property string glyph: ""
    property string image: ""

    function show(label, state, glyph, image) {
        root.label = label
        root.state = state
        root.glyph = glyph || ""
        root.image = image || ""
        active = true
        timer.restart()
    }

    Timer {
        id: timer
        interval: 2000
        onTriggered: root.active = false
    }
}
