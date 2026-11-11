import QtQuick

import "../theme"

// A free-floating bar capsule: 30 px, fully rounded, 4 px below the screen edge, the island's opaque black with its
// faint light hairline. Every capsule of the bar (resources, workspaces, tray, toolbar) is one, so they read as a set.
// Content goes inside as usual; keep ~16 px between the pill edge and the first glyph (text pills pad 16, icon-cell
// pills pad 11 because a 24 px cell already centres its glyph ~5 px in), and 4 px between icon cells.
Rectangle {
    implicitHeight: 30
    radius: height / 2

    color: Theme.imperial.ink
    border.width: 1
    border.color: Theme.imperial.hairline
}
