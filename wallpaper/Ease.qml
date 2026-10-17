import QtQuick

// The exponential ease-out used across the shell (launcher, island).
NumberAnimation {
    easing.type: Easing.BezierSpline
    easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
}
