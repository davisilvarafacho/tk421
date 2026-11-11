
import Quickshell
import QtQuick.Controls
import QtQuick

import "../components"
import "../services"
import "../theme"

PanelWindow {
    id: bar

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 38
    exclusiveZone: 38
    color: "transparent"

    SystemStats {
        id: stats
    }

    // Cápsula de monitoramento
    BarPill {
        id: resourcesCapsule

        anchors {
            left: parent.left
            top: parent.top
            leftMargin: 30
            topMargin: 4     // same top edge and height as the Dynamic Island pill
        }

        implicitWidth: resourcesRow.implicitWidth + 32

        // Hovering the capsule opens the resource panel (resources/ResourcePanel.qml).
        HoverHandler {
            onHoveredChanged: Resources.capsuleHovered = hovered
        }

        Row {
            id: resourcesRow

            anchors.centerIn: parent
            spacing: 12

            ResourceIndicator {
                label: "CPU"
                value: stats.cpuPercent
            }

            Rectangle {
                width: 1
                height: 12
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.imperial.border
            }

            ResourceIndicator {
                label: "GPU"
                value: stats.gpuPercent
            }

            Rectangle {
                width: 1
                height: 12
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.imperial.border
            }

            ResourceIndicator {
                label: "RAM"
                value: stats.ramPercent
            }
        }
    }

    // Cápsula de áreas de trabalho
    BarPill {
        id: workspacesCapsule

        anchors {
            left: resourcesCapsule.right
            top: parent.top
            leftMargin: 8
            topMargin: 4     // same top edge and height as the resources capsule
        }

        implicitWidth: workspaceIndicator.implicitWidth + 32

        WorkspaceIndicator {
            id: workspaceIndicator

            anchors.centerIn: parent
        }
    }

    // O relógio agora vive na Dynamic Island (island/Island.qml).
    

    // Toolbar capsule (right), the mirror of the resources pill: 30 px from the wall, like the dropdowns under it.
    Toolbar {
        id: toolbarCapsule

        anchors {
            right: parent.right
            top: parent.top
            rightMargin: 30
            topMargin: 4
        }
    }

    // Tray capsule: apps that keep an icon in the bar, left of the toolbar capsule (the Claude usage chip stays inside it).
    TrayCapsule {
        anchors {
            right: toolbarCapsule.left
            top: parent.top
            rightMargin: 8      // the gap between the left capsules
            topMargin: 4        // same top edge and height as the left capsules
        }
    }

    ControlPanel {
        id: controlPanel
        visible: false
    }

}
