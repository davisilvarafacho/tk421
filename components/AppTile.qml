import Quickshell
import QtQuick

import "../theme"
import "../notifications/logic.js" as Logic

// App icon of a notification, drawn as it is (no box). Resolution order: the app's icon name or absolute path,
// then the desktop entry's icon, then a generic bell. Icons with a URL scheme are discarded in logic.js,
// so a notification cannot make the shell fetch a remote image.
Item {
    id: tile

    property string appIcon: ""
    property string desktopEntry: ""
    property bool critical: false
    property int size: 28
    property string asset: ""           // a themed icon in assets/<asset>.svg; wins over the app's own icon

    readonly property var picked: Logic.iconSource(appIcon)
    readonly property string entryIcon: desktopEntry !== "" ? (DesktopEntries.byId(desktopEntry)?.icon ?? "") : ""
    readonly property string named: picked.kind === "name" ? picked.value : picked.kind === "none" ? entryIcon : ""
    readonly property string source: asset !== "" ? Qt.resolvedUrl("../assets/" + asset + ".svg")
        : picked.kind === "path" ? "file://" + picked.value
        : named !== "" ? Quickshell.iconPath(named, true) : ""

    implicitWidth: size
    implicitHeight: size

    Image {
        id: icon

        anchors.fill: parent
        source: tile.source
        sourceSize: Qt.size(tile.size * 2, tile.size * 2)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        visible: status === Image.Ready
    }

    Icon {
        anchors.centerIn: parent
        visible: !icon.visible
        name: "notifications"
        color: tile.critical ? Theme.imperial.dangerText : Theme.imperial.muted
        size: tile.size * 0.75
    }
}
