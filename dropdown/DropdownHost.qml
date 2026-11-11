import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

import "../services"
import "../theme"

// The one window behind every bar dropdown (power, tray overflow, a tray app's menu, network, Bluetooth, sound).
// The active panel unrolls from the capsules, exactly like the notification centre design.
// Prototype: prototypes/toolbar/index.html. State: services/Dropdown.qml.
// Panel icons are names from the Material Symbols table (theme/icons.js), drawn by components/Icon.qml; no font glyph literals here (final fix wave 2026-11-11).
PanelWindow {
    id: win

    readonly property var c: Theme.imperial

    // `opened` follows Dropdown.current; `shown` is the last panel and stays mounted while the close animation plays.
    property bool opened: false
    property string shown: ""

    readonly property real panelWidth: shown === "sound" || shown === "keyboard" ? 340 : shown === "net" || shown === "bt" ? 320 : shown === "tray" ? 280 : shown === "menu" ? 210 : 260
    readonly property real hostLeft: (win.screen?.width ?? 2560) - 30 - win.width
    // The tray app's menu sits under the icon it belongs to; slot panels are right-aligned.
    readonly property real menuX: Math.max(12, Math.min(Dropdown.menuAnchorX - hostLeft - 24, win.width - 210 - 12))

    anchors {
        top: true
        right: true
    }
    margins.top: 40
    margins.right: 30
    implicitWidth: 640
    implicitHeight: shown === "keyboard" ? 800 : 520
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    // Stay mapped while the close animation plays.
    visible: opened || panel.height > 0.5

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "tk421-dropdown"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Only the panel takes input; the rest of the window is click-through.
    mask: Region { item: panel }

    component Ease: NumberAnimation {
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
    }

    Connections {
        target: Dropdown

        function onCurrentChanged() {
            const name = Dropdown.current
            if (name === "") {
                win.opened = false
                content.appear = 0
                return
            }

            const wasOpen = win.opened
            win.opened = true
            if (name !== win.shown)
                win.shown = name
            if (wasOpen)
                content.swap()
            else
                content.appear = 1
        }

        // Right-clicking another tray icon while a menu is open: same panel, other app.
        function onMenuItemChanged() {
            if (win.opened && win.shown === "menu")
                content.swap()
        }
    }

    // A click outside closes it.
    HyprlandFocusGrab {
        windows: [win]
        active: win.opened && !Dropdown.held
        onCleared: Dropdown.closeByGrab()
    }

    // Esc first drops a pending "are you sure?", then closes.
    Shortcut {
        sequence: "Escape"
        enabled: win.opened
        onActivated: {
            if (Power.confirming !== "")
                Power.cancel()
            else
                Dropdown.close()
        }
    }

    Rectangle {
        id: panel

        x: win.shown === "menu" ? win.menuX : win.width - width
        y: 0
        width: win.opened ? win.panelWidth : 240
        height: win.opened ? content.implicitHeight + 2 : 0
        radius: win.opened ? 20 : 14
        color: Qt.alpha(win.c.surface, 0.72)
        border.width: 1
        border.color: win.c.border
        clip: true
        opacity: win.opened ? 1 : 0

        Behavior on width { Ease { duration: win.opened ? 520 : 340 } }
        Behavior on height { Ease { duration: win.opened ? 520 : 340 } }
        Behavior on radius { Ease { duration: win.opened ? 520 : 340 } }
        Behavior on opacity { NumberAnimation { duration: win.opened ? 200 : 160 } }

        // Fixed width, so the growing frame never reflows the content.
        Item {
            id: content

            property real appear: 0
            property bool behaviorOn: true

            function swap() {
                swapAnim.restart()
            }

            x: win.shown === "menu" ? 1 : panel.width - width - 1
            y: 1
            width: win.panelWidth - 2
            implicitHeight: loader.item ? loader.item.implicitHeight : 0
            height: implicitHeight

            opacity: appear
            scale: 0.97 + 0.03 * appear
            transformOrigin: win.shown === "menu" ? Item.TopLeft : Item.TopRight

            Behavior on appear {
                enabled: content.behaviorOn

                SequentialAnimation {
                    PauseAnimation { duration: win.opened ? 140 : 0 }
                    NumberAnimation { duration: win.opened ? 320 : 140 }
                }
            }

            // Switching panels while open: the new content rises in.
            SequentialAnimation {
                id: swapAnim

                ScriptAction {
                    script: {
                        content.behaviorOn = false
                        content.appear = 0
                        content.behaviorOn = true
                    }
                }
                NumberAnimation { target: content; property: "appear"; to: 1; duration: 300; easing.type: Easing.OutCubic }
            }

            Loader {
                id: loader

                width: parent.width
                source: win.shown === "power" ? "PowerPanel.qml"
                    : win.shown === "tray" ? "TrayPanel.qml"
                    : win.shown === "menu" ? "TrayMenuPanel.qml"
                    : win.shown === "net" ? "NetworkPanel.qml"
                    : win.shown === "bt" ? "BluetoothPanel.qml"
                    : win.shown === "sound" ? "SoundPanel.qml"
                    : win.shown === "keyboard" ? "KeyboardPanel.qml" : ""
            }
        }
    }
}
