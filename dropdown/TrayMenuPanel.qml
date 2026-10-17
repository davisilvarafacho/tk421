import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import QtQuick

import "../bar/trayLogic.js" as Logic
import "../services"
import "../theme"

// An app's own menu (what it exports over D-Bus), styled like the other panels. Submenus open in place with a back row.
// Check and radio entries keep the menu open; everything else closes it.
Item {
    id: panel

    readonly property var c: Theme.imperial
    readonly property var item: Dropdown.menuItem

    // Submenus. One QsMenuOpener per level: an opener drops the entries of the menu it leaves, including the entry that
    // opened the next level, so a single opener cannot walk down a menu. h1..h3 are the entries opened at each level.
    property var h1: null
    property var h2: null
    property var h3: null
    property var titles: []
    readonly property int depth: titles.length
    readonly property string menuTitle: titles.length > 0 ? titles[titles.length - 1] : Tray.nameOf(item)

    function reset() {
        h1 = null
        h2 = null
        h3 = null
        titles = []
    }

    // The panel stays mounted while the window animates closed, and another app's menu reuses it: every opening, and
    // every change of app, starts from the top level. (Deferred: resetting inside the change handler loops the bindings.)
    Connections {
        target: Dropdown

        function onCurrentChanged() {
            if (Dropdown.current === "menu")
                Qt.callLater(panel.reset)
        }

        function onMenuItemChanged() {
            Qt.callLater(panel.reset)
        }
    }

    function push(entry, title) {
        if (depth >= 3)
            return
        if (depth === 0)
            h1 = entry
        else if (depth === 1)
            h2 = entry
        else
            h3 = entry
        titles = titles.concat([title])
    }

    function back() {
        if (depth === 0)
            return
        if (depth === 1)
            h1 = null
        else if (depth === 2)
            h2 = null
        else
            h3 = null
        titles = titles.slice(0, -1)
    }

    QsMenuOpener { id: op0; menu: panel.item?.menu ?? null }
    QsMenuOpener { id: op1; menu: panel.h1 }
    QsMenuOpener { id: op2; menu: panel.h2 }
    QsMenuOpener { id: op3; menu: panel.h3 }

    readonly property var opener: depth === 0 ? op0 : depth === 1 ? op1 : depth === 2 ? op2 : op3

    // [{ entry, separator, text }], cleaned and limited (an app can send hundreds of entries, or hostile text).
    readonly property var rows: {
        const values = opener.children?.values ?? []
        const raw = values.map(e => ({ entry: e, separator: e.isSeparator, text: Logic.cleanLabel(e.text, 60) }))
        return Logic.limitEntries(raw, 40)
    }

    readonly property real listHeight: Math.min(column.implicitHeight, 400)

    implicitHeight: 6 + header.height + listHeight + 8

    function trigger(row) {
        const e = row.entry
        if (!e || !e.enabled)
            return
        if (e.hasChildren) {
            push(e, row.text)
            return
        }
        e.triggered()
        if (e.buttonType === QsMenuButtonType.None)
            Dropdown.close()
    }

    // Tests and debugging without a pointer; exists only while this panel is loaded.
    IpcHandler {
        target: "traymenu"

        function rows(): string {
            return panel.menuTitle + " [depth " + panel.depth + "] " + panel.rows.map((r, i) => i + ":" + (r.separator ? "-" : r.text
                + (r.entry.hasChildren ? " >" : "") + (r.entry.checkState === Qt.Checked && r.entry.buttonType !== QsMenuButtonType.None ? " [x]" : "")
                + (r.entry.enabled ? "" : " (disabled)"))).join(" | ")
        }

        function click(index: int): void {
            const row = panel.rows[index]
            if (row)
                panel.trigger(row)
        }

        function back(): void {
            panel.back()
        }
    }

    Item {
        id: header

        y: 6
        width: parent.width
        height: 28

        Text {
            visible: panel.depth === 0
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 1
            width: parent.width - 32
            text: panel.menuTitle
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: panel.c.muted
            renderType: Text.CurveRendering
            font.family: Theme.displayFont
            font.pixelSize: 9
            font.letterSpacing: 1.8
            font.capitalization: Font.AllUppercase
        }

        // Back out of a submenu.
        Item {
            visible: panel.depth > 0
            anchors.fill: parent

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0.91, 0.9, 0.89, 0.035)
                opacity: backArea.containsMouse ? 1 : 0
            }

            Text {
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                text: ""      // Font Awesome chevron-left
                color: panel.c.muted
                renderType: Text.CurveRendering
                font.family: Theme.iconFont
                font.pixelSize: 10
            }

            Text {
                x: 36
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 1
                width: parent.width - 52
                text: panel.menuTitle
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: panel.c.muted
                renderType: Text.CurveRendering
                font.family: Theme.displayFont
                font.pixelSize: 9
                font.letterSpacing: 1.8
                font.capitalization: Font.AllUppercase
            }

            MouseArea {
                id: backArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: panel.back()
            }
        }
    }

    Flickable {
        y: 6 + header.height
        width: parent.width
        height: panel.listHeight
        contentHeight: column.implicitHeight
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: column

            width: parent.width

            Repeater {
                model: panel.rows

                delegate: Item {
                    id: row

                    required property var modelData

                    readonly property var entry: modelData.entry
                    readonly property bool separator: modelData.separator
                    readonly property bool enabledRow: entry?.enabled ?? false

                    width: column.width
                    height: separator ? 8 : 32

                    Rectangle {
                        visible: !row.separator
                        anchors.fill: parent
                        color: Qt.rgba(0.91, 0.9, 0.89, 0.035)
                        opacity: area.containsMouse && row.enabledRow ? 1 : 0
                    }

                    // Check mark (check boxes) or dot (radio buttons).
                    Text {
                        visible: !row.separator && (row.entry?.buttonType ?? 0) !== QsMenuButtonType.None
                            && row.entry?.checkState === Qt.Checked
                        x: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.entry?.buttonType === QsMenuButtonType.RadioButton ? "" : ""
                        color: panel.c.accent
                        renderType: Text.CurveRendering
                        font.family: Theme.iconFont
                        font.pixelSize: row.entry?.buttonType === QsMenuButtonType.RadioButton ? 7 : 11
                    }

                    Text {
                        visible: !row.separator
                        x: 38
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 38 - 36
                        text: row.modelData.text
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        opacity: row.enabledRow ? 1 : 0.4
                        color: panel.c.text
                        renderType: Text.CurveRendering
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                    }

                    // Submenu.
                    Text {
                        visible: !row.separator && (row.entry?.hasChildren ?? false)
                        x: parent.width - 16 - implicitWidth
                        anchors.verticalCenter: parent.verticalCenter
                        text: ""      // Font Awesome chevron-right
                        opacity: row.enabledRow ? 1 : 0.4
                        color: panel.c.muted
                        renderType: Text.CurveRendering
                        font.family: Theme.iconFont
                        font.pixelSize: 10
                    }

                    MouseArea {
                        id: area

                        anchors.fill: parent
                        enabled: !row.separator && row.enabledRow
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.trigger(row.modelData)
                    }
                }
            }
        }
    }
}
