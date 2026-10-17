import Quickshell
import Quickshell.Services.SystemTray
import QtQuick

import "../services"
import "../theme"

// The apps that do not fit in the capsule, plus the passive ones. Click activates, right-click opens the app's menu.
Item {
    id: panel

    readonly property var c: Theme.imperial

    implicitHeight: 48 + Math.max(column.implicitHeight, 36) + 8

    Text {
        id: title

        x: 16
        y: 2 + (46 - height) / 2
        text: "Tray"
        color: panel.c.text
        renderType: Text.CurveRendering
        font.family: Theme.displayFont
        font.pixelSize: 11
        font.letterSpacing: 2.2
        font.capitalization: Font.AllUppercase
    }

    Text {
        x: title.x + title.implicitWidth + 8
        y: title.y
        height: title.height
        verticalAlignment: Text.AlignVCenter
        text: Tray.overflowItems.length > 0 ? Tray.overflowItems.length + " hidden" : ""
        color: panel.c.muted
        renderType: Text.CurveRendering
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }

    Text {
        visible: Tray.overflowItems.length === 0
        x: 16
        y: 48 + 8
        text: "Nothing hidden."
        color: panel.c.muted
        renderType: Text.CurveRendering
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }

    Column {
        id: column

        y: 48
        width: parent.width

        Repeater {
            model: ScriptModel {
                values: Tray.overflowItems
            }

            delegate: Item {
                id: row

                required property var modelData

                readonly property var item: modelData
                readonly property bool attention: item?.status === Status.NeedsAttention

                width: column.width
                height: 40

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0.91, 0.9, 0.89, 0.035)
                    opacity: area.containsMouse ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: 120 }
                    }
                }

                Image {
                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    height: 18
                    source: row.item?.icon ?? ""
                    sourceSize: Qt.size(36, 36)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }

                Column {
                    x: 46
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 46 - 56

                    Row {
                        spacing: 6

                        Rectangle {
                            visible: row.attention
                            anchors.verticalCenter: parent.verticalCenter
                            width: 5
                            height: 5
                            radius: 2.5
                            color: panel.c.accent
                        }

                        Text {
                            text: Tray.nameOf(row.item)
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, 150)
                            color: panel.c.text
                            renderType: Text.CurveRendering
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }
                    }

                    Text {
                        text: row.item ? Tray.statusText(row.item) : ""
                        color: panel.c.muted
                        renderType: Text.CurveRendering
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }

                Text {
                    x: parent.width - 16 - implicitWidth
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 1
                    text: "Open"
                    color: panel.c.muted
                    opacity: area.containsMouse ? 1 : 0
                    renderType: Text.CurveRendering
                    font.family: Theme.displayFont
                    font.pixelSize: 9
                    font.letterSpacing: 1.4
                    font.capitalization: Font.AllUppercase

                    Behavior on opacity {
                        NumberAnimation { duration: 140 }
                    }
                }

                MouseArea {
                    id: area

                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor

                    onClicked: mouse => {
                        if (!row.item)
                            return
                        if (mouse.button === Qt.RightButton && row.item.hasMenu) {
                            Dropdown.openMenu(row.item, 1e6)      // far right: the menu clamps against the window edge
                        } else {
                            Tray.activateItem(row.item)
                            Dropdown.close()
                        }
                    }
                }
            }
        }
    }
}
