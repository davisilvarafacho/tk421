import QtQuick

// Line graph of 0-100 samples with a faint fill under it, in brushed steel (the launcher's accent).
Canvas {
    id: spark

    property var values: []
    readonly property color steel: "#B9B6B2"

    onValuesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        if (values.length < 2 || width <= 0)
            return

        const step = width / (values.length - 1)
        const y = v => height - 2 - (Math.max(0, Math.min(100, v)) / 100) * (height - 4)

        ctx.beginPath()
        ctx.moveTo(0, y(values[0]))
        for (let i = 1; i < values.length; i++)
            ctx.lineTo(i * step, y(values[i]))

        ctx.strokeStyle = steel
        ctx.lineWidth = 1.4
        ctx.lineJoin = "round"
        ctx.stroke()

        ctx.lineTo(width, height)
        ctx.lineTo(0, height)
        ctx.closePath()
        ctx.fillStyle = Qt.rgba(0.725, 0.714, 0.698, 0.10)
        ctx.fill()
    }
}
