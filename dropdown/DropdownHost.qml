import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

import "../services"
import "../theme"

// The one window behind every bar dropdown (power, tray overflow, a tray app's menu, network, Bluetooth, sound).
// The toolbar panels grow out of the toolbar pill like the comms log; the tray panels unroll below the tray pill.
// Panel building blocks: components/PanelHeader, PanelSection, PanelButton and Theme.imperial.rowHover.
// Reviewed with impeccable critique on 2026-11-12 (contrast, two-click disconnect, wheel, offline states).
// Prototype: prototypes/toolbar/index.html. State: services/Dropdown.qml.
// Panel icons are names from the Material Symbols table (theme/icons.js), drawn by components/Icon.qml; no font glyph literals here (final fix wave 2026-11-11).
PanelWindow {
    id: win

    readonly property var c: Theme.imperial

    // `opened` follows Dropdown.current; `shown` is the last panel and stays mounted while the close animation plays.
    property bool opened: false
    property string shown: ""

    // The toolbar panels dock: they hang from the toolbar pill like the comms log (pill width, ink, no top edge) and the
    // pill squares its bottom corners (Dropdown.docked). The tray panels float 7 px below the tray pill.
    readonly property bool dock: shown !== "" && shown !== "tray" && shown !== "menu"
    readonly property real panelWidth: dock ? Math.round(Notifications.dockWidth) : shown === "sound" || shown === "keyboard" ? 340 : shown === "net" || shown === "bt" ? 320 : shown === "tray" ? 280 : shown === "menu" ? 210 : 260
    readonly property real hostLeft: (win.screen?.width ?? 2560) - 30 - win.width
    // The tray app's menu sits under the icon it belongs to; slot panels are right-aligned.
    readonly property real menuX: Math.max(12, Math.min(Dropdown.menuAnchorX - hostLeft - 24, win.width - 210 - 12))

    anchors {
        top: true
        right: true
    }
    margins.top: 33     // the pill spans y 4..34: a docked panel starts on its bottom hairline row and covers it
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

    Binding {
        target: Dropdown
        property: "docked"
        value: win.visible && win.dock
    }

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
        y: win.dock ? 0 : 7
        width: win.opened || win.dock ? win.panelWidth : 240
        height: win.opened ? content.implicitHeight + 2 : 0
        radius: win.opened ? 20 : 14
        // Docked: this is the hairline on the sides and bottom, the ink fill sits inside it.
        topLeftRadius: win.dock ? 0 : radius
        topRightRadius: win.dock ? 0 : radius
        bottomLeftRadius: win.dock ? 22 : radius
        bottomRightRadius: win.dock ? 22 : radius
        color: win.dock ? win.c.hairline : Qt.alpha(win.c.surface, 0.72)
        border.width: win.dock ? 0 : 1
        border.color: win.c.border
        clip: true
        opacity: win.opened || win.dock ? 1 : 0

        Behavior on width { Ease { duration: win.opened ? 520 : 340 } }
        Behavior on height { Ease { duration: win.opened ? 520 : 340 } }
        Behavior on radius { Ease { duration: win.opened ? 520 : 340 } }
        Behavior on opacity { NumberAnimation { duration: win.opened ? 200 : 160 } }

        Rectangle {
            visible: win.dock
            x: 1
            width: parent.width - 2
            height: parent.height - 1
            color: win.c.ink
            bottomLeftRadius: 21
            bottomRightRadius: 21
        }

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
