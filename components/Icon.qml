import QtQuick
import QtQuick.Shapes

import "../theme"
import "../theme/icons.js" as Icons

// One Material Symbols Sharp glyph, drawn through its ligature. It pins its own
// text settings so the ligature always forms, and draws nothing (one warning in
// the log) when the name is unknown or the font did not form the ligature.
Item {
    id: root

    property string name: ""
    property real size: Theme.iconSize.bar
    property color color: Theme.imperial.text
    property color gapColor: Theme.imperial.ink    // the slash cuts a 1 px gap in this colour
    property string family: Theme.symbolsFont

    readonly property var spec: Icons.resolve(name)
    // Read-only hooks for tests/qml/tst_icons.qml.
    readonly property real glyphWidth: label.contentWidth
    readonly property bool glyphVisible: label.visible
    // A ligature is one glyph (about `size` wide); the word or a fallback font's letters are far wider.
    // Very short names ("tv") are not wider than a glyph in a fallback font, so
    // for the symbols family the font must also be loaded.
    readonly property bool ok: spec !== null && label.contentWidth <= size * 1.5
        && (family !== Theme.symbolsFont || Theme.symbolsLoader.status === FontLoader.Ready)

    property string warnedName: ""

    implicitWidth: size
    implicitHeight: size

    // contentWidth lags behind text/size/family, so `ok` can be briefly stale
    // right after a change. Decide the warning one event-loop turn later, from
    // the settled value, and warn once per failure episode.
    Timer {
        id: settle
        interval: 0
        onTriggered: {
            if (root.ok)
                root.warnedName = ""
            else if (root.name !== "" && root.warnedName !== root.name) {
                root.warnedName = root.name
                console.warn("Icon: cannot draw", root.name)
            }
        }
    }

    onOkChanged: settle.restart()
    onNameChanged: settle.restart()
    onSizeChanged: settle.restart()
    onFamilyChanged: settle.restart()
    Component.onCompleted: settle.restart()

    Item {
        anchors.fill: parent
        scale: root.spec ? root.spec.scale : 1

        Text {
            id: label
            anchors.fill: parent
            visible: root.ok
            text: root.spec ? root.spec.glyph : ""
            color: root.color
            textFormat: Text.PlainText
            renderType: Text.CurveRendering
            wrapMode: Text.NoWrap
            elide: Text.ElideNone
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.family: root.family
            font.pixelSize: root.size
            font.letterSpacing: 0
            font.wordSpacing: 0
            font.capitalization: Font.MixedCase
            font.variableAxes: ({
                "wght": root.spec ? root.spec.weight : 300,
                "FILL": root.spec ? root.spec.fill : 0,
                "GRAD": 0,
                "opsz": 24
            })
        }

        // Mic slash: top-right to bottom-left of the glyph's ink box
        // (x 29%..71%, y 8%..92%), with a 1 px gap on its upper side: the gap
        // stroke is shifted 1 px along the line's normal (0.894, 0.447).
        Shape {
            anchors.fill: parent
            visible: root.ok && root.spec !== null && root.spec.slash
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: root.gapColor
                strokeWidth: 1
                fillColor: "transparent"
                startX: root.size * 0.71 + 0.894
                startY: root.size * 0.08 + 0.447
                PathLine { x: root.size * 0.29 + 0.894; y: root.size * 0.92 + 0.447 }
            }
            ShapePath {
                strokeColor: root.color
                strokeWidth: 1
                fillColor: "transparent"
                startX: root.size * 0.71
                startY: root.size * 0.08
                PathLine { x: root.size * 0.29; y: root.size * 0.92 }
            }
        }
    }
}
