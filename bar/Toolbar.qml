import QtQuick

import "../theme"

// Right-hand capsule of the bar, the mirror of the CPU/RAM/GPU capsule. Items are added to the Row:
// notifications now; network, Bluetooth and power get their own specs.
Rectangle {
    id: toolbar

    implicitWidth: row.implicitWidth + 10
    implicitHeight: 28
    radius: 14

    color: Theme.imperial.surface
    border.width: 1
    border.color: Theme.imperial.border

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 2

        UsageChip {}
        NetworkButton {}
        BluetoothButton {}
        VolumeButton {}
        MicButton {}
        NotificationBell {}
        PowerButton {}
    }
}
