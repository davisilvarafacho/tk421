import QtQuick

import "../components"
import "../services"

// Right-hand capsule of the bar, the mirror of the CPU/RAM/GPU capsule. Items are added to the Row:
// notifications now; network, Bluetooth and power get their own specs.
BarPill {
    id: toolbar

    // Same pill as the tray. The usage chip pads its spark 8 px inside its hover cell (icon cells pad ~5), so the left
    // side gets 8 px instead of 11: every pill keeps ~16 px between its edge and the first and last glyph.
    implicitWidth: 8 + row.implicitWidth + 11

    // The comms log, the toolbar dropdowns and the Claude usage card grow out of this pill: same width, and the pill's
    // bottom corners square off while one of them hangs from it.
    readonly property bool docked: Notifications.docked || Dropdown.docked || ClaudeUsage.docked

    bottomLeftRadius: docked ? 0 : height / 2
    bottomRightRadius: docked ? 0 : height / 2
    onWidthChanged: Notifications.dockWidth = width
    Component.onCompleted: Notifications.dockWidth = width

    Behavior on bottomLeftRadius { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    Behavior on bottomRightRadius { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    Row {
        id: row

        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        UsageChip {}
        KeyboardButton {}
        NetworkButton {}
        BluetoothButton {}
        VolumeButton {}
        MicButton {}
        NotificationBell {}
        PowerButton {}
    }
}
