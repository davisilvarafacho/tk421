import QtQuick

// Reduced motion: a plain crossfade.
Item {
    id: fx

    property url fromSource
    property url toSource
    property real progress: 0
    property int decodeWidth: 2560

    Cover {
        anchors.fill: parent
        source: fx.fromSource
        decodeWidth: fx.decodeWidth
    }

    Cover {
        anchors.fill: parent
        source: fx.toSource
        decodeWidth: fx.decodeWidth
        opacity: fx.progress
    }
}
