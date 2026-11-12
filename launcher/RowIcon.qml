import QtQuick
import QtQuick.Effects

import "../components"
import "../theme"
import "Fuzzy.js" as Fuzzy

// App icon (greyscale, candy-grey), a Material Symbol for commands and the calculator, or the initials tile.
Item {
    id: ri

    property var row: null
    property real size: 20
    property bool selected: false
    readonly property bool hasImage: img.status === Image.Ready

    width: size
    height: size

    Image {
        id: img

        anchors.fill: parent
        source: ri.row?.source ?? ""
        sourceSize: Qt.size(ri.size * 2, ri.size * 2)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        visible: ri.hasImage
        opacity: ri.selected ? 1 : 0.62
        layer.enabled: visible
        layer.effect: MultiEffect {
            saturation: -1
        }

        Behavior on opacity { NumberAnimation { duration: 140 } }
    }

    Icon {
        visible: !ri.hasImage && (ri.row?.glyph ?? "") !== ""
        anchors.centerIn: parent
        name: ri.row?.glyph ?? ""
        size: ri.size <= 20 ? Theme.iconSize.panel + 2 : Theme.iconSize.hero + 4
        color: ri.selected ? Theme.imperial.text : Theme.imperial.muted
    }

    Rectangle {
        visible: !ri.hasImage && (ri.row?.glyph ?? "") === ""
        anchors.fill: parent
        radius: ri.size <= 20 ? 6 : 9
        color: ri.selected && ri.size <= 20 ? Theme.imperial.ink : Theme.imperial.surfaceAlt

        Text {
            anchors.centerIn: parent
            text: Fuzzy.initials(ri.row?.initials ?? ri.row?.name ?? "")
            textFormat: Text.PlainText
            color: ri.selected ? Theme.imperial.text : Theme.imperial.muted
            font.family: Theme.fontFamily
            font.pixelSize: ri.size <= 20 ? 9 : 12
            font.weight: Font.DemiBold
            renderType: Text.CurveRendering
        }
    }
}
