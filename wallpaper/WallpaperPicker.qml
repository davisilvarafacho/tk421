import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes

import "../services"
import "../theme"
import "logic.js" as Logic

// Wallpaper picker: a blast door in the middle of the screen. The leaves part (and retract into the jambs) to show a bay with the
// wallpapers; ← → move the selection and the desktop behind changes live (wallpaper/WallpaperStage.qml); ↑ ↓ pick the transition
// effect; Enter keeps the wallpaper, Esc restores the original. Prototype: prototypes/wallpaper/index.html
// IPC lives in services/Wallpaper.qml (target `wallpaper`).
PanelWindow {
    id: win

    // Graphite and steel only, as the prototype and the launcher. Theme.imperial.accent is blue, so the steel tokens live here.
    readonly property QtObject k: QtObject {
        readonly property color surface: Theme.imperial.surface
        readonly property color border: Theme.imperial.border
        readonly property color text: Theme.imperial.text
        readonly property color muted: Theme.imperial.muted
        readonly property color steel: "#B9B6B2"
        readonly property color steelText: "#F2F0ED"
        readonly property color lamp: "#2A2A31"
        readonly property color bay: "#060608"
    }

    readonly property real u: Math.min(1, width * 0.000734)      // 1 design px: the door is 1280 wide on a 2560 px screen
    readonly property bool open: Wallpaper.open
    readonly property int count: Wallpaper.files.length

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: open || door.opacity > 0.01

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "tk421-wallpaper-picker"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: {
        if (open)
            keys.forceActiveFocus()
    }

    Item {
        id: keys

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Right)
                Wallpaper.step(1)
            else if (event.key === Qt.Key_Left)
                Wallpaper.step(-1)
            else if (event.key === Qt.Key_Down)
                Wallpaper.cycleEffect(1)
            else if (event.key === Qt.Key_Up)
                Wallpaper.cycleEffect(-1)
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                Wallpaper.commit()
            else if (event.key === Qt.Key_Escape)
                Wallpaper.cancel()
            else
                return

            event.accepted = true
        }
    }

    // A light scrim: the desktop behind is the preview, so it must stay readable. Click outside the door cancels.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(5 / 255, 5 / 255, 5 / 255, 0.3)
        opacity: win.open ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: win.open ? 360 : 220 } }

        MouseArea {
            anchors.fill: parent
            onClicked: Wallpaper.cancel()
        }
    }

    Item {
        id: door

        readonly property real ch: 16 * win.u            // corner chamfer

        width: 1280 * win.u
        height: 434 * win.u
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.985

        Behavior on opacity { NumberAnimation { duration: win.open ? 220 : 180 } }
        Behavior on scale { Ease { duration: win.open ? 520 : 260 } }

        // Swallows clicks on the door so they do not reach the scrim.
        MouseArea { anchors.fill: parent }

        // The frame: a chamfered plate with a 1 px steel edge.
        Shape {
            anchors.fill: parent
            layer.enabled: true
            layer.samples: 4

            ShapePath {
                fillColor: win.k.surface
                strokeColor: win.k.border
                strokeWidth: 1

                PathPolyline {
                    path: [
                        Qt.point(door.ch, 0.5),
                        Qt.point(door.width - door.ch, 0.5),
                        Qt.point(door.width - 0.5, door.ch),
                        Qt.point(door.width - 0.5, door.height - door.ch),
                        Qt.point(door.width - door.ch, door.height - 0.5),
                        Qt.point(door.ch, door.height - 0.5),
                        Qt.point(0.5, door.height - door.ch),
                        Qt.point(0.5, door.ch),
                        Qt.point(door.ch, 0.5)
                    ]
                }
            }
        }

        // ---------- lintel: the effect names (left), one lamp per wallpaper (right) ----------
        Item {
            id: lintel

            width: parent.width
            height: 44 * win.u

            Rectangle {
                y: parent.height - 1
                width: parent.width
                height: 1
                color: win.k.border
            }

            EffectButton {
                x: 28 * win.u
                anchors.verticalCenter: parent.verticalCenter
                u: win.u
                steel: win.k.steel
                steelText: win.k.steelText
                edge: win.k.border
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 28 * win.u
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6 * win.u

                Repeater {
                    model: Math.min(win.count, 24)

                    Rectangle {
                        required property int index
                        readonly property bool on: index === Logic.lampIndex(Wallpaper.selected, win.count, 24)

                        width: 14 * win.u * (on ? 1.5 : 1)
                        height: 3 * win.u
                        color: on ? win.k.steelText : win.k.lamp

                        Behavior on width { Ease { duration: 380 } }
                        Behavior on color { ColorAnimation { duration: 220 } }
                    }
                }
            }
        }

        // ---------- bay: dark recess; the leaves cover it until the door opens ----------
        Item {
            id: bay

            y: 44 * win.u
            width: parent.width
            height: 340 * win.u
            clip: true

            Rectangle {
                anchors.fill: parent
                color: win.k.bay
            }

            // Ceiling and floor ribs of the corridor. (Inline components cannot see ids of the enclosing file, so the geometry
            // is passed in.)
            component Ribs: Item {
                id: ribs

                required property bool floor
                property real u: 1
                property real bayWidth: 0
                property real bayHeight: 0

                y: floor ? bayHeight - 22 * u : 0
                width: bayWidth
                height: 22 * u
                z: 1

                Repeater {
                    model: 3

                    Rectangle {
                        required property int index

                        y: index * 7 * ribs.u
                        width: parent.width
                        height: 5 * ribs.u
                        color: "#121216"
                    }
                }

                Rectangle {
                    y: ribs.floor ? 0 : parent.height - 1
                    width: parent.width
                    height: 1
                    color: "#22222A"
                }
            }

            Ribs { floor: false; u: win.u; bayWidth: bay.width; bayHeight: bay.height }
            Ribs { floor: true; u: win.u; bayWidth: bay.width; bayHeight: bay.height }

            // Strip light in the ceiling: a hairline and a wash falling on the wallpapers. It comes on after the leaves start to part.
            Rectangle {
                x: bay.width * 0.12
                y: 22 * win.u
                z: 1
                width: bay.width * 0.76
                height: 150 * win.u
                opacity: win.open ? 1 : 0
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(0.95, 0.94, 0.93, 0.10) }
                    GradientStop { position: 0.85; color: Qt.rgba(0.95, 0.94, 0.93, 0) }
                }

                Behavior on opacity {
                    SequentialAnimation {
                        PauseAnimation { duration: win.open ? 380 : 0 }
                        NumberAnimation { duration: win.open ? 700 : 260 }
                    }
                }

                // The wash has no hard side edges: both ends fade into the bay colour.
                Rectangle {
                    width: parent.width * 0.22
                    height: parent.height
                    gradient: Gradient {
                        orientation: Gradient.Horizontal

                        GradientStop { position: 0; color: win.k.bay }
                        GradientStop { position: 1; color: Qt.rgba(0.024, 0.024, 0.031, 0) }
                    }
                }

                Rectangle {
                    x: parent.width * 0.78
                    width: parent.width * 0.22
                    height: parent.height
                    gradient: Gradient {
                        orientation: Gradient.Horizontal

                        GradientStop { position: 0; color: Qt.rgba(0.024, 0.024, 0.031, 0) }
                        GradientStop { position: 1; color: win.k.bay }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal

                        GradientStop { position: 0; color: Qt.rgba(0.95, 0.94, 0.93, 0) }
                        GradientStop { position: 0.22; color: Qt.rgba(0.95, 0.94, 0.93, 0.5) }
                        GradientStop { position: 0.78; color: Qt.rgba(0.95, 0.94, 0.93, 0.5) }
                        GradientStop { position: 1; color: Qt.rgba(0.95, 0.94, 0.93, 0) }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: win.count === 0
                text: "NO IMAGES"
                color: win.k.muted
                font.family: Theme.displayFont
                font.pixelSize: 12 * win.u
                font.weight: Font.Medium
                font.letterSpacing: 3 * win.u
                renderType: Text.CurveRendering
            }

            // Scrolling over the bay changes the wallpaper: down is forward, up is back. (A MouseArea, not a WheelHandler: the handler
            // never fires on this Quickshell/Qt. It takes the wheel only, so clicks still reach the plates and the door.)
            MouseArea {
                property real acc: 0

                anchors.fill: parent
                z: 1
                acceptedButtons: Qt.NoButton

                onWheel: wheel => {
                    const d = Math.abs(wheel.angleDelta.y) >= Math.abs(wheel.angleDelta.x) ? wheel.angleDelta.y : wheel.angleDelta.x
                    const r = Logic.wheelStep(acc, d)
                    acc = r.acc
                    for (let i = 0; i < Math.abs(r.steps); i++)
                        Wallpaper.step(r.steps > 0 ? 1 : -1)
                }
            }

            Item {
                anchors.fill: parent
                z: 2

                Repeater {
                    model: Wallpaper.files

                    Plate {
                        u: win.u
                        selected: Wallpaper.selected
                        count: win.count
                        revealed: win.open
                        steel: win.k.steel
                        steelText: win.k.steelText
                        edge: win.k.border
                    }
                }
            }

            DoorLeaf { side: -1; open: win.open; u: win.u; bayWidth: bay.width }
            DoorLeaf { side: 1; open: win.open; u: win.u; bayWidth: bay.width }
            DoorJamb { side: -1; x: 0; open: win.open; u: win.u }
            DoorJamb { side: 1; x: bay.width - width; open: win.open; u: win.u }

            // The lock between the leaves clears as they part.
            Rectangle {
                x: (bay.width - width) / 2
                y: (bay.height - height) / 2
                z: 6
                width: 4 * win.u
                height: 54 * win.u
                color: win.k.lamp
                opacity: win.open ? 0 : 1

                Behavior on opacity {
                    SequentialAnimation {
                        PauseAnimation { duration: win.open ? 260 : 0 }
                        NumberAnimation { duration: 260 }
                    }
                }
            }
        }

        // ---------- sill: name and size (left), keys (right) ----------
        Item {
            id: sill

            y: 384 * win.u
            width: parent.width
            height: 50 * win.u

            Rectangle {
                width: parent.width
                height: 1
                color: win.k.border
            }

            Row {
                x: 28 * win.u
                anchors.verticalCenter: parent.verticalCenter
                spacing: 16 * win.u

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.count > 0 ? Logic.displayName(Wallpaper.shown).toUpperCase() : "NO IMAGES"
                    color: win.k.text
                    textFormat: Text.PlainText
                    font.family: Theme.fontFamily
                    font.pixelSize: 15 * win.u
                    font.weight: Font.Medium
                    renderType: Text.CurveRendering
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Wallpaper.dimensions
                    color: win.k.muted
                    textFormat: Text.PlainText
                    font.family: Theme.displayFont
                    font.pixelSize: 11 * win.u
                    font.weight: Font.Medium
                    font.letterSpacing: 2.2 * win.u
                    renderType: Text.CurveRendering
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 28 * win.u
                anchors.verticalCenter: parent.verticalCenter
                spacing: 20 * win.u

                KeyHint { u: win.u; caps: ["←", "→"]; label: "WALLPAPER" }
                KeyHint { u: win.u; caps: ["↑", "↓"]; label: "EFFECT" }
                KeyHint { u: win.u; caps: ["↵"]; label: "APPLY" }
                KeyHint { u: win.u; caps: ["ESC"]; label: "CANCEL" }
            }
        }
    }
}
