
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

    implicitHeight: 32
    exclusiveZone: 32
    color: "transparent"

    SystemStats {
        id: stats
    }

    // Cápsula de monitoramento
    Rectangle {
        id: resourcesCapsule

        anchors {
            left: parent.left
            top: parent.top
            leftMargin: 30
            topMargin: 4     // same top edge and height as the Dynamic Island pill
        }

        implicitWidth: resourcesRow.implicitWidth + 24
        implicitHeight: 28
        radius: 14

        color: Theme.imperial.surface
        border.width: 1
        border.color: Theme.imperial.border

        // Hovering the capsule opens the resource panel (resources/ResourcePanel.qml).
        HoverHandler {
            onHoveredChanged: Resources.capsuleHovered = hovered
        }

        Row {
            id: resourcesRow

            anchors.centerIn: parent
            spacing: 10

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
    Rectangle {
        id: workspacesCapsule

        anchors {
            left: resourcesCapsule.right
            top: parent.top
            leftMargin: 8
            topMargin: 4     // same top edge and height as the resources capsule
        }

        implicitWidth: workspaceIndicator.implicitWidth + 24
        implicitHeight: 28
        radius: 14

        color: Theme.imperial.surface
        border.width: 1
        border.color: Theme.imperial.border

        WorkspaceIndicator {
            id: workspaceIndicator

            anchors.centerIn: parent
        }
    }

    // O relógio agora vive na Dynamic Island (island/Island.qml).
    

    // Toolbar capsule (right). Notifications first; network, Bluetooth and power join it later.
    Toolbar {
        id: toolbarCapsule

        anchors {
            right: parent.right
            top: parent.top
            rightMargin: 30
            topMargin: 4     // same top edge and height as the left capsules
        }
    }

    // Tray capsule: apps that keep an icon in the bar, left of the toolbar capsule (the Claude usage chip stays inside it).
    TrayCapsule {
        anchors {
            right: toolbarCapsule.left
            top: parent.top
            rightMargin: 8
            topMargin: 4     // same top edge and height as the other capsules
        }
    }

    ControlPanel {
        id: controlPanel
        visible: false
    }

}
