import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

import "../services"

// Session lock. Trigger: `quickshell ipc call lock lock`.
// Dev preview (no real lock, password "preview"): `quickshell ipc call lock preview`.
// Both first screenshot every output (lock/capture.lua), so the lock screen shows the desktop as it was, dimmed and lightly blurred.
Scope {
    id: root

    readonly property string shotDir: Quickshell.env("XDG_RUNTIME_DIR") + "/tk421-lock"
    property string pending: ""         // "lock" | "preview": what to do once the screenshots are taken

    function capture(then) {
        if (pending !== "")
            return
        pending = then
        shotTimeout.restart()
        shots.running = true
    }

    // Runs when the screenshots are done, failed or timed out: the lock itself never depends on them.
    function finishCapture() {
        shotTimeout.stop()
        const then = pending
        pending = ""
        if (then === "lock")
            sessionLock.locked = true
        else if (then === "preview")
            previewWindow.visible = true
    }

    // The screenshots hold the desktop's contents: they only live while the lock does.
    function cleanup() {
        Quickshell.execDetached(["rm", "-rf", shotDir])
    }

    Process {
        id: shots

        command: ["lua", Quickshell.shellPath("lock/capture.lua"), root.shotDir].concat(Quickshell.screens.map(s => s.name))
        onExited: root.finishCapture()
    }

    Timer {
        id: shotTimeout
        interval: 3000
        onTriggered: {
            root.finishCapture()
            shots.running = false
        }
    }

    // Not named "session": inside the lock surface component that name collides with
    // LockSurface's own `session` property and the binding resolved to undefined.
    LockSession {
        id: authSession
    }

    LockSession {
        id: previewSession
        mock: true
    }

    WlSessionLock {
        id: sessionLock

        onLockedChanged: {
            if (locked)
                authSession.reset()
            else
                root.cleanup()
        }

        WlSessionLockSurface {
            id: lockWindow

            LockSurface {
                anchors.fill: parent
                session: authSession
                screenName: lockWindow.screen?.name ?? ""
                onFinished: sessionLock.locked = false
            }
        }
    }

    // Full-screen overlay that looks like the lock but locks nothing. Esc closes it.
    PanelWindow {
        id: previewWindow

        visible: false
        color: "#050505"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        WlrLayershell.namespace: "tk421-lock-preview"

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        onVisibleChanged: {
            Media.mock = visible && Media.player === null
            if (visible)
                previewSession.reset()
            else
                root.cleanup()
        }

        Shortcut {
            sequence: "Escape"
            onActivated: previewWindow.visible = false
        }

        Loader {
            anchors.fill: parent
            active: previewWindow.visible

            sourceComponent: LockSurface {
                session: previewSession
                screenName: previewWindow.screen?.name ?? ""
                onFinished: previewWindow.visible = false
            }
        }
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            if (!sessionLock.locked)
                root.capture("lock")
        }

        function isLocked(): bool {
            return sessionLock.locked
        }

        function preview(): void {
            if (previewWindow.visible)
                previewWindow.visible = false
            else
                root.capture("preview")
        }
    }
}
