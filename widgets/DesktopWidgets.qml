import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

import "../services"
import "logic.js" as Logic

// Desktop widgets: two 400 px columns on the flanks of the screen, the centre left to the wallpaper.
// Left: clock, systems, Claude plan. Right: agenda, now playing, audio (cava spectrum), comms.
// btop and lavat are Ghostty windows beside them (widgets/terminals.lua and the tk421-widget-* rules in hyprland.lua).
// They only show on one workspace (`workspace`, 6 for now) and sit on the Bottom layer, under every window.
// Everything is click-through except the media transport buttons.
// Prototype: prototypes/widgets/index.html
Scope {
    id: root

    readonly property int workspace: 6
    readonly property bool shown: (Hyprland.focusedMonitor?.activeWorkspace?.id ?? -1) === workspace

    property double now: Date.now()
    property string uptime: ""
    property string disk: "—"

    // Keep the detail sample (temperatures, clock, busiest process) running while the widgets show.
    Binding {
        target: Resources
        property: "watched"
        value: root.shown
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.shown
        triggeredOnStart: true
        onTriggered: root.now = Date.now()
    }

    Timer {
        interval: 60000
        repeat: true
        running: root.shown
        triggeredOnStart: true
        onTriggered: {
            uptimeFile.reload()
            if (!df.running)
                df.running = true
        }
    }

    FileView {
        id: uptimeFile

        path: "/proc/uptime"
        onLoaded: root.uptime = Logic.uptime(Number(text().split(" ")[0]))
    }

    Process {
        id: df

        command: ["df", "-B1", "--output=used,size", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const d = Logic.parseDf(text)
                if (d)
                    root.disk = Logic.gbPair(d.used, d.size)
            }
        }
    }

    component Column400: PanelWindow {
        id: col

        property bool shown: false
        default property alias content: layout.data

        anchors {
            top: true
            bottom: true
        }
        margins.top: 68
        margins.bottom: 30
        implicitWidth: 400
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        visible: shown || layout.opacity > 0.01

        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "tk421-widgets"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        ColumnLayout {
            id: layout

            anchors.fill: parent
            spacing: 12
            opacity: col.shown ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: col.shown ? 260 : 160 } }
        }
    }

    Column400 {
        anchors.left: true
        margins.left: 30
        shown: root.shown
        mask: Region {}

        ClockWidget {
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            now: root.now
        }

        SystemsWidget {
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            uptime: root.uptime
            disk: root.disk
        }

        Item { Layout.fillHeight: true }

        UsageWidget {
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            now: root.now
        }
    }

    Column400 {
        anchors.right: true
        margins.right: 30
        shown: root.shown
        mask: Region { item: media.visible ? media.controls : null }

        AgendaWidget {
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            now: root.now
        }

        MediaWidget {
            id: media

            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            visible: Media.present
        }

        AudioWidget {
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            running: root.shown
        }

        Item { Layout.fillHeight: true }

        CommsWidget {
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            now: root.now
        }
    }
}
