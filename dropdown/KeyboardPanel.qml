import QtQuick

import "../components"
import "../services"
import "../theme"

// Keyboard dropdown: the Basike Ba-KEY391 drawn as isometric hairlines, lit the way the keyboard is lit, and the controls
// the keyboard really has. The projection and the face technique come from iso-glow (MIT, April Zhu), itself based on
// iso-figure (MIT, Tolga Cohce). Every change goes through services/Keyboard.qml. Prototype: prototypes/keyboard/index.html.
// It hangs from the toolbar pill in the comms log language: Orbitron only for the title, Geist sentence case, chip-filled
// selects and segmented controls, monochrome levels.
Item {
    id: panel

    readonly property var c: Theme.imperial
    readonly property bool isOpen: Dropdown.current === "keyboard"

    // Drawing colours (graphite, as in the prototype). The light of the keyboard comes from the effects, not from here.
    readonly property string bodyColor: "#111115"
    readonly property string deckColor: "#16161b"
    readonly property string lineColor: "#5d5c64"
    readonly property string detailColor: "#2a2a31"
    readonly property string recessColor: "#0a0a0d"
    readonly property string keySideColor: "#0d0d10"
    readonly property string screenColor: "#05070b"

    // The keyboard's effects: hw id, name, lighting family, has speed, has colour (ba-key391/led_catalog.json).
    readonly property var effects: [
        [1, "Fixed", "static", false, true], [2, "Rainbow", "hueWave", true, true], [3, "Respire", "breathe", true, false],
        [4, "Game mode", "perkey", true, true], [5, "Windmill", "spin", true, true], [6, "Sine wave", "wave", true, true],
        [7, "Off", "off", true, true], [8, "Waterfall", "waterfall", true, true], [9, "Storm", "spin", true, true],
        [10, "Raindrops", "rain", true, true], [11, "Ripples", "ripple", true, true], [12, "Blossoming", "bloom", true, true],
        [13, "Reaction", "reaction", true, true], [14, "Stars", "twinkle", true, true], [15, "Effect 28", "wave", true, false],
        [16, "Effect 30", "hueWave", true, false], [17, "Scanning", "scan", true, false], [18, "Effect 29", "waterfall", true, true]
    ]
    readonly property var colorNames: ["red", "green", "blue", "yellow", "purple", "cyan", "white", "rainbow"]
    readonly property var colorRgb: [[255, 45, 45], [45, 255, 90], [45, 91, 255], [255, 224, 45], [176, 45, 255], [45, 224, 255], [255, 255, 255]]
    readonly property var sideModes: ["OFF", "RAINBOW", "CYCLE", "WHITE", "PULSE"]
    readonly property var effectOptions: effects.map(e => e[1])

    // Geometry in the prototype's units: the keyboard is kbW x kbD, kbBase thick, keys kbKeyH high.
    readonly property real kbW: 372
    readonly property real kbD: 106
    readonly property real kbBase: 10
    readonly property real kbKeyH: 5
    readonly property real cosA: Math.cos(Math.PI / 6)
    readonly property real sinA: 0.5
    readonly property var keyList: buildKeys()
    readonly property var keyPos: keyList.map(k => [(k[0] + k[2] / 2) / kbW, (k[1] + k[3] / 2) / kbD])
    readonly property var wasdKeys: keyList.map((k, i) => (k[1] >= 28 && k[1] <= 62 && k[0] >= 46 && k[0] <= 96) ? i : -1).filter(i => i >= 0)

    // Set by fit() on every paint: scale and offset of the projection into the canvas.
    property real fitScale: 1
    property real fitX: 0
    property real fitY: 0
    property real animT: 0

    width: parent.width
    implicitHeight: column.y + column.implicitHeight + 16

    function buildKeys() {
        const k = []
        for (let c = 0; c < 15; c++)
            k.push([12 + c * 17, 12, 15, 11])                                              // function row
        for (let r = 0; r < 3; r++)
            for (let c = 0; c < 15; c++)
                k.push([12 + c * 17, 28 + r * 17, 15, 14])                                 // main block
        const bottom = [[12, 22], [36, 22], [60, 22], [84, 96], [184, 18], [204, 18], [224, 18]]
        bottom.forEach(b => k.push([b[0], 79, b[1], 14]))                                  // bottom row
        for (let r = 0; r < 4; r++)
            for (let c = 0; c < 4; c++)
                k.push([284 + c * 17, 28 + r * 17, 15, 14])                                // numpad
        return k.sort((a, b) => (a[0] + a[1]) - (b[0] + b[1]))                             // back to front
    }

    function effectIndex(hw) {
        for (let i = 0; i < effects.length; i++)
            if (effects[i][0] === hw)
                return i
        return -1
    }

    function effectInfo(hw) {
        for (let i = 0; i < effects.length; i++)
            if (effects[i][0] === hw)
                return effects[i]
        return [hw, "Effect " + hw, "static", false, false]
    }

    function fit(cw) {
        const pts = [[0, 0, 0], [kbW, 0, 0], [0, kbD, 0], [kbW, kbD, 0], [kbW, 0, kbBase + kbKeyH + 6]]
        let x0 = 1e9, x1 = -1e9, y0 = 1e9, y1 = -1e9
        for (const p of pts) {
            const x = (p[0] - p[1]) * cosA, y = (p[0] + p[1]) * sinA - p[2]
            x0 = Math.min(x0, x); x1 = Math.max(x1, x)
            y0 = Math.min(y0, y); y1 = Math.max(y1, y)
        }
        const m = 4
        fitScale = (cw - 2 * m) / (x1 - x0)
        fitX = m - x0 * fitScale
        fitY = (cw / 1.6 - (y1 - y0) * fitScale) / 2 - y0 * fitScale
    }

    function px(x, y, z) {
        return [(x - y) * cosA * fitScale + fitX, ((x + y) * sinA - z) * fitScale + fitY]
    }

    function path(ctx, pts) {
        ctx.beginPath()
        for (let i = 0; i < pts.length; i++) {
            const q = px(pts[i][0], pts[i][1], pts[i][2])
            if (i === 0)
                ctx.moveTo(q[0], q[1])
            else
                ctx.lineTo(q[0], q[1])
        }
        ctx.closePath()
    }

    function paintPath(ctx, pts, fill, stroke) {
        path(ctx, pts)
        if (fill !== "") {
            ctx.fillStyle = fill
            ctx.fill()
        }
        if (stroke !== "") {
            ctx.strokeStyle = stroke
            ctx.stroke()
        }
    }

    function circlePath(ctx, cx, cy, r, z) {
        const pts = []
        for (let i = 0; i < 32; i++) {
            const a = i / 32 * 2 * Math.PI
            pts.push([cx + r * Math.cos(a), cy + r * Math.sin(a), z])
        }
        path(ctx, pts)
    }

    function hueRgb(h) {
        const a = ((h % 360) + 360) % 360 / 60, f = a - Math.floor(a), q = 1 - f, i = Math.floor(a) % 6
        const rgb = [[1, f, 0], [q, 1, 0], [0, 1, f], [0, q, 1], [f, 0, 1], [1, 0, q]][i]
        return rgb.map(v => Math.round(40 + v * 215))
    }

    function mixRgb(a, b, t) {
        const k = Math.max(0, Math.min(1, t))
        return a.map((v, i) => Math.round(v + (b[i] - v) * k))
    }

    function css(rgb, alpha) {
        return alpha === undefined ? "rgb(" + rgb.join(",") + ")" : "rgba(" + rgb.join(",") + "," + alpha.toFixed(3) + ")"
    }

    function hash(i) {
        const s = Math.sin(i * 127.1 + 311.7) * 43758.5453
        return s - Math.floor(s)
    }

    // Side glow colour at a point along the two visible walls (0..1).
    function sideRgb(mode, along, t) {
        if (mode === 1)
            return hueRgb(along * 360 + t * 90)
        if (mode === 2)
            return hueRgb(t * 40)
        return [255, 255, 255]
    }

    // Amplitude 0..1 and hue of key i for a lighting family; a null hue means "the chosen colour".
    function sample(family, i, t, sp) {
        const nx = keyPos[i][0], ny = keyPos[i][1]
        switch (family) {
        case "off": return [0, null]
        case "static": return [1, null]
        case "breathe": return [0.12 + 0.88 * (0.5 + 0.5 * Math.sin(t * 1.6 * sp)), (t * 25) % 360]
        case "hueWave": return [1, (nx * 360 + t * 70 * sp) % 360]
        case "wave": return [0.5 + 0.5 * Math.sin(nx * 7 - t * 2.4 * sp), null]
        case "waterfall": return [1, (ny * 200 + nx * 60 + t * 90 * sp) % 360]
        case "spin": return [1, (Math.atan2(ny - 0.5, nx - 0.5) * 57.3 + t * 100 * sp) % 360]
        case "rain": { const p = (t * 0.55 * sp + hash(i)) % 1; return [Math.max(0.05, 1 - p * 3.2), null] }
        case "ripple": { const d = Math.hypot((nx - 0.5) * 1.8, ny - 0.5); return [Math.max(0.08, Math.sin(d * 16 - t * 4 * sp)), null] }
        case "bloom": { const d = Math.hypot((nx - 0.5) * 1.8, ny - 0.5); return [Math.sin(t * 2 * sp - d * 9) > 0.15 ? 1 : 0.2, (d * 300 + t * 40) % 360] }
        case "reaction": { const p = (t * 0.9 * sp + hash(i) * 7) % 7; return [p < 0.9 ? 1 - p / 0.9 * 0.85 : 0.1, null] }
        case "twinkle": return [0.08 + 0.92 * Math.pow(Math.max(0, Math.sin(t * 1.6 * sp + hash(i) * 40)), 8), null]
        case "scan": { const pos = (t * 0.35 * sp) % 1.5 - 0.25; return [Math.max(0.06, 1 - Math.abs(nx - pos) * 7), null] }
        case "perkey": return [wasdKeys.indexOf(i) >= 0 ? 1 : 0.07, null]
        }
        return [1, null]
    }

    function drawKeyboard(ctx) {
        const t = animT
        const info = effectInfo(Keyboard.effect)
        const family = info[2]
        const sp = Keyboard.effectHasSpeed ? 0.35 + Keyboard.speed * 0.4 : 0.8
        const bri = Keyboard.bright / 6
        const chosen = Keyboard.color < 7 ? colorRgb[Keyboard.color] : null
        const n = keyList.length
        const amp = [], rgb = []
        for (let i = 0; i < n; i++) {
            const s = sample(family, i, t, sp)
            let c
            if (Keyboard.effectHasColor && chosen)
                c = chosen
            else if (s[1] !== null)
                c = hueRgb(s[1])
            else
                c = hueRgb(t * 50 * sp + keyPos[i][0] * 360)
            amp.push(s[0] * bri)
            rgb.push(c)
        }

        ctx.lineWidth = 1
        ctx.lineCap = "round"

        // the box
        paintPath(ctx, [[0, 0, kbBase], [kbW, 0, kbBase], [kbW, kbD, kbBase], [0, kbD, kbBase]], deckColor, lineColor)
        paintPath(ctx, [[0, kbD, 0], [kbW, kbD, 0], [kbW, kbD, kbBase], [0, kbD, kbBase]], bodyColor, lineColor)
        paintPath(ctx, [[kbW, 0, 0], [kbW, kbD, 0], [kbW, kbD, kbBase], [kbW, 0, kbBase]], bodyColor, lineColor)
        paintPath(ctx, [[5, 5, kbBase], [kbW - 5, 5, kbBase], [kbW - 5, kbD - 5, kbBase], [5, kbD - 5, kbBase]], "", detailColor)

        // the side glow along the two visible walls, a wide soft stroke under a thin core
        const m = Keyboard.sideMode, lvl = Keyboard.sideLevel / 4, zs = 6
        const fStart = px(0, kbD, zs), fEnd = px(kbW, kbD, zs), sEnd = px(kbW, 0, zs)
        if (m === 0) {
            ctx.lineWidth = 1
            ctx.strokeStyle = detailColor
            ctx.beginPath(); ctx.moveTo(fStart[0], fStart[1]); ctx.lineTo(fEnd[0], fEnd[1]); ctx.lineTo(sEnd[0], sEnd[1]); ctx.stroke()
        } else {
            const pulse = m === 4 ? ((0.5 + 0.5 * Math.sin(t * 6)) > 0.5 ? 1 : 0.08) : 1
            const total = kbW + kbD
            const edges = [[fStart, fEnd, 0, kbW / total], [fEnd, sEnd, kbW / total, 1]]
            for (const e of edges) {
                const g = ctx.createLinearGradient(e[0][0], e[0][1], e[1][0], e[1][1])
                for (let s = 0; s <= 8; s++) {
                    const along = e[2] + (e[3] - e[2]) * s / 8
                    g.addColorStop(s / 8, css(sideRgb(m, along, t)))
                }
                ctx.strokeStyle = g
                ctx.beginPath(); ctx.moveTo(e[0][0], e[0][1]); ctx.lineTo(e[1][0], e[1][1])
                ctx.lineWidth = 7; ctx.globalAlpha = 0.22 * lvl * pulse; ctx.stroke()
                ctx.lineWidth = 2; ctx.globalAlpha = 0.15 + 0.85 * lvl * pulse; ctx.stroke()
            }
            ctx.globalAlpha = 1
        }

        // light spilling under each lit key, then the keys themselves, back to front
        for (let i = 0; i < n; i++) {
            if (amp[i] < 0.05)
                continue
            const k = keyList[i], top = kbBase + kbKeyH
            paintPath(ctx, [[k[0] - 1.5, k[1] - 1.5, top], [k[0] + k[2] + 1.5, k[1] - 1.5, top],
                            [k[0] + k[2] + 1.5, k[1] + k[3] + 1.5, top], [k[0] - 1.5, k[1] + k[3] + 1.5, top]],
                      css(rgb[i], amp[i] * 0.28), "")
        }
        for (let i = 0; i < n; i++) {
            const k = keyList[i], x = k[0], y = k[1], w = k[2], d = k[3], z0 = kbBase, z1 = kbBase + kbKeyH
            paintPath(ctx, [[x, y + d, z0], [x + w, y + d, z0], [x + w, y + d, z1], [x, y + d, z1]], keySideColor, lineColor)
            paintPath(ctx, [[x + w, y, z0], [x + w, y + d, z0], [x + w, y + d, z1], [x + w, y, z1]], keySideColor, lineColor)
            paintPath(ctx, [[x, y, z1], [x + w, y, z1], [x + w, y + d, z1], [x, y + d, z1]],
                      css(mixRgb([23, 23, 28], rgb[i], amp[i] * 0.95)), lineColor)
        }

        // the knob: a ring that follows the side glow, and the cap
        const ring = m === 0 ? detailColor : css(sideRgb(m, 0.5, t), 0.35 + 0.65 * lvl)
        circlePath(ctx, 359, 16, 10.5, kbBase)
        ctx.strokeStyle = ring; ctx.lineWidth = 2; ctx.stroke()
        if (m !== 0) {
            ctx.globalAlpha = 0.25 * lvl
            ctx.lineWidth = 5; ctx.stroke()
            ctx.globalAlpha = 1
        }
        circlePath(ctx, 359, 16, 8, kbBase + 3)
        ctx.fillStyle = deckColor; ctx.fill()
        ctx.strokeStyle = detailColor; ctx.lineWidth = 1; ctx.stroke()

        // the screen: the recess, then its content drawn on the top plane
        paintPath(ctx, [[286, 7, kbBase], [344, 7, kbBase], [344, 26, kbBase], [286, 26, kbBase]], recessColor, lineColor)
        const o = px(288, 9, kbBase)
        ctx.save()
        ctx.setTransform(cosA * fitScale, sinA * fitScale, -cosA * fitScale, sinA * fitScale, o[0], o[1])
        ctx.fillStyle = screenColor
        ctx.fillRect(0, 0, 54, 15)
        if (Keyboard.boot === 2) {
            for (let b = 0; b < 9; b++) {
                const h = 3 + 9 * Math.abs(Math.sin(t * 2.2 + b * 0.7))
                ctx.fillStyle = css(hueRgb(200 + b * 14 + t * 30))
                ctx.fillRect(3 + b * 5.6, 14 - h, 4, h)
            }
        } else {
            ctx.fillStyle = "#b5bac3"
            ctx.font = "8px Orbitron"
            ctx.textAlign = "center"
            ctx.fillText("12:41", 27, 10.2)
        }
        ctx.restore()
    }

    // A section label (comms log language: plain, faint, no rule).
    component Section: Item {
        id: section

        property string label: ""

        width: column.width
        height: 22

        Text {
            anchors.bottom: parent.bottom
            text: section.label
            color: Theme.imperial.faint
            renderType: Text.CurveRendering
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }
    }

    // A labelled row. Its children sit to the right of the label; the row grows when a child opens a list.
    component Setting: Item {
        id: setting

        property string label: ""
        property bool disabled: false

        width: column.width
        height: Math.max(28, childrenRect.height)
        // Every control writes to the keyboard: with it offline nothing here can act.
        enabled: !disabled && Keyboard.online
        opacity: disabled || !Keyboard.online ? 0.35 : 1

        Text {
            width: 84
            height: 28
            verticalAlignment: Text.AlignVCenter
            text: setting.label
            color: Theme.imperial.muted
            elide: Text.ElideRight
            renderType: Text.CurveRendering
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }
    }

    // A select: click the header to open the list, the mouse wheel over it steps through the options (down = next).
    component Select: Item {
        id: select

        property var options: []
        property int current: -1
        property string placeholder: ""
        property bool disabled: false
        property bool expanded: false

        signal picked(int index)

        function step(delta) {
            if (options.length === 0)
                return
            const base = current < 0 ? (delta > 0 ? -1 : options.length) : current
            const next = Math.max(0, Math.min(options.length - 1, base + delta))
            if (next !== current)
                picked(next)
        }

        height: header.height + (expanded ? listBox.height + 4 : 0)

        Rectangle {
            id: header

            width: select.width
            height: 28
            radius: 8
            color: headerArea.containsMouse || select.expanded ? "#24242C" : Theme.imperial.surfaceAlt
            opacity: select.disabled ? 0.35 : 1

            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                x: 10
                width: parent.width - 36
                anchors.verticalCenter: parent.verticalCenter
                text: select.current >= 0 ? select.options[select.current] : select.placeholder
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: select.current >= 0 ? Theme.imperial.text : Theme.imperial.muted
                renderType: Text.CurveRendering
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }

            Icon {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                name: "expand_more"
                rotation: select.expanded ? 180 : 0
                color: Theme.imperial.muted
                size: Theme.iconSize.panel

                Behavior on rotation { NumberAnimation { duration: 140 } }
            }

            MouseArea {
                id: headerArea

                anchors.fill: parent
                hoverEnabled: true
                enabled: !select.disabled
                cursorShape: Qt.PointingHandCursor
                onClicked: select.expanded = !select.expanded
                onWheel: wheel => select.step(wheel.angleDelta.y < 0 ? 1 : -1)
            }
        }

        Rectangle {
            id: listBox

            y: header.height + 4
            width: select.width
            height: Math.min(list.contentHeight + 8, 164)
            visible: select.expanded
            radius: 10
            color: "#0D0D10"
            clip: true

            ListView {
                id: list

                anchors.fill: parent
                anchors.margins: 4
                model: select.options
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                currentIndex: select.current
                onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)

                delegate: Rectangle {
                    id: row

                    required property int index
                    required property string modelData

                    readonly property bool chosen: row.index === select.current

                    width: list.width
                    height: 26
                    radius: 7
                    color: rowArea.containsMouse ? Theme.imperial.surfaceAlt : "transparent"

                    Text {
                        x: 8
                        width: parent.width - 36
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: row.chosen || rowArea.containsMouse ? Theme.imperial.text : Theme.imperial.muted
                        renderType: Text.CurveRendering
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: row.chosen ? Font.Medium : Font.Normal
                    }

                    Icon {
                        visible: row.chosen
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        name: "check"
                        color: Theme.imperial.text
                        size: Theme.iconSize.panel
                    }

                    MouseArea {
                        id: rowArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            select.expanded = false
                            select.picked(row.index)
                        }
                        onWheel: wheel => select.step(wheel.angleDelta.y < 0 ? 1 : -1)
                    }
                }
            }
        }
    }

    // `steps`: a segmented level bar, filled up to the value (white, like the volume sliders).
    // Otherwise: a segmented choice, the chosen segment carries the chip fill.
    component Cells: Row {
        id: cells

        property int count: 0
        property var labels: []
        property int value: 0
        property bool steps: false
        property bool disabled: false

        signal picked(int index)

        height: 28
        spacing: cells.steps ? 3 : 2

        Repeater {
            model: cells.count

            delegate: Item {
                id: cell

                required property int index

                readonly property bool lit: cells.steps ? cell.index <= cells.value : cell.index === cells.value

                width: (cells.width - cells.spacing * (cells.count - 1)) / cells.count
                height: cells.height

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: cells.steps ? 6 : 28
                    radius: cells.steps ? 3 : 8
                    color: cells.steps
                        ? (cell.lit ? Theme.imperial.text : cellArea.containsMouse && !cells.disabled ? "#2E2E36" : Theme.imperial.surfaceAlt)
                        : (cell.lit ? Theme.imperial.surfaceAlt : cellArea.containsMouse && !cells.disabled ? "#16161B" : Theme.imperial.rowHover)

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        visible: !cells.steps
                        text: cells.labels[cell.index] || ""
                        textFormat: Text.PlainText
                        color: cell.lit || cellArea.containsMouse ? Theme.imperial.text : Theme.imperial.muted
                        renderType: Text.CurveRendering
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                }

                MouseArea {
                    id: cellArea

                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !cells.disabled
                    cursorShape: Qt.PointingHandCursor
                    onClicked: cells.picked(cell.index)
                    onWheel: wheel => {
                        const next = Math.max(0, Math.min(cells.count - 1, cells.value + (wheel.angleDelta.y > 0 ? 1 : -1)))
                        if (next !== cells.value)
                            cells.picked(next)
                    }
                }
            }
        }
    }

    readonly property int sendPct: Keyboard.sentFrames > 0
        ? Math.round(((Keyboard.sentFrame - 1) * Keyboard.sentPages + Keyboard.sentPage) / (Keyboard.sentFrames * Keyboard.sentPages) * 100)
        : 0

    readonly property string effectLabel: effectInfo(Keyboard.effect)[1] !== "Effect " + Keyboard.effect
        ? effectInfo(Keyboard.effect)[1] : Keyboard.effectName
    readonly property string stateLabel: effectInfo(Keyboard.effect)[2] === "off" ? "Lights out"
        : (Keyboard.effectHasColor ? (Keyboard.color === 7 ? "Rainbow" : colorNames[Keyboard.color].charAt(0).toUpperCase() + colorNames[Keyboard.color].slice(1))
            : "Effect colours")

    PanelHeader {
        id: header

        x: 22
        y: 16
        width: parent.width - 44
        title: "BA-KEY391"
        detail: Keyboard.sending ? "Sending" : Keyboard.writing ? "Writing" : Keyboard.online ? "USB cable" : "Offline"
        detailColor: Keyboard.online ? Theme.imperial.faint : Theme.imperial.dangerText
    }

    Column {
        id: column

        x: 22
        y: header.y + header.height + 8
        width: panel.width - 44
        spacing: 10

        // The figure on the ink itself, with the effect and its state under it.
        Item {
            width: column.width
            height: fig.height + 22

            Canvas {
                id: fig

                x: -6
                width: parent.width + 12
                height: width / 1.6

                onPaint: {
                    const ctx = getContext("2d")
                    panel.fit(width)
                    ctx.clearRect(0, 0, width, height)
                    panel.drawKeyboard(ctx)
                }
            }

            Text {
                anchors.bottom: parent.bottom
                text: panel.effectLabel
                textFormat: Text.PlainText
                color: panel.c.text
                renderType: Text.CurveRendering
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.Medium
            }

            Text {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                text: panel.stateLabel
                textFormat: Text.PlainText
                color: panel.c.muted
                renderType: Text.CurveRendering
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
        }

        // lighting: the effects, then how bright, how fast and which colour
        Section {
            label: "Lighting"
        }

        Setting {
            label: "Effect"

            Select {
                x: 96
                width: parent.width - 96
                options: panel.effectOptions
                current: panel.effectIndex(Keyboard.effect)
                placeholder: "Effect " + Keyboard.effect
                onPicked: index => Keyboard.setEffect(panel.effects[index][0])
            }
        }

        Setting {
            label: "Brightness"
            disabled: !Keyboard.effectHasBrightness

            Cells {
                x: 96
                width: parent.width - 96
                count: 7
                steps: true
                value: Keyboard.bright
                disabled: !Keyboard.effectHasBrightness
                onPicked: index => Keyboard.setBright(index)
            }
        }

        Setting {
            label: "Speed"
            disabled: !Keyboard.effectHasSpeed

            Cells {
                x: 96
                width: parent.width - 96
                count: 5
                steps: true
                value: Keyboard.speed
                disabled: !Keyboard.effectHasSpeed
                onPicked: index => Keyboard.setSpeed(index)
            }
        }

        Setting {
            label: "Colour"
            disabled: !Keyboard.effectHasColor

            Row {
                id: swatches

                // Eight swatches always fit the control column (they overflowed at a fixed 24 px).
                readonly property real size: Math.min(24, Math.floor((parent.width - 96 - 7 * spacing) / 8))

                x: 96
                y: (28 - size) / 2
                spacing: 3

                Repeater {
                    model: 8

                    delegate: Rectangle {
                        id: swatch

                        required property int index

                        readonly property bool picked: Keyboard.color === index

                        width: swatches.size
                        height: swatches.size
                        radius: swatches.size / 2
                        color: "transparent"
                        border.width: 1
                        border.color: picked ? panel.c.text : swatchArea.containsMouse ? panel.c.faint : "transparent"

                        Rectangle {
                            anchors.centerIn: parent
                            width: 14
                            height: 14
                            radius: 7
                            visible: swatch.index < 7
                            color: swatch.index < 7 ? Qt.rgba(panel.colorRgb[swatch.index][0] / 255, panel.colorRgb[swatch.index][1] / 255,
                                panel.colorRgb[swatch.index][2] / 255, 1) : "transparent"
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 14
                            height: 14
                            radius: 7
                            visible: swatch.index === 7

                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#ff2d2d" }
                                GradientStop { position: 0.2; color: "#ffe02d" }
                                GradientStop { position: 0.4; color: "#2dff5a" }
                                GradientStop { position: 0.6; color: "#2de0ff" }
                                GradientStop { position: 0.8; color: "#b02dff" }
                                GradientStop { position: 1.0; color: "#ff2d2d" }
                            }
                        }

                        MouseArea {
                            id: swatchArea

                            anchors.fill: parent
                            enabled: Keyboard.effectHasColor
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Keyboard.setColor(swatch.index)
                        }
                    }
                }
            }
        }

        // side glow: the mode is one of five presets, the level is how strong it is
        Section {
            label: "Side glow"
        }

        Setting {
            label: "Mode"

            Select {
                x: 96
                width: parent.width - 96
                options: panel.sideModes.map(m => m.charAt(0) + m.slice(1).toLowerCase())
                current: Keyboard.sideMode
                onPicked: index => Keyboard.setSideMode(index)
            }
        }

        Setting {
            label: "Level"
            disabled: Keyboard.sideMode === 0

            Cells {
                x: 96
                width: parent.width - 96
                count: 5
                steps: true
                value: Keyboard.sideLevel
                disabled: Keyboard.sideMode === 0
                onPicked: index => Keyboard.setSideLevel(index)
            }
        }

        // the screen shown when the keyboard starts
        Section {
            label: "Display"
        }

        Setting {
            label: "Boot"

            Cells {
                x: 96
                width: parent.width - 96
                count: 2
                labels: ["Home", "GIF"]
                value: Keyboard.boot - 1
                onPicked: index => Keyboard.setBoot(index + 1)
            }
        }

        Setting {
            label: "Image"
            disabled: Keyboard.sending

            Select {
                x: 96
                width: parent.width - 96
                options: Keyboard.gifNames
                current: Keyboard.gifNames.indexOf(Keyboard.gifSelected)
                disabled: Keyboard.sending
                placeholder: "No image in ~/Pictures/Keyboard"
                onPicked: index => Keyboard.selectGif(Keyboard.gifNames[index])
            }
        }

        Setting {
            label: ""
            disabled: Keyboard.gifSelected === "" && !Keyboard.sending

            // idle: the button
            PanelButton {
                x: 96
                visible: !Keyboard.sending
                text: "Send to screen"
                primary: true
                enabled: Keyboard.gifSelected !== ""
                onClicked: Keyboard.sendGif(Keyboard.gifSelected)
            }

            // sending: the progress, and a cancel
            Item {
                x: 96
                width: parent.width - 96
                height: 28
                visible: Keyboard.sending

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -2
                    text: Keyboard.sentFrames > 0 ? "Frame " + Keyboard.sentFrame + " of " + Keyboard.sentFrames + ", " + panel.sendPct + "%" : "Starting…"
                    color: panel.c.text
                    renderType: Text.CurveRendering
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.features: { "tnum": 1 }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -2
                    text: "Cancel"
                    color: cancelArea.containsMouse ? panel.c.dangerText : panel.c.muted
                    renderType: Text.CurveRendering
                    font.family: Theme.fontFamily
                    font.pixelSize: 12

                    MouseArea {
                        id: cancelArea

                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Keyboard.cancelGif()
                    }
                }

                Rectangle {
                    id: track

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 2
                    radius: 1
                    color: panel.c.surfaceAlt

                    Rectangle {
                        width: track.width * panel.sendPct / 100
                        height: track.height
                        radius: 1
                        color: panel.c.text
                    }
                }
            }
        }

        Text {
            width: column.width
            visible: Keyboard.gifError !== "" || Keyboard.gifSent !== ""
            text: Keyboard.gifError !== "" ? Keyboard.gifError : "Sent " + Keyboard.gifSent + " to the screen."
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: Keyboard.gifError !== "" ? panel.c.dangerText : panel.c.muted
            renderType: Text.CurveRendering
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }

        // The raw state the keyboard reports (hardware effect id and levels), or why it cannot be read.
        Text {
            width: column.width
            text: Keyboard.online
                ? "Effect " + Keyboard.effect + ", brightness " + Keyboard.bright + "/6, speed " + Keyboard.speed + "/4, side glow " + Keyboard.sideMode + "/" + Keyboard.sideLevel
                : (Keyboard.error !== "" ? Keyboard.error : "Keyboard not found. Is the cable connected?")
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: Keyboard.online ? panel.c.faint : panel.c.dangerText
            renderType: Text.CurveRendering
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.features: { "tnum": 1 }
        }
    }

    // The figure animates while the panel is open, and the state is read again every 2 s, so the Fn keys show here too.
    Timer {
        id: clock

        interval: 33
        repeat: true
        running: panel.isOpen
        onTriggered: {
            panel.animT += 0.033
            fig.requestPaint()
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: panel.isOpen
        onTriggered: Keyboard.refresh()
    }

    Connections {
        target: Dropdown

        function onCurrentChanged() {
            if (Dropdown.current === "keyboard") {
                Keyboard.refresh()
                Keyboard.listGifs()
            }
        }
    }

    Component.onCompleted: {
        Keyboard.refresh()
        Keyboard.listGifs()
        fig.requestPaint()
    }
}
