import Quickshell
import Quickshell.Wayland
import QtQuick

import "../services"
import "effects"
import "logic.js" as Logic

// Draws what the desktop shows while the picker is open or a transition runs, on the Bottom layer: above the awww background,
// below every window, click-through. awww stays the real wallpaper; on Enter the model calls `awww img` and this window hides
// right after, so both show the same image (both crop to cover, centred). The window is transparent wherever nothing is drawn,
// so a still-decoding image shows the awww wallpaper underneath, never black.
PanelWindow {
    id: win

    readonly property int decodeWidth: Math.max(1280, width)

    property string resting: ""          // the image at rest
    property string fromPath: ""
    property string toPath: ""
    property bool running: false
    property real progress: 0
    property bool lingering: false
    readonly property bool busy: Wallpaper.open || Wallpaper.applying || running

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: (busy || lingering) && resting !== ""

    // An empty region: the whole window is click-through.
    mask: Region {}

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "tk421-wallpaper-stage"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    onBusyChanged: {
        if (busy) {
            lingering = true
            release.stop()
        } else {
            release.restart()
        }
    }

    Timer {
        id: release

        interval: 80
        onTriggered: win.lingering = false
    }

    // Start a transition to `path`. A request that arrives mid-transition finishes the running one first (nothing queues).
    function go(path) {
        if (path === "")
            return

        if (running)
            finish()

        if (resting === "") {
            resting = path
            return
        }

        if (path === resting)
            return

        fromPath = resting
        toPath = path
        progress = 0
        anim.duration = Logic.duration(Wallpaper.effect, Wallpaper.reducedMotion)
        running = true
        anim.restart()
    }

    function finish() {
        anim.stop()

        if (running) {
            resting = toPath
            progress = 1
            running = false
        }
    }

    function effectComponent(id) {
        return id === "hyperspace" ? hyper : id === "doors" ? doors : id === "scan" ? scan : laser
    }

    NumberAnimation {
        id: anim

        target: win
        property: "progress"
        from: 0
        to: 1
        onFinished: win.finish()
    }

    Component { id: laser; Superlaser {} }
    Component { id: hyper; Hyperspace {} }
    Component { id: doors; BlastDoors {} }
    Component { id: scan; TacticalScan {} }
    Component { id: crossfade; Crossfade {} }

    Connections {
        target: Wallpaper

        function onShownChanged() {
            win.go(Wallpaper.shown)
        }

        function onOpenChanged() {
            if (Wallpaper.open && !win.running)
                win.resting = Wallpaper.applied
        }
    }

    // Keeps the images that are likely next decoded, so an effect never waits on a 4K file. ScriptModel diffs, so the
    // images that stay in the list are not reloaded when the selection moves.
    ScriptModel {
        id: preload

        values: [win.resting, Wallpaper.shown, Wallpaper.neighbor(-1), Wallpaper.neighbor(1)].filter(p => p !== "")
    }

    Item {
        anchors.fill: parent

        Repeater {
            model: preload

            Image {
                required property string modelData

                visible: false
                asynchronous: true
                source: Logic.fileUrl(modelData)
                sourceSize.width: win.decodeWidth
                fillMode: Image.PreserveAspectCrop
            }
        }

        Image {
            id: restImg

            anchors.fill: parent
            source: win.resting !== "" ? Logic.fileUrl(win.resting) : ""
            sourceSize.width: win.decodeWidth
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready && !fx.active
        }

        // The effect stays loaded after it ends until the resting image is ready, so there is no gap between them.
        Loader {
            id: fx

            anchors.fill: parent
            active: win.running || (win.toPath !== "" && win.resting !== "" && restImg.status !== Image.Ready)
            sourceComponent: Wallpaper.reducedMotion ? crossfade : win.effectComponent(Wallpaper.effect)

            onLoaded: {
                item.fromSource = Qt.binding(() => Logic.fileUrl(win.fromPath))
                item.toSource = Qt.binding(() => Logic.fileUrl(win.toPath))
                item.decodeWidth = win.decodeWidth
                item.progress = Qt.binding(() => win.progress)
            }
        }
    }
}
