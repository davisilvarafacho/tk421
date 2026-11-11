import QtQuick
import QtQuick.Shapes

import "../theme"

// A bar capsule that hangs from the top edge of the screen: concave flares where it meets the edge and a rounded
// bottom, like the island's silhouette (island/Island.qml). The content goes inside as usual; the flares are drawn
// outside the item, so leave 2 * flare between neighbours. `stickLeft` / `stickRight` glue that side to the screen
// wall instead (no flare, square corner): place the item at the screen edge with no margin.
Item {
    id: tab

    property bool stickLeft: false
    property bool stickRight: false

    readonly property real flare: 12
    readonly property real radius: Math.max(0, Math.min(height / 2, height - flare, width / 2))
    readonly property real lf: stickLeft ? 0 : flare        // left flare
    readonly property real rf: stickRight ? 0 : flare       // right flare
    readonly property real lr: stickLeft ? 0 : radius       // bottom-left corner
    readonly property real rr: stickRight ? 0 : radius      // bottom-right corner

    implicitHeight: 38

    Shape {
        x: -tab.lf
        z: -1
        width: tab.lf + tab.width + tab.rf
        height: tab.height
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: Theme.imperial.surface
            strokeColor: Theme.imperial.border
            strokeWidth: 1

            // Starts above the screen so the closing top line is never drawn.
            startX: 0
            startY: -2
            PathLine { x: 0; y: 0 }
            PathArc { x: tab.lf; y: tab.lf; radiusX: tab.lf; radiusY: tab.lf; direction: PathArc.Clockwise }
            PathLine { x: tab.lf; y: tab.height - tab.lr }
            PathArc { x: tab.lf + tab.lr; y: tab.height; radiusX: tab.lr; radiusY: tab.lr; direction: PathArc.Counterclockwise }
            PathLine { x: tab.lf + tab.width - tab.rr; y: tab.height }
            PathArc { x: tab.lf + tab.width; y: tab.height - tab.rr; radiusX: tab.rr; radiusY: tab.rr; direction: PathArc.Counterclockwise }
            PathLine { x: tab.lf + tab.width; y: tab.rf }
            PathArc { x: tab.lf + tab.width + tab.rf; y: 0; radiusX: tab.rf; radiusY: tab.rf; direction: PathArc.Clockwise }
            PathLine { x: tab.lf + tab.width + tab.rf; y: -2 }
        }
    }
}
