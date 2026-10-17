import QtQuick
import Quickshell.Hyprland

import "../theme"

Row {
    id: indicator

    readonly property int slots: 4
    readonly property var workspace: Hyprland.focusedWorkspace
    readonly property int activeId: workspace ? workspace.id : 0
    // A special workspace (e.g. "magic") floats above the regular one, so the
    // focused workspace stays the regular one; read it from the monitor instead.
    readonly property var monitorState: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.lastIpcObject : null
    readonly property bool isSpecial: monitorState && monitorState.specialWorkspace
        ? monitorState.specialWorkspace.name !== "" : false
    readonly property bool overflow: isSpecial || activeId > slots

    spacing: 8
    height: 22

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "activespecial" || event.name === "activespecialv2")
                Hyprland.refreshMonitors();
        }
    }

    Repeater {
        model: indicator.slots

        delegate: WorkspaceLabel {
            required property int index

            text: String(index + 1)
            active: !indicator.isSpecial && indicator.activeId === index + 1
        }
    }

    // Fifth slot: only shown while the active workspace is outside 1–4.
    WorkspaceLabel {
        visible: indicator.overflow
        text: indicator.isSpecial ? "S" : String(indicator.activeId)
        active: true
    }

    component WorkspaceLabel: Item {
        id: label

        property string text: ""
        property bool active: false

        width: labelText.implicitWidth
        height: indicator.height

        Text {
            id: labelText

            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 1      // Orbitron's digits sit ~1px high at this size
            text: label.text
            color: Theme.imperial.text      // same white as the resource values; the underline marks the active one
            renderType: Text.CurveRendering
            font.family: Theme.displayFont
            font.pixelSize: 12
            font.weight: Font.Black
            font.letterSpacing: 0.4
        }

        Rectangle {
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: 2
            }
            width: labelText.implicitWidth
            height: 1
            color: Theme.imperial.accent
            opacity: label.active ? 1 : 0

            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }
        }
    }
}
