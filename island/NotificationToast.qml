import QtQuick

import "../components"
import "../services"
import "../theme"

// Content of the island while a notification pops up. Laid out at its final 360 px width and clipped by the
// growing card, so the text never reflows while the card animates. Prototype: prototypes/notifications/index.html
Item {
    id: toast

    readonly property var c: Theme.imperial

    // Last shown entry: kept while the card shrinks back, so the text does not blank out mid-animation.
    property var entry: null
    property bool hovered: false

    readonly property bool critical: entry?.critical ?? false
    readonly property int shownActions: entry ? entry.actions.length : 0
    // Compact: icon, title, one line of body. Hovered: header row, up to three body lines, the actions.
    readonly property real compactHeight: 58
    readonly property real expandedHeight: 22 + 17 + 20 + probe.implicitHeight + (shownActions > 0 ? 34 : 0)

    signal dismissed()

    width: 360
    height: hovered ? expandedHeight : compactHeight

    Connections {
        target: Notifications

        function onToastChanged() {
            if (Notifications.toast !== null)
                toast.entry = Notifications.toast
        }
    }

    // Sizes the hovered state: the body at its three-line limit.
    Text {
        id: probe

        visible: false
        width: 254
        text: toast.entry?.body ?? ""
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        maximumLineCount: 3
        font.family: Theme.fontFamily
        font.pixelSize: 12
        lineHeight: 16
        lineHeightMode: Text.FixedHeight
    }

    // Swap: when a new notification replaces this one, the content rises in.
    property real rise: 0
    onEntryChanged: riseAnim.restart()

    NumberAnimation {
        id: riseAnim

        target: toast
        property: "rise"
        from: 1
        to: 0
        duration: 460
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
    }

    Item {
        id: body

        anchors.fill: parent
        opacity: 1 - toast.rise
        transform: Translate { y: toast.rise * 8 }

        // A click on the body marks it read and closes the popup.
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: toast.dismissed()
        }

        AppTile {
            x: 18
            y: 15
            size: 28
            appIcon: toast.entry?.appIcon ?? ""
            desktopEntry: toast.entry?.desktopEntry ?? ""
            asset: toast.entry?.iconAsset ?? ""
            critical: toast.critical
        }

        Column {
            x: 58
            y: 11
            width: 254

            // Header: only while hovered.
            Item {
                width: parent.width
                height: toast.hovered ? 17 : 0
                opacity: toast.hovered ? 1 : 0
                clip: true

                Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 200 } }

                Text {
                    anchors.left: parent.left
                    anchors.right: time.left
                    anchors.rightMargin: 8
                    y: 1
                    text: (toast.critical ? "PRIORITY ALPHA" : "TRANSMISSION") + " · " + (toast.entry?.label ?? "")
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: toast.critical ? toast.c.dangerText : toast.c.muted
                    renderType: Text.CurveRendering
                    font.family: Theme.displayFont
                    font.pixelSize: 9
                    font.letterSpacing: 1.6
                    font.capitalization: Font.AllUppercase
                }

                Text {
                    id: time

                    anchors.right: parent.right
                    text: "NOW"
                    color: toast.critical ? toast.c.dangerText : toast.c.muted
                    renderType: Text.CurveRendering
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
            }

            Text {
                width: parent.width
                height: 20
                text: toast.entry?.summary ?? ""
                textFormat: Text.PlainText
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                color: toast.critical ? toast.c.dangerText : toast.c.text
                renderType: Text.CurveRendering
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.Medium
            }

            Text {
                width: parent.width
                text: toast.entry?.body ?? ""
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: toast.hovered ? 3 : 1
                color: toast.c.muted
                renderType: Text.CurveRendering
                font.family: Theme.fontFamily
                font.pixelSize: 12
                lineHeight: 16
                lineHeightMode: Text.FixedHeight
            }

            Row {
                visible: toast.hovered && toast.shownActions > 0
                opacity: toast.hovered ? 1 : 0
                topPadding: 8
                spacing: 4
                x: -10

                Behavior on opacity { NumberAnimation { duration: 200 } }

                Repeater {
                    model: toast.entry?.actions ?? []

                    delegate: ActionButton {
                        required property var modelData
                        required property int index

                        text: modelData.text
                        primary: index === 0
                        danger: index === 0 && toast.critical
                        onClicked: Notifications.invoke(toast.entry, index)
                    }
                }
            }
        }
    }

    // The popup's remaining life, drained along the bottom edge (Notifications.toastProgress).
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: parent.width * Notifications.toastProgress
        height: 1
        color: toast.critical ? toast.c.danger : toast.c.accent
        opacity: Notifications.toast !== null && !toast.critical ? 0.8 : 0
    }
}
