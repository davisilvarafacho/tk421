
import QtQuick

Rectangle {
    id: clock

    property string timeFormat: "HH:mm:ss"
    property string currentTime:
        Qt.formatDateTime(new Date(), timeFormat)

    implicitWidth: 82
    implicitHeight: 22
    radius: 11

    color: "#CC111418"

    border.width: 1
    border.color: "#39414D"

    Text {
        anchors.centerIn: parent

        text: clock.currentTime
        color: "#E8E6E3"

        font.family: "Geist"
        font.pixelSize: 10
        font.weight: Font.DemiBold
        font.letterSpacing: 0.5
    }

    Timer {
        interval: 1000
        repeat: true
        running: true

        onTriggered: {
            clock.currentTime =
                Qt.formatDateTime(new Date(), clock.timeFormat)
        }
    }
}
